#!/bin/bash
# Entry point for a single GitHub Actions runner scope (org or repo).
# RUNNER_TOKEN is required only on FIRST configuration of a scope; credentials
# persist in the mounted volume so container restarts reuse the registration.
set -euo pipefail
RUNNER_VERSION="${RUNNER_VERSION:-2.337.0}"
RUNNER_DIR="${RUNNER_DIR:-/data/runner}"
mkdir -p "$RUNNER_DIR"
git config --global --add safe.directory '*' || true
export DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"

if [ ! -f "$RUNNER_DIR/.runner" ]; then
  : "${RUNNER_SCOPE_URL:?RUNNER_SCOPE_URL required}"
  : "${RUNNER_TOKEN:?RUNNER_TOKEN required (fresh registration token)}"
  : "${RUNNER_NAME:?RUNNER_NAME required}"
  : "${RUNNER_LABELS:?RUNNER_LABELS required}"
  cd "$RUNNER_DIR"
  curl -fsSL -o runner.tgz "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
  tar -xzf runner.tgz --skip-old-files
  rm -f runner.tgz
  # shellcheck disable=SC2154
  ./config.sh --url "$RUNNER_SCOPE_URL" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" \
    --labels "$RUNNER_LABELS" --unattended --work /data/_work
  echo "runner configured: $RUNNER_NAME for $RUNNER_SCOPE_URL"
else
  echo "existing registration found for $RUNNER_NAME; skipping config"
fi
cd "$RUNNER_DIR"
exec ./run.sh
