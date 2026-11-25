#!/usr/bin/env bash
# Follow docs/install.md from start to finish on this host, then run tools/smoke.py against the result.
#   check_install.sh compose          needs Docker with Compose
# COMPOSE overrides the Compose command, and PCAP_ANALYZER_PORT the port.
set -euo pipefail

ROOT=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
VERSION=$(sed -n 's/^__version__ = "\(.*\)"/\1/p' "$ROOT/src/pcap_analyzer/__init__.py")
IMAGE=pcap-analyzer:$VERSION
PORT=${PCAP_ANALYZER_PORT:-8000}
COMPOSE=${COMPOSE:-docker compose}
PYTHON=${PYTHON:-python3}
WORK=$(mktemp -d)
SUDO=
[[ $(id -u) == 0 ]] || SUDO=sudo
export PCAP_ANALYZER_PORT=$PORT PCAP_ANALYZER_SMOKE_PASSWORD=$(head -c 18 /dev/urandom | base64 | tr -d '/+=')
export PCAP_ANALYZER_SMOKE_MASTER_KEY='Smoke#Master-Key'  # the first sign-in sets it, which encrypts the data folder

die() { echo "error: $*" >&2; exit 1; }

capture() {
  "$PYTHON" "$ROOT/tools/gen_samples.py" "$WORK/samples" >/dev/null
  CAPTURE=$WORK/samples/http_scenarios.pcap
}

wait_for() {
  for _ in $(seq 1 60); do
    "$PYTHON" -c "import ssl, sys, urllib.request as u; u.urlopen(sys.argv[1], timeout=2, context=ssl.create_default_context(cafile=sys.argv[2] or None))" "$1" "${2:-}" 2>/dev/null && return
    sleep 1
  done
  die "$1 did not answer"
}

compose_stop() {
  (cd "$ROOT/docker" && $COMPOSE down -v) || true
  rm -f "$ROOT/docker/.env"
}

compose() {
  [[ ! -e $ROOT/docker/.env ]] || die "docker/.env exists. This check would replace it"
  (cd "$ROOT" && docker build -f docker/Containerfile -t "$IMAGE" .)
  local hash
  hash=$(printf '%s\n' "$PCAP_ANALYZER_SMOKE_PASSWORD" | docker run --rm -i "$IMAGE" pcap-analyzer hash-password 2>/dev/null)
  trap compose_stop EXIT
  { grep -v '^PCAP_ANALYZER_ADMIN_PASSWORD=' "$ROOT/docker/.env.example"; printf "PCAP_ANALYZER_ADMIN_PASSWORD_HASH='%s'\n" "$hash"; } >"$ROOT/docker/.env"
  (cd "$ROOT/docker" && $COMPOSE up -d --no-build)
  wait_for "http://127.0.0.1:$PORT/healthz"
  capture
  "$PYTHON" "$ROOT/tools/smoke.py" "http://127.0.0.1:$PORT" "$CAPTURE"
}

case ${1:-} in
  compose) compose ;;
  *) sed -n '2,6p' "$0"; exit 2 ;;
esac
rm -rf "$WORK"
echo "Install check passed: $*"
