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

## Appendix: Per-PR preview subdomains on cashconsults.com

Once Workers Builds is live (Phase 1), every push already gets an automatic,
stable **Branch Preview URL** on `*.workers.dev` — Cloudflare generates it
following the pattern `<branch-name>-<worker-name>.<account-subdomain>.workers.dev`,
and it stays the same across every commit to that branch. That's the raw
material; this appendix wires two friendlier addresses on top of it:

- **`pr-<N>.cashconsults.com`** — always shows the current preview build for
  PR #`<N>`.
- **`testing.cashconsults.com`** — always shows whichever open PR was most
  recently updated, or a clean "build failed" page naming that PR if its
  build isn't currently working.
- **`testing.drrupp.org`** — since `drrupp.org` already redirects everything
  to `cashconsults.com`, this needs one extra rule so it lands on
  `testing.cashconsults.com` specifically, not the bare apex.

### Why not just compute the workers.dev alias directly?

Cloudflare's branch-name-to-subdomain sanitization (how it handles the `/`
in branch names like `claude/cloudflare-migration-guide-docs`, length
limits, hashing for long names) isn't something worth hard-coding into our
own router — it's an implementation detail that could change. Safer and
simpler: read the **actual** Branch Preview URL that Cloudflare itself posts
as a PR comment after each build (same UX as it already does for Pages), and
store `PR number → that URL` in Workers KV. The router then just does a KV
lookup — no guessing at sanitization rules.

### Architecture

- A second, separate Worker — **`cashconsults-pr-router`** — dedicated to
  this, so the production site's Worker stays pure static assets. It owns a
  wildcard **Route** (`*.cashconsults.com/*`; Routes support wildcards,
  unlike exact-hostname Custom Domains), while the main site keeps its exact
  Custom Domains (`cashconsults.com`, `www.cashconsults.com`) untouched.
- A Workers KV namespace (`PR_PREVIEWS`) mapping `pr-<N>` → the current
  Branch Preview URL for that PR.
- A GitHub Actions workflow that watches for Cloudflare's own bot comment on
  each PR, extracts the Branch Preview URL, and writes it into KV. A
  companion step clears the KV entry when the PR closes (same pattern as the
  existing `preview-cleanup.yml`).
- The router, at request time:
  - `pr-<N>.cashconsults.com` → look up `pr-<N>` in KV, proxy the request
    there; if missing or the preview errors, render a clean page linking to
    `github.com/gignsky/cashconsults-website/pull/<N>/checks`.
  - `testing.cashconsults.com` → ask the GitHub API for the most recently
    updated open PR, look up *that* PR's KV entry, proxy or show the same
    clean error page naming it.

### Temporary phase — prove it out by hand

- [ ] Create the router Worker (`wrangler init` in a new `pr-router/`
  folder, no `assets`, just a `main` script) and the `PR_PREVIEWS` KV
  namespace (`wrangler kv namespace create PR_PREVIEWS`).
- [ ] Deploy the router manually (`wrangler deploy`) and bind it to a
  **single** test hostname first — e.g. `pr-4.cashconsults.com` — rather
  than the wildcard, so nothing else on the zone is affected while
  iterating.
- [ ] Manually seed one KV entry for that PR
  (`wrangler kv key put --namespace-id=<id> pr-4 "<branch-preview-url>"`)
  and confirm `https://pr-4.cashconsults.com` proxies it correctly.
- [ ] Manually break it (e.g. point the KV value at a bad URL) and confirm
  the error page renders cleanly instead of a raw Cloudflare error.

### Permanent phase — generalize and automate

- [ ] Swap the single test hostname for the wildcard Route
  `*.cashconsults.com/*`, and add a wildcard DNS record `*.cashconsults.com`
  (proxied) — additive, doesn't touch the apex/`www`/MX/TXT records already
  there.
- [ ] Add the GitHub Actions sync workflow (watches Cloudflare's PR comment,
  writes to KV) and a cleanup step on PR close.
- [ ] Add `CLOUDFLARE_API_TOKEN` (Workers KV:Edit) and
  `CLOUDFLARE_ACCOUNT_ID` as new repo secrets for that workflow to use.
