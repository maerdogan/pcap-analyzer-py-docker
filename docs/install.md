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

Put the hash in `.env` in single quotes, as `PCAP_ANALYZER_ADMIN_PASSWORD_HASH='...'`, and start it. The hash is optional: without it the first sign-in is `admin` / `admin`. At the first start the app takes it over into the data folder and logs a warning, so you can remove it from `.env` afterwards:

```bash
docker compose up -d --no-build
```

Compose publishes port 8000 on localhost only, so put an HTTPS proxy in front of it. Set `PCAP_ANALYZER_PORT` in `.env` to use another port. To serve HTTPS directly, mount a certificate, add `--cert` and `--key` to the command, and set `PCAP_ANALYZER_BEHIND_PROXY=0`.

Compose limits the app to 2 CPUs, 4 GiB of memory, 256 processes and 3 GiB in `/tmp`. `/tmp` is memory there. An upload waits in a private folder inside the data folder, where it is joined and encrypted before the analysis reads it. Captures over 100 MB are read in parts of whole connections, so a 1 GB capture peaked near 700 MiB and took under 3 minutes. One very large connection is never split, so a capture that is mostly one connection still needs memory in proportion to its size. Raise the limits if you raise `PCAP_ANALYZER_MAX_JOBS`.

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
| `PCAP_ANALYZER_ADMIN_USER` | `admin` | Name of the setup admin, who opens the encrypted data after every restart. Other users are made in the app under **Settings → Users** |
| `PCAP_ANALYZER_ADMIN_PASSWORD_HASH` | | A first password for the setup admin, as a hash from `pcap-analyzer hash-password`. Optional |
| `PCAP_ANALYZER_ADMIN_PASSWORD` | | A first password in plain text, as the alternative. Optional. With neither set, or with the password `admin` or one under 12 characters, the first sign-in is `admin` / `admin` or that password, and every page asks for a new password first. Either is taken over once into `.admin-password.json` in the data folder, with a warning in the log to remove it from the settings, and is ignored from then on. Once the master key is set, that file is deleted: the admin password then only unwraps the admin key of the encrypted data folder |
| `PCAP_ANALYZER_LDAP_CA_FILE` | | Certificates to trust for an `ldaps://` server signed by a private CA. Without it the system's trusted certificates are used |
| `PCAP_ANALYZER_BEHIND_PROXY` | `0` | `1` when an HTTPS proxy is in front |
| `PCAP_ANALYZER_HSTS_S` | `31536000` | How long browsers must use HTTPS, sent whenever HTTPS is on. `0` tells them to stop. Applies to the host name on every port |
| `PCAP_ANALYZER_REQUEST_ID_HEADER` | `x-request-id` | Header that follows a request through proxies. `traceparent` is read when it is absent |
| `PCAP_ANALYZER_CLIENT_IP_HEADER` | `x-forwarded-for,x-real-ip,true-client-ip,x-client-ip,client-ip,forwarded` | Headers that carry the original client, comma separated, tried in order. A PROXY protocol header is used when none has one. A NetScaler adds its own with *Client IP header* on the service |
| `PCAP_ANALYZER_HEALTH_PATHS` | | More health check paths, comma separated, besides `/healthz`, `/ready`, `/actuator/health` and the like. Requests to them are marked as health checks |
| `PCAP_ANALYZER_MERGECAP` | `mergecap` | Program that joins parts of a capture |
| `PCAP_ANALYZER_SANDBOX` | on where possible | `0` stops running tshark in its own namespaces |
| `PCAP_ANALYZER_TRUSTED_PROXIES` | | Proxy addresses or networks whose forwarded headers are believed, such as `10.0.0.5,10.1.0.0/16`. When empty, all users behind the proxy share one login lockout |
| `PCAP_ANALYZER_WORKDIR` | `~/.local/share/pcap-analyzer` | The data folder: captures, results, users, settings, the activity log and the encryption keys, all encrypted once the master key is set. Uploads and running analyses use private `.tmp-` folders in it. Back it up together with the master key |
| `PCAP_ANALYZER_MAX_SIZE_MB` | `1000` | Largest accepted capture. Captures over 100 MB are read in parts of whole connections |
| `PCAP_ANALYZER_TTL_DAYS` | `7` | An analysis nobody opened for this many days is deleted, at start and every hour. One never opened counts from its upload |
| `PCAP_ANALYZER_MAX_JOBS` | `2` | Analyses running at once |
| `PCAP_ANALYZER_KEEP_CAPTURE` | `1` | Keep the capture for PCAP export, `0` to delete it after analysis. The Statistics tab, TCP graphs, Flow Graph, Follow Stream and Export Objects read the kept capture, so they need `1` |
| `PCAP_ANALYZER_GEOIP_DIR` | none | A folder of MaxMind GeoLite2 `.mmdb` files. IP endpoints then show their country and AS number |
| `PCAP_ANALYZER_LANGUAGE` | `tr` | Default language: `tr`, `en`, `de` or `es`. Each user can choose another in the app |
| `PCAP_ANALYZER_ANALYSIS_TIMEOUT_S` | `600` | Longest analysis in seconds, `0` for no limit |
| `PCAP_ANALYZER_KNOWLEDGE` | | Path of another knowledge file, built with `tools/build_knowledge.py` |
