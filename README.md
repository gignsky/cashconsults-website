# cashconsults-website

The **Cash Consulting** website — Maxwell Rupp: real estate appraisals +
small-business tech support. The primary domain is
[cashconsults.com](https://cashconsults.com); `cashrealestateconsulting.com`
and `drrupp.org` redirect to it via Cloudflare redirect rules (see
[`dns/README.md`](dns/README.md)).

Structure is modeled on the [council](https://github.com/gignsky/council)
repo: a Nix flake builds and lints the static site, and Cloudflare Workers
Builds deploys `site/` straight from `main`.

Hosting moved from GitHub Pages to Cloudflare Workers (static assets); the
runbook that got it there is [`CLOUDFLARE_MIGRATION.md`](CLOUDFLARE_MIGRATION.md).

## Layout

| Path                            | What it is                                               |
| ------------------------------- | -------------------------------------------------------- |
| `site/`                         | The deployable site: `index.html` (hand-authored static HTML — the source of truth for the live markup), `support/index.html` (the CashDesk remote-help page), `_redirects` and `assets/` (optimized images). |
| `design/`                       | The original design source (`Cash Consulting Site.dc.html`), full-size assets, and the deploy handoff notes — kept as the design reference. |
| `flake.nix`                     | Builds the deployable site (running `tidy` over every page) and provides the dev shell. |
| `.github/workflows/check.yml`   | PR gate: checks and builds the flake and uploads the built site as a downloadable artifact. |
| `dns/`                          | Cloudflare import file + step-by-step DNS instructions.  |
| `wrangler.jsonc`                | Cloudflare Workers static-assets config: serves `site/`. |
| `CLOUDFLARE_MIGRATION.md`       | The runbook used to move hosting from GitHub Pages to Cloudflare. |

## Local development

With [Nix](https://nixos.org) (flakes enabled):

```sh
nix develop            # dev shell: nodejs, live-server, python3, html-tidy
live-server site       # live-reloading preview

nix build .#site       # produce the deployable tree at ./result
nix run                # preview the built site at http://localhost:8080
```

## Previewing a PR before merging

Every PR gets two previews, no dev environment needed:

- **Workers preview URL** — Cloudflare Workers Builds deploys every PR branch
  to a preview URL and posts it on the PR. That is the real deployment
  pipeline, including `_redirects`.
- **The real build** — the `site-preview` artifact on the **Build check**
  workflow run is the exact `nix build .#site` output. Download, unzip, and
  open `index.html` in a browser.

## Deployment

Cloudflare **Workers Builds** watches this repo. Every push to `main` deploys
the `site/` directory as static assets, as declared in `wrangler.jsonc`; there
is no deploy workflow in this repo and nothing to build. PR branches get
preview deployments at their own URLs. The custom domain `cashconsults.com`
is bound to the Worker in the Cloudflare dashboard, and its DNS records live
in the same Cloudflare zone (see `dns/`).

### Remote help page and the CashDesk download

`/support/` is the client-facing page for **CashDesk**, the branded remote
support client built in [`gignsky/cashdesk`](https://github.com/gignsky/cashdesk).
The site never hosts the binaries: `site/_redirects` sends
`/support/download` (Windows), `/support/download/linux` and
`/support/download/android` to that repo's *latest release* assets with a
302, so a new client release needs no site change at all.

Workers static assets read `site/_redirects` natively. If a preview
deployment ever stops honouring it, the fallback is a **Single Redirect
rule** on the `cashconsults.com` zone in the Cloudflare dashboard, with the
same three source → destination pairs.

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
