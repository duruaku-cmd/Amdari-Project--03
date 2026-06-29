"""Day 6 defence-in-depth security helpers.

Centralises the new controls so routes stay readable and the controls are
testable in isolation:
  * password hashing (Argon2id) with transparent migration from legacy MD5
  * SSRF-safe outbound URL validation (blocks private / link-local / metadata)
  * signed-JSON session tokens (replacing insecure pickle)
  * a structured audit logger
"""
import os
import json
import hmac
import hashlib
import base64
import ipaddress
import socket
import logging
from urllib.parse import urlparse

# ---------------------------------------------------------------------------
# Structured audit logging (V-APP-11)
# ---------------------------------------------------------------------------
_audit = logging.getLogger("sentinelpay.audit")
if not _audit.handlers:
    _h = logging.StreamHandler()
    _h.setFormatter(logging.Formatter('%(asctime)s AUDIT %(message)s'))
    _audit.addHandler(_h)
    _audit.setLevel(logging.INFO)


def audit(action, actor=None, target=None, outcome="success", **extra):
    """Emit a structured audit record for a security-relevant event."""
    record = {"action": action, "actor": actor, "target": target, "outcome": outcome}
    record.update(extra)
    _audit.info(json.dumps(record))


# ---------------------------------------------------------------------------
# Password hashing: Argon2id with legacy-MD5 migrate-on-login (V-APP-06)
# ---------------------------------------------------------------------------
try:
    from argon2 import PasswordHasher
    from argon2.exceptions import VerifyMismatchError
    _ph = PasswordHasher()  # sensible defaults (memory-hard)
    _ARGON2_AVAILABLE = True
except Exception:  # pragma: no cover - argon2 should be installed via requirements
    _ARGON2_AVAILABLE = False


def hash_password(password: str) -> str:
    """Hash a password with Argon2id for storage."""
    if not _ARGON2_AVAILABLE:
        raise RuntimeError("argon2-cffi is not installed; cannot hash securely")
    return _ph.hash(password)


def _looks_like_md5(stored_hash: str) -> bool:
    """Legacy MD5 hashes are 32 lowercase hex chars."""
    return len(stored_hash) == 32 and all(c in "0123456789abcdef" for c in stored_hash.lower())


def verify_password(password: str, stored_hash: str):
    """Verify a password against either an Argon2 hash or a legacy MD5 hash.

    Returns a tuple (ok: bool, new_hash: str|None). If the stored hash was
    legacy MD5 and the password matched, new_hash carries a freshly-computed
    Argon2id hash so the caller can transparently upgrade the stored value
    (migrate-on-login — no forced password reset).
    """
    if _looks_like_md5(stored_hash):
        legacy = hashlib.md5(password.encode(), usedforsecurity=False).hexdigest()  # nosec B324 
        if hmac.compare_digest(legacy, stored_hash.lower()):
            return True, (hash_password(password) if _ARGON2_AVAILABLE else None)
        return False, None
    # Argon2 path
    try:
        _ph.verify(stored_hash, password)
        return True, None
    except VerifyMismatchError:
        return False, None
    except Exception:
        return False, None


# ---------------------------------------------------------------------------
# SSRF-safe outbound URL validation (V-APP-04)
# ---------------------------------------------------------------------------
_BLOCKED_NETS = [
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("169.254.0.0/16"),   # link-local incl. cloud metadata
    ipaddress.ip_network("::1/128"),
    ipaddress.ip_network("fc00::/7"),
    ipaddress.ip_network("fe80::/10"),
]


class UnsafeURLError(ValueError):
    pass


def validate_outbound_url(url: str, allowed_hosts=None):
    """Validate a caller-supplied URL before the server fetches it.

    Enforces:
      * scheme is http/https only;
      * host resolves only to public IPs (blocks loopback, private, link-local,
        and the 169.254.169.254 cloud-metadata address);
      * if allowed_hosts is provided, the host must be in it.
    Raises UnsafeURLError on any violation. Returns the parsed host on success.
    """
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        raise UnsafeURLError("only http/https URLs are allowed")
    host = parsed.hostname
    if not host:
        raise UnsafeURLError("URL has no host")

    if allowed_hosts is not None and host not in allowed_hosts:
        raise UnsafeURLError("host is not in the allowlist")

    # Resolve every address the host maps to and reject if ANY is non-public.
    try:
        infos = socket.getaddrinfo(host, None)
    except socket.gaierror:
        raise UnsafeURLError("host could not be resolved")

    for info in infos:
        ip = ipaddress.ip_address(info[4][0])
        for net in _BLOCKED_NETS:
            if ip in net:
                raise UnsafeURLError(f"host resolves to blocked address {ip}")
        if ip.is_loopback or ip.is_link_local or ip.is_private or ip.is_reserved:
            raise UnsafeURLError(f"host resolves to non-public address {ip}")
    return host


# ---------------------------------------------------------------------------
# Signed-JSON session tokens, replacing insecure pickle (V-APP-10)
# ---------------------------------------------------------------------------
def _session_key() -> bytes:
    key = os.environ.get("SESSION_SIGNING_KEY") or os.environ.get("JWT_SECRET")
    if not key:
        raise RuntimeError("SESSION_SIGNING_KEY/JWT_SECRET not set")
    return key.encode()


def make_session(data: dict) -> str:
    """Serialise session data as signed JSON (data, not code)."""
    payload = base64.urlsafe_b64encode(json.dumps(data).encode()).decode()
    sig = hmac.new(_session_key(), payload.encode(), hashlib.sha256).hexdigest()
    return f"{payload}.{sig}"


def load_session(blob: str) -> dict:
    """Verify the signature, then JSON-decode. Never executes code.

    Raises ValueError if the signature is missing or invalid.
    """
    try:
        payload, sig = blob.split(".", 1)
    except ValueError:
        raise ValueError("malformed session token")
    expected = hmac.new(_session_key(), payload.encode(), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(sig, expected):
        raise ValueError("bad session signature")
    return json.loads(base64.urlsafe_b64decode(payload.encode()).decode())
