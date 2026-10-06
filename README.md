# infra-gh-runner

Container image for GitHub Actions self-hosted runners deployed via Coolify on hetzner-sw02-fsn1.

Each compose service = one runner scope (org or repo). Registration credentials persist in the
service volume; `RUNNER_TOKEN` is only needed the first time a scope is configured (harvest a
fresh token from GitHub when adding or re-adding a scope). The host docker socket is mounted so
workflow `services:` / `container:` jobs work through the host daemon.

Runners here share labels with the LXC9104 (prox01-gh-runner) fleet so GitHub load-balances
jobs between the two machines and either one can absorb the full load when the other is down.
