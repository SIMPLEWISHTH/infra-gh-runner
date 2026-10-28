# CI Runner Fleet — Mandatory Rules for All Agents and Developers

**Version:** 2026-10-06 · **Owner:** infra (ZCode) · **Applies to:** all repos under `SIMPLEWISHTH` (org), `digital-simplewish`, `chatchawan-simplewish`
**Purpose:** hand this document to every AI agent (Claude / Codex / Cursor / etc.) and human developer that creates or edits GitHub Actions workflows. Add it to each repo's `CLAUDE.md` / `AGENTS.md` / contributor docs.

---

## 1. The one rule that matters

Every Linux x64 job in every workflow MUST declare:

```yaml
runs-on: [self-hosted, Linux, X64, ubuntu-latest]
```

**Never** write bare `runs-on: ubuntu-latest` in a **private** repo.

Why: our GitHub accounts have a spending limit that **fails GitHub-hosted jobs before they start** ("The job was not started because recent account payments have failed or your spending limit needs to be increased"). A bare `ubuntu-latest` selector matches the GitHub-hosted pool first, so the job dies pre-execution with zero steps run. The explicit label set forces dispatch to our own runner fleet, which is free and unaffected by the spending limit.

Exception: `runs-on:` driven by a matrix that includes `windows-latest` / `macos-*` / `arm` images must stay as-is — the fleet is Linux x64 only; those jobs run on GitHub-hosted (free for public repos; avoid adding new ones in private repos).

## 2. What the fleet is (2026-10-06)

| Tier | Machines | Runners | Serves |
|---|---|---|---|
| 1st — Hetzner | hetzner-sw02-fsn1 (16 vCPU/32G, Coolify project "GitHub Runners", ~80% capped) | `hz-runner-*` (12 containers) | org + 10 digital repos + OmniRoute |
| 2nd — LXC9104 | prox-01-swserver container 9104 `prox01-gh-runner` (24 vCPU/24G, 400G runner disk) | `prox01-gh-runner-*` (14 services) | same scopes, twin of each Hetzner runner |
| 3rd — GitHub-hosted | n/a | n/a | last resort only; **payment-blocked for private repos** |

- Pairs share identical labels → GitHub **load-balances when both are online and fails over automatically** when one is down (e.g. prox-01 maintenance: jobs simply move to Hetzner).
- Org repos (`SIMPLEWISHTH/*`) are covered by the org-level pair (`hz-runner-org` / `prox01-gh-runner-org`) — no per-repo setup needed.
- Repo-scoped: `dreamjob-web`, `dreamjobs-platform`, `dreamjobs-backend`, `dj-enrich-contract`, `dj-enrich-runner`, `dreamjobs-translayer`, `portal-mini-tools`, `PHUM-GEO-engine`, `limousine`, `ai-plus`, `chatchawan-simplewish/OmniRoute` each have a dedicated pair.
- OmniRoute (public) also carries labels `omni-light` / `omni-build` for its `USE_VPS_RUNNER` conditional lanes (toggle currently `true`).

## 3. Agent workflow conventions (add to your prompt/conventions file)