- [ ] Once the main repo goes private (Phase 4), also give the router a
  read-only `GITHUB_TOKEN` secret (fine-grained PAT, this repo only) — it
  needs to read PR metadata for the `testing.cashconsults.com` lookup, which
  stops working unauthenticated once the repo isn't public.

### testing.drrupp.org

The existing redirect rule on the `drrupp.org` zone
([`dns/drrupp.org-redirect.zone`](dns/drrupp.org-redirect.zone),
[`dns/README.md`](dns/README.md) — "All incoming requests" →
`concat("https://cashconsults.com", http.request.uri.path)`) drops the
subdomain, so `testing.drrupp.org` would otherwise redirect to bare
`cashconsults.com`, not `testing.cashconsults.com`. Fix:

- [ ] Add one more proxied placeholder record to the `drrupp.org` zone:
  `testing.drrupp.org` → `192.0.2.1` (same pattern as the existing
  `@`/`www` placeholders in `dns/drrupp.org-redirect.zone`) — additive, no
  MX/TXT impact.
- [ ] Add a second Redirect Rule on the `drrupp.org` zone, **above** the
  existing catch-all in priority: When `hostname eq "testing.drrupp.org"` →
  Dynamic redirect, expression
  `concat("https://testing.cashconsults.com", http.request.uri.path)`, same
  redirect-status and "Preserve query string" settings as the existing rule.

### Reference Worker (starting point, not tested against a live account)

```js
// pr-router/src/index.js
const REPO = "gignsky/cashconsults-website";

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const prMatch = url.hostname.match(/^pr-(\d+)\.cashconsults\.com$/);

    if (prMatch) return servePr(Number(prMatch[1]), url, env);
    if (url.hostname === "testing.cashconsults.com") return serveTesting(url, env);
    return new Response("Not found", { status: 404 });
  },
};

async function servePr(prNumber, url, env) {
  const target = await env.PR_PREVIEWS.get(`pr-${prNumber}`);
  if (!target) return errorPage(prNumber, "no preview recorded yet");
  return proxyOrError(target, url, prNumber);
}

async function serveTesting(url, env) {
  const pr = await mostRecentOpenPr(env);
  if (!pr) return errorPage("n/a", "no open PRs found");
  const target = await env.PR_PREVIEWS.get(`pr-${pr.number}`);
  if (!target) return errorPage(pr.number, "no preview recorded yet");
  return proxyOrError(target, url, pr.number);
}

async function proxyOrError(target, url, prNumber) {
  const res = await fetch(target + url.pathname + url.search);
  if (!res.ok) return errorPage(prNumber, `preview responded with HTTP ${res.status}`);
  return new Response(res.body, res);
}

async function mostRecentOpenPr(env) {
  const res = await fetch(
    `https://api.github.com/repos/${REPO}/pulls?state=open&sort=updated&direction=desc&per_page=1`,
    {
      headers: {
        "User-Agent": "cashconsults-pr-router",
        Accept: "application/vnd.github+json",
        ...(env.GITHUB_TOKEN ? { Authorization: `Bearer ${env.GITHUB_TOKEN}` } : {}),
      },
    }
  );
  if (!res.ok) return null;
  const prs = await res.json();
  return prs[0] ?? null;
}

function errorPage(prNumber, reason) {
  const checksUrl = `https://github.com/${REPO}/pull/${prNumber}/checks`;
  const html = `<!doctype html><meta charset="utf-8">
<title>Preview unavailable</title>
<body style="font:16px sans-serif;max-width:40em;margin:4em auto;padding:0 1em">
<h1>Preview unavailable</h1>
<p>PR #${prNumber} isn't showing a live preview right now: ${reason}.</p>
<p>That's the build failing, not this router — check <a href="${checksUrl}">the PR's build logs</a> for the actual error.</p>
</body>`;
  return new Response(html, { status: 502, headers: { "content-type": "text/html; charset=utf-8" } });
}
```

Adjust the KV binding name, repo slug, and GitHub API auth to match whatever
is actually configured before deploying this for real — this is a shape to
build from, not copy-paste-ready production code.

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
