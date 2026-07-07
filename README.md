# cashconsults-website

The temporary **"Site in Progress"** landing page for
**[cashconsults.com](https://cashconsults.com)** — and, for now, the landing
target for `cashrealestateconsulting.com`, `drrupp.org`, and `rupp.life`
via Cloudflare redirects.

Structure is modeled on the [council](https://github.com/gignsky/council)
repo: a Nix flake builds the static site, and GitHub Actions deploys the
flake output to GitHub Pages.

## Layout

| Path                            | What it is                                               |
| ------------------------------- | -------------------------------------------------------- |
| `site/`                         | The static site source (`index.html`, `CNAME`).          |
| `flake.nix`                     | Builds the deployable site and provides the dev shell.   |
| `.github/workflows/deploy.yml`  | Builds the flake output and publishes it to GitHub Pages.|
| `.github/workflows/check.yml`   | PR gate: the flake must build before merging to main.    |
| `dns/`                          | Cloudflare import file + step-by-step DNS instructions.  |

## Local development

With [Nix](https://nixos.org) (flakes enabled):

```sh
nix develop            # dev shell: nodejs, live-server, python3, html-tidy
live-server site       # live-reloading preview

nix build .#site       # produce the deployable tree at ./result
nix run                # preview the built site at http://localhost:8080
```

## Deployment

Every push to `main` triggers the **Deploy site to GitHub Pages** workflow,
which runs `nix build .#site` and publishes the result to GitHub Pages. The
`site/CNAME` file binds the custom domain `cashconsults.com`.

### One-time GitHub setup (human, via the web UI)

1. **Settings → Pages → Build and deployment → Source = "GitHub Actions".**
   The workflow cannot publish until this is set.
2. Merge this branch to `main` (or run the deploy workflow manually via
   *Actions → Deploy site to GitHub Pages → Run workflow*) and wait for a
   green run.
3. **Settings → Pages → Custom domain:** enter `cashconsults.com` and save.
   With Actions-based deploys this setting is authoritative (the `CNAME`
   file alone isn't guaranteed to register it), so set it explicitly.
   GitHub will run a DNS check — this only passes **after** the Cloudflare
   records from `dns/` are in place.
4. Once the DNS check passes and the certificate is issued (can take up to
   ~an hour), tick **Enforce HTTPS**.
5. *(Recommended)* Verify the domain at the account level — see the last
   section of [`dns/README.md`](dns/README.md).

### DNS

Everything DNS lives in [`dns/README.md`](dns/README.md):

- **`dns/cashconsults.com-github-pages.zone`** — upload this in the
  Cloudflare dashboard (DNS → Records → Import and Export). It is
  **additive-only** and contains **no MX/TXT records, so it cannot affect
  email** — but read the two manual pre-steps in `dns/README.md` first.
- The other three domains are handled with Cloudflare **redirect rules**
  to `cashconsults.com` (a GitHub Pages site can only carry one custom
  domain) — steps in the same file.
