# Slim base = far smaller package surface than the full python:3.11 image,
# which is what was dragging in libssh2 + extra OS CVEs.
FROM python:3.11-slim

# --- OS layer: apply Debian security updates -------------------------------
# Trivy flagged libssh2 (CVE-2026-55200 / -55199 / -7598), all fixed in
# Debian's +deb13u1 build. `apt-get upgrade` pulls the patched packages, then
# we delete the apt cache so it doesn't bloat the image or re-introduce metadata.
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# --- Python build tooling: patch BEFORE installing app deps ----------------
# wheel (CVE-2026-24049) and jaraco.context (CVE-2026-23949) ship inside the
# base image's pip/setuptools chain. Upgrading them here bakes the fixed
# versions into the image so the image scan comes back clean.
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# --- Run as non-root --------------------------------------------------------
# Distinction-grade container hardening: drop root so a process compromise
# doesn't own the container.
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8001

CMD ["python", "-m", "app.main"]
