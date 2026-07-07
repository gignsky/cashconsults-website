# Migrating hosting to Cloudflare (Workers + static assets)

This is the runbook for moving `cashconsults.com` off GitHub Pages onto
**Cloudflare Workers with static assets**, with zero downtime, and only
making this repo private once GitHub Pages is no longer in the loop.

Cloudflare Pages still works, but as of 2026 it's in maintenance mode —
Cloudflare is steering all new and migrating static sites to Workers with
static assets instead, which now has full parity (custom domains, automatic
HTTPS, private-repo Git integration, same free tier). That's the target here,
not classic Pages.

The steps below are almost entirely manual dashboard/DNS actions on the
Cloudflare account that holds the `cashconsults.com` zone — they can't be
scripted from this repo, so this file is the checklist to work through by
hand, and to track progress against.

## Sequencing across PRs

This migration ships in two PRs, in order:

1. **This PR — the guide only.** Just this file, merged into `main` first.
2. **The config PR** — `wrangler.jsonc` (the Cloudflare Workers static-assets
   config) plus a `README.md` pointer to this guide, from
   `claude/cloudflare-pages-migration-jeo2xd`. Keep testing Phase 1 against
   that branch directly in the Cloudflare dashboard (see the branch-control
   fix below) until it's fully green, then merge that PR into `main` and
   point Cloudflare's production branch back to `main`.

**Phase 2 doesn't start until the config PR is merged** and Cloudflare is
deploying from `main` again.

## Why this can be zero-downtime

DNS for `cashconsults.com` already lives on Cloudflare (see [`dns/`](dns/)) —
the apex A/AAAA records just happen to point at GitHub Pages' IPs today.
Moving hosting to Cloudflare means the cutover is a same-provider DNS record
edit, not a cross-registrar migration, so the switch propagates across
Cloudflare's edge almost immediately instead of waiting on external resolver
TTLs.

**Do the hosting cutover before making the repo private.** GitHub Pages
historically requires a paid GitHub plan to serve from a private repo;
Cloudflare doesn't. Flipping the repo private only after GitHub Pages is
fully decommissioned means that restriction never has a chance to bite.

## Phase 1 — Stand up Cloudflare, verify in isolation

No production DNS changes in this phase — zero risk.

- [x] Cloudflare dashboard → **Workers & Pages → Create application → Import
  a repository** → connect the GitHub account/App to
  `gignsky/cashconsults-website` (fine to do while the repo is still public)
- [x] Project config: build command none, output/assets directory `site`,
  root directory = repo root (`wrangler.jsonc`, once the config PR merges,
  declares `assets.directory: "site"` at the repo root)
- [x] Save and deploy

### Troubleshooting: Worker name conflict on first deploy

The first "Save and Deploy" failed. Cloudflare built from `main`, which
doesn't have `wrangler.jsonc` yet — that file only exists on
`claude/cloudflare-pages-migration-jeo2xd` so far. Without a config file in
the checkout, `wrangler deploy` bootstrapped a brand-new one and tried to
create a Worker named `cashconsults-website` — which already existed from
the project setup — so Cloudflare's safety check refused to overwrite it:

```
✘ [ERROR] A Worker named "cashconsults-website" already exists in your
account. This deploy could not confirm that it should update that Worker,
so it stopped instead of overwriting it. To update the existing Worker, add
a Wrangler configuration file naming "cashconsults-website"; to deploy
separately, use a different name.
```

Fix (dashboard-only, no repo push needed):

- [x] Worker → **Settings → Build → Branch control** → set the production
  branch to `claude/cloudflare-pages-migration-jeo2xd` (temporarily, until
  the config PR merges to `main`)
- [x] Trigger a new deployment (push, or **Deployments → Retry/Create
  deployment**)
- [x] Confirm the new build log reads the existing `wrangler.jsonc` (no
  "📄 Create wrangler.jsonc:" step in the log) and deploys without the
  name-conflict error

Once that redeploy is confirmed green and the `*.workers.dev` preview
renders correctly (see the **Verification checklist** below), merge the
config PR and point the production branch back to `main` before moving on.

## Phase 2 — Prove the custom domain + HTTPS work before touching production DNS

- [ ] *(Optional, recommended)* Add a throwaway proxied CNAME, e.g.
  `cfcheck.cashconsults.com` → the Worker, and confirm HTTPS + correct
  rendering there first. Validates Cloudflare's proxy/cert behavior against
  the real zone without touching the apex.
- [ ] Worker → **Settings → Domains & Routes → add custom domain**:
  `cashconsults.com` (and `www.cashconsults.com` if both should resolve
  directly). Cloudflare provisions the certificate automatically — it's
  already the DNS authority for the zone, so validation is immediate.
