# cashconsults-website

The **Cash Consulting** website — Maxwell Rupp: real estate appraisals +
small-business tech support. The primary domain is
[cashconsults.com](https://cashconsults.com), bound to this repo via
`site/CNAME`; `cashrealestateconsulting.com` and `drrupp.org` redirect to it
via Cloudflare redirect rules (see [`dns/README.md`](dns/README.md)).

Structure is modeled on the [council](https://github.com/gignsky/council)
repo: a Nix flake builds the static site, and GitHub Actions deploys the
flake output to GitHub Pages.

**Hosting is migrating to Cloudflare Workers (static assets).** See
[`CLOUDFLARE_MIGRATION.md`](CLOUDFLARE_MIGRATION.md) for the zero-downtime
cutover runbook; `wrangler.jsonc` is already in place for that migration.
Everything below describes the current (pre-migration) GitHub Pages setup.

## Layout

| Path                            | What it is                                               |
| ------------------------------- | -------------------------------------------------------- |
| `site/`                         | The deployable site: `index.html` (hand-authored static HTML — the source of truth for the live markup) and `assets/` (optimized images). |
| `design/`                       | The original design source (`Cash Consulting Site.dc.html`), full-size assets, and the deploy handoff notes — kept as the design reference. |
| `flake.nix`                     | Builds the deployable site and provides the dev shell.   |
| `.github/workflows/deploy.yml`  | Builds the flake output and publishes it to GitHub Pages.|
| `.github/workflows/check.yml`   | PR gate: builds the flake, uploads the built site as an artifact, and posts preview screenshots on the PR. |
| `.github/workflows/preview-cleanup.yml` | Deletes a PR's screenshots branch when the PR closes. |
| `dns/`                          | Cloudflare import file + step-by-step DNS instructions.  |
| `wrangler.jsonc`                | Cloudflare Workers static-assets config (`site/`), for the Cloudflare migration. |
| `CLOUDFLARE_MIGRATION.md`       | Zero-downtime runbook for migrating hosting to Cloudflare. |

## Local development

With [Nix](https://nixos.org) (flakes enabled):

```sh
nix develop            # dev shell: nodejs, live-server, python3, html-tidy
live-server site       # live-reloading preview

nix build .#site       # produce the deployable tree at ./result
nix run                # preview the built site at http://localhost:8080
```

## Previewing a PR before merging

Every PR gets two previews from the **Build check** workflow, no dev
environment needed:

- **Screenshots** — a bot comment on the PR shows full-page desktop and
  mobile renders of the built site, updated on every push (images live on a
  throwaway `pr-preview-screens/<PR#>` branch, deleted when the PR closes).
- **The real build** — the `site-preview` artifact on the workflow run is
  the exact `nix build .#site` output. Download, unzip, and open
  `index.html` in a browser.

## Deployment

Every push to `main` triggers the **Deploy site to GitHub Pages** workflow,
which runs `nix build .#site` and publishes the result to GitHub Pages. The
`site/CNAME` file binds the custom domain `cashconsults.com`.

### One-time GitHub setup (human, via the web UI)

1. **Settings → Pages → Build and deployment → Source = "GitHub Actions".**
   (Already set — the site is deploying.)
2. **Settings → Pages → Custom domain:** enter `cashconsults.com` and save
   (replacing `cashrealestateconsulting.com`). With Actions-based deploys
   this setting is authoritative (the `CNAME` file alone isn't guaranteed to
   register it), so set it explicitly. GitHub runs a DNS check — this only
   passes **after** the Cloudflare records from `dns/` are in place.
3. Once the DNS check passes and the certificate is issued (can take up to
   ~an hour), tick **Enforce HTTPS**.
4. *(Recommended)* Verify the domain at the account level — see the last
   section of [`dns/README.md`](dns/README.md).

### DNS

Everything DNS lives in [`dns/README.md`](dns/README.md):

- **`dns/cashconsults.com-github-pages.zone`** — the primary. Upload this in
  the Cloudflare dashboard (DNS → Records → Import and Export). It is
  **additive-only** and contains **no MX/TXT records, so it cannot affect
  email** — but read the manual pre-steps in `dns/README.md` first (old
  apex/`www` web records must be deleted by hand).
- **`dns/cashrealestateconsulting.com-redirect.zone`** and
  **`dns/drrupp.org-redirect.zone`** — proxied placeholder records for the
  redirect domains, which forward to `cashconsults.com` via a Cloudflare
  redirect rule (a GitHub Pages site can only carry one custom domain) —
  steps in the same file.
- `dns/exports/` — archived zone exports, kept as pre-change backups.
