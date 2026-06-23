"""Day 6 defence-in-depth regression tests.

Each test passes against the patched code and fails against the unpatched code.
Run against a live stack (docker compose up).
    PAYMENTS_BASE (default http://localhost:8001)
    KYC_BASE      (default http://localhost:8002)
"""
import os
import uuid
import requests

PAYMENTS = os.environ.get("PAYMENTS_BASE", "http://localhost:8001")


def _register_and_login(email, password="password123"):
    requests.post(f"{PAYMENTS}/v1/auth/register",
                  json={"email": email, "password": password, "full_name": "t"})
    r = requests.post(f"{PAYMENTS}/v1/auth/login",
                      json={"email": email, "password": password})
    return r.json().get("token")


# V-APP-07: role self-grant must be ignored — a registrant is always 'merchant'.
def test_vapp07_role_self_grant_ignored():
    email = f"role_{uuid.uuid4().hex[:8]}@example.com"
    r = requests.post(f"{PAYMENTS}/v1/auth/register",
                      json={"email": email, "password": "password123", "role": "admin"})
    assert r.status_code == 201
    assert r.json().get("role") == "merchant", "client-supplied role was honoured"


# V-APP-07: mass assignment — non-allowlisted fields rejected.
def test_vapp07_mass_assignment_blocked():
    token = _register_and_login(f"ma_{uuid.uuid4().hex[:8]}@example.com")
    r = requests.put(f"{PAYMENTS}/v1/accounts/3/profile",
                     json={"balance": "99999999.00"},
                     headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 400, f"balance write was not rejected (status {r.status_code})"


# V-APP-04: SSRF — the metadata IP must be refused before any fetch.
def test_vapp04_ssrf_metadata_blocked():
    token = _register_and_login(f"ssrf_{uuid.uuid4().hex[:8]}@example.com")
    r = requests.post(f"{PAYMENTS}/v1/webhooks/test",
                      json={"url": "http://169.254.169.254/latest/meta-data/"},
                      headers={"Authorization": f"Bearer {token}"})
    assert r.status_code == 400, f"SSRF to metadata not blocked (status {r.status_code})"


# V-APP-08: rate limiting — rapid logins eventually get a 429.
def test_vapp08_rate_limit_triggers():
    email = f"rl_{uuid.uuid4().hex[:8]}@example.com"
    requests.post(f"{PAYMENTS}/v1/auth/register",
                  json={"email": email, "password": "password123"})
    saw_429 = False
    for _ in range(12):
        r = requests.post(f"{PAYMENTS}/v1/auth/login",
                          json={"email": email, "password": "wrong"})
        if r.status_code == 429:
            saw_429 = True
            break
    assert saw_429, "rate limiter never returned 429 under rapid requests"


# V-APP-09: verbose errors — a server error must NOT include a stack trace.
def test_vapp09_no_stack_trace_leaked():
    # Login with a malformed body to provoke an error path; ensure no 'trace'.
    r = requests.post(f"{PAYMENTS}/v1/auth/login", data="not-json",
                      headers={"Content-Type": "application/json"})
    body = r.text.lower()
    assert "traceback" not in body and '"trace"' not in body, "stack trace leaked to client"


# V-APP-10: pickle RCE — an unsigned/garbage session blob must be rejected,
# not deserialised. (Also requires admin now.)
def test_vapp10_pickle_replaced_with_signed_json():
    import base64, pickle
    # A malicious pickle that would run code if loaded.
    class Boom:
        def __reduce__(self):
            import os as _os
            return (_os.system, ("echo pwned",))
    blob = base64.b64encode(pickle.dumps(Boom())).decode()
    # Without admin we get 403; with the broken code a forged token + pickle = RCE.
    token = _register_and_login(f"pk_{uuid.uuid4().hex[:8]}@example.com")
    r = requests.post(f"{PAYMENTS}/v1/admin/session/restore",
                      json={"session": blob},
                      headers={"Authorization": f"Bearer {token}"})
    # merchant -> 403 admin-only; even as admin the blob is unsigned -> 400.
    assert r.status_code in (400, 403), f"pickle blob not safely rejected (status {r.status_code})"