- [ ] Cloudflare will flag the existing apex A/AAAA records (GitHub Pages
  IPs) and the `www` CNAME (`gignsky.github.io`) as conflicting.
  **Don't let it auto-overwrite yet.** Wait until the new cert shows
  **Active** while the old records are still live and still serving GitHub
  Pages traffic.

## Phase 3 — Zero-downtime cutover

- [ ] Lower the TTL on the apex/`www` records first if they aren't already
  low; pick a low-traffic window.
- [ ] In the Cloudflare DNS zone, replace:
  - Apex `cashconsults.com` A/AAAA (GitHub Pages IPs) → proxied
    CNAME/flattened record to the Worker's custom-domain target (Cloudflare
    flattens CNAMEs at the apex automatically).
  - `www` CNAME (`gignsky.github.io`) → proxied CNAME to the same target.
- [ ] Verify immediately:
  ```sh
  curl -I https://cashconsults.com
  curl -I https://www.cashconsults.com
  curl -v https://cashconsults.com   # eyeball the cert chain
  ```
  Both should return `200` with a valid cert. Also do a manual browser
  check for mixed-content/HSTS issues on the inlined JS/CSS.
- [ ] Enable **Always Use HTTPS**; confirm minimum TLS version matches what
  the zone had before.
- [ ] Monitor for ~15–30 minutes before calling the cutover done.

## Phase 4 — Decommission GitHub Pages, then go private

Only after Cloudflare has been serving production traffic cleanly for a
while (hours, not days — rollback is just restoring two DNS records to the
values already archived in
[`dns/cashconsults.com-github-pages.zone`](dns/cashconsults.com-github-pages.zone)):

- [ ] GitHub repo → **Settings → Pages** → remove the custom domain /
  disable Pages
- [ ] Remove `.github/workflows/deploy.yml` (deploy now happens via
  Cloudflare's Git integration). Keep `check.yml` — it's PR lint/preview
  only and is unrelated to hosting.
- [ ] Delete `site/CNAME` (GitHub-Pages-specific, now vestigial)
- [ ] **Now** flip the repo to private in GitHub settings
- [ ] Confirm Cloudflare's GitHub App still has access to the repo
  post-privacy (GitHub → **Settings → Integrations → GitHub Apps**) —
  usually carries over automatically, but check
- [ ] Push a trivial change and confirm Cloudflare's Git integration still
  auto-deploys from the now-private repo

## Rollback

At any point after the Phase 3 DNS swap and before Phase 4's GitHub Pages
removal, reverting is just restoring the apex A/AAAA and `www` CNAME to the
values already committed in
[`dns/cashconsults.com-github-pages.zone`](dns/cashconsults.com-github-pages.zone) —
GitHub Pages is still fully configured and able to serve immediately since it
isn't disabled until Phase 4.

## Verification checklist

- [ ] `*.workers.dev` preview renders identically to current production
- [ ] Throwaway `cfcheck.cashconsults.com` serves via Cloudflare with valid HTTPS
- [ ] Custom domain cert for `cashconsults.com` shows **Active** before DNS cutover
- [ ] Post-cutover: apex and `www` both return 200 with valid certs
- [ ] No mixed-content warnings; inlined JS runtime still paints correctly
- [ ] `cashrealestateconsulting.com` and `drrupp.org` redirects still land on the new site
- [ ] Push-to-deploy works end-to-end from the (eventually private) repo
- [ ] Old GitHub Pages config removed, `site/CNAME` deleted, `deploy.yml` removed

## Cloudflare vs. GitHub Pages, in short

| | GitHub Pages | Cloudflare (Pages / Workers static assets) |
| --- | --- | --- |
| Private repos | Requires a paid GitHub plan | Free, via GitHub App integration |
| Compute model | Static files only | Static files, with room to add edge logic (redirects, headers, auth) later |
| Custom domain + HTTPS | Free, automatic, but needs DNS-only (unproxied) records for GitHub's own cert issuance | Free, automatic; Cloudflare issues/manages the cert and expects the record proxied |
| Build system | GitHub Actions artifact upload (what this repo does today) | Cloudflare-native Git integration, or accept a pre-built artifact via `wrangler deploy` |
| PR previews | None built in (this repo hand-rolls one via a throwaway branch + screenshots) | Every branch/PR gets its own preview URL automatically |
| Rollback | Only "latest deploy"; recover by re-running an old workflow run | Prior deployments are kept; instant rollback from the dashboard |
| Cost | Free | Free at this scale |
