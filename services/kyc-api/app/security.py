"""Day 6 security helpers for kyc-api (SSRF guard + audit logging).

Mirrors the payments-api security module. The duplication across services is the
same known tech debt noted for the auth module; consolidating both services onto
a shared internal package is tracked for later.
"""
import json
import ipaddress
import socket
import logging
from urllib.parse import urlparse

_audit = logging.getLogger("sentinelpay.audit")
if not _audit.handlers:
    _h = logging.StreamHandler()
    _h.setFormatter(logging.Formatter('%(asctime)s AUDIT %(message)s'))
    _audit.addHandler(_h)
    _audit.setLevel(logging.INFO)


def audit(action, actor=None, target=None, outcome="success", **extra):
    record = {"action": action, "actor": actor, "target": target, "outcome": outcome}
    record.update(extra)
    _audit.info(json.dumps(record))


_BLOCKED_NETS = [
    ipaddress.ip_network("127.0.0.0/8"), ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"), ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("169.254.0.0/16"), ipaddress.ip_network("::1/128"),
    ipaddress.ip_network("fc00::/7"), ipaddress.ip_network("fe80::/10"),
]


class UnsafeURLError(ValueError):
    pass


def validate_outbound_url(url: str, allowed_hosts=None):
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https"):
        raise UnsafeURLError("only http/https URLs are allowed")
    host = parsed.hostname
    if not host:
        raise UnsafeURLError("URL has no host")
    if allowed_hosts is not None and host not in allowed_hosts:
        raise UnsafeURLError("host is not in the allowlist")
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
