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
