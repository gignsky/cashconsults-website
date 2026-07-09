# Cash Consulting — Website Deploy Handoff

> **STATUS (July 2026): superseded.** The compiled-bundle delivery described in
> this document has been replaced: `site/index.html` is now hand-authored,
> pre-rendered static HTML (with responsive/mobile styles and images in
> `site/assets/`), and is the source of truth for the live markup. The
> `.dc.html` file here remains the design reference (visual intent, copy
> provenance). The CNAME/GitHub-Pages deploy steps below are also obsolete —
> hosting is Cloudflare Workers static assets (see `wrangler.jsonc` and
> `CLOUDFLARE_MIGRATION.md`). The rest of this document is kept for history.

A finished redesign of the Cash Consulting site (Maxwell Rupp — real estate
appraisals + small-business tech support). This bundle is meant to be handed
to Claude Code to **deploy into the `gignsky/cashconsults-website` repo**.

---

## TL;DR for the deploying agent

The repo builds a static site with a Nix flake and publishes `site/` to GitHub
Pages. The redesign is a **single self-contained HTML file**. To deploy:

1. `git clone` (or open) `gignsky/cashconsults-website`.
2. Create a branch, e.g. `redesign-launch`.
3. Replace `site/index.html` with the `index.html` from this bundle.
4. **Do NOT touch `site/CNAME`** — it binds the custom domain. Leave it exactly as-is.
5. Do not add any other files to `site/` (fonts, images, JS are all inlined into `index.html`).
6. Commit, push, open a PR against `main`.
7. The `check.yml` PR gate runs `nix build .#site` — it should pass unchanged, since `site/` still contains only `index.html` (+ the existing `CNAME`).
8. On merge to `main`, `deploy.yml` publishes to GitHub Pages automatically.

```sh
git checkout -b redesign-launch
cp /path/to/this-bundle/index.html site/index.html   # keep site/CNAME
git add site/index.html
git commit -m "Replace 'Site in Progress' placeholder with full Cash Consulting site"
git push -u origin redesign-launch
# then open the PR against main in the GitHub UI
```

---

## What's in this bundle

| Path | What it is |
| --- | --- |
| `index.html` | **The deployable site.** Fully self-contained — fonts, images, and the render runtime are inlined. Works offline by opening it directly. This becomes `site/index.html`. |
| `source/Cash Consulting Site.dc.html` | The editable source (a Design Component). Edit this, not the compiled `index.html`, for future changes — then re-bundle. |
| `source/assets/floorplan.png` | The property building-sketch image used in the Real Estate section (PII already cropped out). |
| `source/uploads/Headshot.jpg` | Maxwell's headshot used in the About section. |

`index.html` is the compiled output of `source/Cash Consulting Site.dc.html`.
**Never hand-edit `index.html`** — change the source and recompile.

---

## Important caveats

- **CNAME:** the repo's `site/CNAME` sets the custom domain
  (`cashrealestateconsulting.com` during the testing phase). Preserve it. The
  redesign does not include or manage a CNAME.
- **JavaScript-rendered:** this build paints via a small client-side runtime
  (inlined). It works in every modern browser, but crawlers/no-JS visitors see
  a splash icon rather than the text. It's fine to launch with, but a
  **pre-rendered / static-HTML version is a recommended follow-up** for SEO and
  lighter load. (The design is identical; only the delivery differs.)
- **Contact form:** the form uses a `mailto:` action — it opens the visitor's
  email client pre-filled to `maxwell@cashconsults.com`. It does **not** send
  server-side. To make it deliver automatically, wire it to a form service
  (e.g. Web3Forms/Formspree) — needs an access key.

---

## The design, in brief

Single-page site, deep-green + sage brand (from the logo), classy serif type
(Playfair Display headings, Newsreader body, Kaushan Script accents).

**Sections (top to bottom):**
1. **Sticky nav** — logo mark + wordmark, links (Real Estate / Business Support / About), phone CTA pill.
2. **Hero** — "Two things I do well. Both without the runaround." + book/call CTAs.
3. **The Split** — two side-by-side panels: Real Estate (light) vs. Small Business Support (dark).
4. **Real Estate** — Appraisals (primary, marked INDEPENDENT · UNBIASED, with a "How hiring works" note re: lender-ordered purchase/refi appraisals), Measurements (add-on), Photography (on request), + the building-sketch image.
5. **Business Support** — cards: Tech Support, Business Data Management, Servers & Networks, Custom Software & Systems, and a catch-all "Not sure it fits a box?".
6. **About** — headshot, bio, "Why 'Cash'?" note, trust stats (5+ yrs in the field, Certified Residential Appraiser since 2023, Greater Charlotte NC, lifetime with tech).
7. **Contact** — call / email / service-area cards + the quote form.
8. **Footer** — name, phone, email.

### Brand tokens
- Deep green (brand): `#094d2c`  ·  darkest: `#06341e` / `#04250f`  ·  mid: `#0d5f38`
- Sage accent: `#9bc078`  ·  light sage: `#c6dfac`
- Paper background: `#faf8f1`  ·  warm panel: `#f4f1e8`  ·  ink text: `#14261c`
- Fonts (Google Fonts): Playfair Display, Newsreader, Kaushan Script

### Contact details baked into the site
- Phone: **704-292-6994**
- Email: **maxwell@cashconsults.com**
- Service area: **Greater Charlotte area, North Carolina**

---

## Editing later

The source is a Design Component (`.dc.html`). If Cash Consulting is edited in
its original design tool, re-export/re-bundle to produce a fresh self-contained
`index.html`, then repeat the deploy steps. If editing by hand in a normal repo
instead, treat `index.html` as the artifact and keep the design intent above as
the reference.