1. When creating any new workflow file, use the fleet selector from §1 by default.
2. When editing an existing workflow, check every `runs-on:` line you touch — and fix any bare `ubuntu-latest` you see nearby (one-line `sed` is fine).
3. Do NOT register new self-hosted runners or add labels without coordinating with infra — runner scope (org vs repo) and label consistency are load-balancing-critical. To cover a **new private repo**: ask infra (a pair registration is a 10-minute task).
4. Fixed-port services in CI (databases, dev servers like `vite` on 4173/5173): prefer ephemeral/`0` ports or unique ports per workflow. Multiple fleet runners share two machines, and concurrent jobs from different repos can collide on fixed ports.
5. Verification after your change: check the run's job — requested labels must include `self-hosted`, and the job must show a runner name starting with `hz-runner-` or `prox01-gh-runner`. A run that fails with **zero steps** and a payments/spending-limit annotation = your selector is wrong (or was reverted).
6. Known runner environment (already installed, don't re-install in jobs): Docker (services/`container:` jobs work), Chromium + Playwright system libs, Python 3 + toolcache 3.10/3.12 (for `actions/setup-python` — note: setup-python has **no Debian-12 downloads**, the toolcache provides them on the LXC9104 side), Node via setup-node, pnpm.

## 4. Recurrence warning (why this doc exists)

Fleet selectors have been silently reverted **three times** by agent-generated commits (2026-10-06: `dreamjobs-backend`, `ai-plus`, `PHUM-GEO-engine`). Each revert broke CI for that repo (payment-block, zero-step failures) until re-patched. Treat §1 as a repo convention, not a one-time fix.

## 5. Quick reference

- Fleet image + compose: `SIMPLEWISHTH/infra-gh-runner` (public).
- Runner status (org): `gh api orgs/SIMPLEWISHTH/actions/runners --jq '.runners[] | [.name,.status]'` (needs org rights) or GitHub UI → org Settings → Actions → Runners.
- Selector check for a repo: `gh api repos/<owner>/<repo>/contents/.github/workflows/<file> --jq .content | base64 -d | grep runs-on`.
- Escalation: infra session (ZCode) can re-run the fleet-wide rescan on request.

## 6. Billing verdict (Codex-confirmed 2026-10-07) — do NOT change billing

- Self-hosted execution is free; the fleet needs **no payment method, no budget/limit changes**. Keep the existing `$0 / Stop usage` budgets as-is.
- A Free org already gets 2,000 included hosted minutes/month for private repos; the card on file only matters for paid usage beyond allowances. Do not add cards to personal accounts.
- **Queued jobs FAIL after 24 hours** waiting for a runner (they do not wait forever) — if a runner outage could exceed 24h, escalate.

## 7. Disaster runbook (if fleet machines are down)

1. Jobs with `[self-hosted, ...]` selectors queue and auto-resume when any runner returns. You have ~24h before queued jobs fail.
2. **Preferred recovery = bring any runner back** (LXC9104: `systemctl start 'actions.runner.*'` on prox-01 container 9104; Hetzner: containers auto-restart with the host, or `docker compose -p gh-org-extra -f /root/org-extra.yaml up -d` for the org-extra stack).
3. There is NO automatic GitHub-hosted fallback with self-hosted selectors. A paid emergency fallback would require: valid payment method on the **repository-owning account**, a hard Actions budget with alerts, overlapping-budget check, then **manually flipping selectors and triggering fresh runs** (reruns keep the old event/commit). The org's card does not fund personal-account repositories. Do not attempt this without the owner.
4. After any outage: check queued runs were picked up or re-dispatch failed ones.

## 8. Resource limits (added 2026-10-28 after dreamjobs-platform OOM incident)

- **Incident:** 2026-10-26, platform CI exit 137 on `hz-runner-dreamjobs-platform`. Root cause: the fleet template shipped `mem_limit: 1g` / `cpus: 0.5-0.6` to 10 repo-scoped hz runner containers. A plain `pnpm install` peaks above 1 GiB (probe: `memory.peak` 1,078 MB, `oom_kill` incrementing); the host has **no swap**, so cgroup limits were hard walls. Same label had a healthy prox01 twin, so jobs alternated pass/kill.
- **Fix (2026-10-28):** all 10 undersized hz containers (9 fleet + harnes) raised live via `docker update` to **mem 6g / memswap 12g / cpus 4**, and persisted in the Coolify DB composes (services `24tldf54b3j0sir3u5sonnx0`, `rgkycbqo5ioemowfyrm3yksl`) so redeploys keep it. Template `compose.yaml` updated to the same floor. Verified: cgroup readback 6g/4cpu on all 10, 3.5 GB allocation test survived (old peak ceiling was 1,078 MB), zero container recreates.
- **Floor rule for new repo-scoped hz runners:** `cpus: "4"`, `mem_limit: 6g`. web=6g/4cpu and org=8g/4cpu already comply. org-extra slots stay 3g/1.5cpu — watch item: platform-class builds peak ~4 GB and could OOM a 3g slot; raise before running monorepo builds there.
- **Rollback:** `docker update --memory 1g --memory-swap 2g --cpus 0.6 <container>` per container, or redeploy the pre-change compose (host backups: `docker-compose.yml.bak-20261028-limits` in both Coolify service dirs). Evidence pack: `SW-Adhoc/runner-setup-20261005/incident-20261028-hz-oom/`.
