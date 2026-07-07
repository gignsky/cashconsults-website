# cashconsults-website

The **Cash Consulting** website — Maxwell Rupp: real estate appraisals +
small-business tech support. **Currently in a testing phase with
[cashrealestateconsulting.com](https://cashrealestateconsulting.com) as the
primary domain**; the plan is to cut over to `cashconsults.com` once the
test looks good, with `drrupp.org` landing here via a Cloudflare redirect
(see [`dns/README.md`](dns/README.md)).

Structure is modeled on the [council](https://github.com/gignsky/council)
repo: a Nix flake builds the static site, and GitHub Actions deploys the
flake output to GitHub Pages.

## Layout

| Path                            | What it is                                               |
| ------------------------------- | -------------------------------------------------------- |
| `site/`                         | The deployable site (`index.html`, `CNAME`). `index.html` is compiled output — don't hand-edit it (see `design/HANDOFF.md`). |
| `design/`                       | The editable design source (`Cash Consulting Site.dc.html`), original assets, and the deploy handoff notes. |
| `flake.nix`                     | Builds the deployable site and provides the dev shell.   |
| `.github/workflows/deploy.yml`  | Builds the flake output and publishes it to GitHub Pages.|
| `.github/workflows/check.yml`   | PR gate: builds the flake, uploads the built site as an artifact, and posts preview screenshots on the PR. |
| `.github/workflows/preview-cleanup.yml` | Deletes a PR's screenshots branch when the PR closes. |
| `dns/`                          | Cloudflare import file + step-by-step DNS instructions.  |

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
`site/CNAME` file binds the custom domain `cashrealestateconsulting.com`
(the testing-phase primary).

### One-time GitHub setup (human, via the web UI)

1. **Settings → Pages → Build and deployment → Source = "GitHub Actions".**
   The workflow cannot publish until this is set.
2. Merge this branch to `main` (or run the deploy workflow manually via
   *Actions → Deploy site to GitHub Pages → Run workflow*) and wait for a
   green run.
3. **Settings → Pages → Custom domain:** enter `cashrealestateconsulting.com`
   and save. With Actions-based deploys this setting is authoritative (the
   `CNAME` file alone isn't guaranteed to register it), so set it explicitly.
   GitHub will run a DNS check — this only passes **after** the Cloudflare
   records from `dns/` are in place.
4. Once the DNS check passes and the certificate is issued (can take up to
   ~an hour), tick **Enforce HTTPS**.
5. *(Recommended)* Verify the domain at the account level — see the last
   section of [`dns/README.md`](dns/README.md).

### DNS

Everything DNS lives in [`dns/README.md`](dns/README.md):

- **`dns/cashrealestateconsulting.com-github-pages.zone`** — upload this in
  the Cloudflare dashboard (DNS → Records → Import and Export) for the
  testing phase. It is **additive-only** and contains **no MX/TXT records,
  so it cannot affect email** — but read the two manual pre-steps in
  `dns/README.md` first (one old apex CNAME must be deleted by hand).
- **`dns/cashconsults.com-github-pages.zone`** — staged for the later
  cutover to `cashconsults.com` as primary (procedure at the bottom of
  `dns/README.md`).
- **`dns/drrupp.org-redirect.zone`** — proxied placeholder records for
  `drrupp.org`, which redirects to the primary via a Cloudflare redirect
  rule (a GitHub Pages site can only carry one custom domain) — steps in
  the same file.
- `dns/exports/` — archived zone exports, kept as pre-change backups.
