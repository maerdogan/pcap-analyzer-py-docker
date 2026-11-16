# Install

Read the [security section](../README.md#security) first. HTTPS, network isolation and encrypted storage are yours to add.

Everything below works without internet on the target host once the image is there.

## Docker or Podman

Each [release](https://github.com/maerdogan/pcap-analyzer-py-docker/releases) has the image on GitHub Container Registry, and the same image as a file for hosts without internet. Take it one of these ways.

From the registry:

```bash
docker pull ghcr.io/maerdogan/pcap-analyzer-py-docker:0.8.0
docker tag ghcr.io/maerdogan/pcap-analyzer-py-docker:0.8.0 pcap-analyzer:0.8.0
```

From the release files, copied to the host:

```bash
sha256sum --check --ignore-missing SHA256SUMS
gunzip -c pcap-analyzer-0.8.0-image-amd64.tar.gz | docker load
```

Or build it yourself:

```bash
docker build -f docker/Containerfile -t pcap-analyzer:0.8.0 .
```

Then create the settings and a password hash:

```bash
cd docker
cp .env.example .env
docker run --rm -it pcap-analyzer:0.8.0 pcap-analyzer hash-password
```

Put the hash in `.env` in single quotes, as `PCAP_ANALYZER_ADMIN_PASSWORD_HASH='...'`, and start it:

```bash
docker compose up -d --no-build
```

Compose publishes port 8000 on localhost only, so put an HTTPS proxy in front of it. Set `PCAP_ANALYZER_PORT` in `.env` to use another port. To serve HTTPS directly, mount a certificate, add `--cert` and `--key` to the command, and set `PCAP_ANALYZER_BEHIND_PROXY=0`.

Compose limits the app to 2 CPUs, 4 GiB of memory, 256 processes and 3 GiB in `/tmp`. `/tmp` is memory there, and an upload waits in it. Captures over 100 MB are read in parts of whole connections, so a 1 GB capture peaked near 700 MiB and took under 3 minutes. One very large connection is never split, so a capture that is mostly one connection still needs memory in proportion to its size. Raise the limits if you raise `PCAP_ANALYZER_MAX_JOBS`.

## Check an install

`tools/smoke.py` signs in, uploads a capture, opens every page, downloads each export, deletes the analysis and signs out. It stops at the first failure and needs only Python. Use a capture with plain HTTP traffic.

```bash
read -rs PCAP_ANALYZER_SMOKE_PASSWORD && export PCAP_ANALYZER_SMOKE_PASSWORD
python3 tools/smoke.py http://127.0.0.1:8000 capture.pcap
```

With a self-signed certificate, add `--cafile cert.pem`.

`tools/check_install.sh compose` follows this guide from start to finish and then runs that walk. CI runs it on every change.

## Settings

| Variable | Default | Meaning |
|---|---|---|
| `PCAP_ANALYZER_ADMIN_USER` | `admin` | Login name |
| `PCAP_ANALYZER_ADMIN_PASSWORD_HASH` | | Password hash, preferred |
| `PCAP_ANALYZER_ADMIN_PASSWORD` | | Plain password, as the alternative. With neither set, or with the password `admin`, the first sign-in is `admin` / `admin` and every page asks for a new password first. The new password is kept in `.admin-password.json` in the data folder and wins over these settings; delete that file to go back to them |
| `PCAP_ANALYZER_BEHIND_PROXY` | `0` | `1` when an HTTPS proxy is in front |
| `PCAP_ANALYZER_HSTS_S` | `31536000` | How long browsers must use HTTPS, sent whenever HTTPS is on. `0` tells them to stop. Applies to the host name on every port |
| `PCAP_ANALYZER_REQUEST_ID_HEADER` | `x-request-id` | Header that follows a request through proxies. `traceparent` is read when it is absent |
| `PCAP_ANALYZER_MERGECAP` | `mergecap` | Program that joins parts of a capture |
| `PCAP_ANALYZER_SANDBOX` | on where possible | `0` stops running tshark in its own namespaces |
| `PCAP_ANALYZER_TRUSTED_PROXIES` | | Proxy addresses or networks whose forwarded headers are believed, such as `10.0.0.5,10.1.0.0/16`. When empty, all users behind the proxy share one login lockout |
| `PCAP_ANALYZER_WORKDIR` | `~/.local/share/pcap-analyzer` | Where results are saved |
| `PCAP_ANALYZER_MAX_SIZE_MB` | `1000` | Largest accepted capture. Captures over 100 MB are read in parts of whole connections |
| `PCAP_ANALYZER_TTL_DAYS` | `7` | Days results are kept. The server removes older ones every hour |
| `PCAP_ANALYZER_MAX_JOBS` | `2` | Analyses running at once |
| `PCAP_ANALYZER_KEEP_CAPTURE` | `1` | Keep the capture for PCAP export, `0` to delete it after analysis. The Statistics tab, TCP graphs, Flow Graph, Follow Stream and Export Objects read the kept capture, so they need `1` |
| `PCAP_ANALYZER_GEOIP_DIR` | none | A folder of MaxMind GeoLite2 `.mmdb` files. IP endpoints then show their country and AS number |
| `PCAP_ANALYZER_LANGUAGE` | `tr` | Default language: `tr`, `en`, `de` or `es`. Each user can choose another in the app |
| `PCAP_ANALYZER_ANALYSIS_TIMEOUT_S` | `600` | Longest analysis in seconds, `0` for no limit |
| `PCAP_ANALYZER_KNOWLEDGE` | | Path of another knowledge file, built with `tools/build_knowledge.py` |
