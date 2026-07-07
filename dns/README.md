# DNS setup — pointing the domains at GitHub Pages

The goal: serve this repo's GitHub Pages deployment on the CASH Consults
domains, **without touching any email DNS**.

**Current phase: TESTING with `cashrealestateconsulting.com` as the primary
domain.** Once the test looks good, the plan is to cut over to
`cashconsults.com` as primary (see "Cutover" at the bottom).

| Domain                        | Role (testing phase)                                  |
| ----------------------------- | ----------------------------------------------------- |
| `cashrealestateconsulting.com`| **Primary** — bound to this repo via `site/CNAME`     |
| `cashconsults.com`            | Not yet touched (zone file staged for the cutover)    |
| `drrupp.org`                  | Redirect to the primary (`drrupp.org-redirect.zone`)  |

(`rupp.life` was originally part of this plan but is reserved for another
project — nothing here touches it.)

A GitHub Pages site can be bound to exactly **one** custom domain, so every
non-primary domain is handled with Cloudflare redirect rules rather than by
pointing it at GitHub directly (GitHub would answer 404 for hostnames it
doesn't know about).

## 1. cashrealestateconsulting.com — import the zone file

The file to upload is **`dns/cashrealestateconsulting.com-github-pages.zone`**.

### Why this cannot break email

A Cloudflare DNS import is **additive only** — it adds the records in the
file and never deletes or edits anything already in the zone. The file
contains only `A`/`AAAA` records for the apex and one `CNAME` for `www`.
It contains **no `MX`, no `TXT`, no SPF/DKIM/DMARC** records, so mail
routing, sender authentication, and verification records are untouched no
matter what.

### Steps

These steps were checked against the zone export from 2026-07-07, which
contains exactly one web record and six email/verification records.

1. Log in to the Cloudflare dashboard and open the
   **cashrealestateconsulting.com** zone.
2. **(Recommended) Export a backup first:** DNS → Records →
   *Import and Export* → **Export DNS records**. Keep that file — it is your
   full current zone, email records included.
3. **Delete exactly one record:** the proxied apex `CNAME`
   `cashrealestateconsulting.com → www.cashconsults.com`. That is the only
   existing web record and it would conflict with the GitHub Pages records.
   (There is currently no `www` record, so nothing else needs deleting.)
   **Do not delete anything else.** In this zone that means keeping:
   - the three `MX` records (`route1/2/3.mx.cloudflare.net` —
     Cloudflare Email Routing)
   - the SPF `TXT` on the apex (`v=spf1 include:_spf.mx.cloudflare.net ~all`)
   - the DKIM `TXT`s (`cf2024-1._domainkey` and `*._domainkey`)
   - the DMARC `TXT` (`_dmarc`)
   - the Canva verification `TXT` (`_canva-domain-verify`)
4. **Import:** DNS → Records → *Import and Export* →
   **Import DNS records** → select
   `cashrealestateconsulting.com-github-pages.zone`.
   **Uncheck "Proxy imported DNS records"** so the records arrive DNS-only
   (grey cloud). GitHub can't issue the HTTPS certificate for the domain
   while Cloudflare proxies it.
5. Confirm the result: the apex should now have four `A` and four `AAAA`
   records to `185.199.10x.153` / `2606:50c0:800x::153`, and `www` should be
   a `CNAME` to `gignsky.github.io` — all grey-cloud. Every MX/TXT record
   should be exactly as it was.

Once GitHub has issued the certificate and **Enforce HTTPS** is on (see the
GitHub setup section in the main README), you can optionally flip the apex
and `www` records to Proxied (orange cloud) with SSL/TLS mode **Full
(strict)** — but DNS-only works fine and is the simplest correct state.

## 2. Non-primary domains — redirect rules

For each domain that should land on the primary (`drrupp.org` now, and —
after the cutover — `cashrealestateconsulting.com` itself), assuming the
zone is on Cloudflare:

1. **Import the domain's `-redirect.zone` file** (e.g.
   `drrupp.org-redirect.zone`) via DNS → Records → *Import and Export* →
   **Import DNS records**. It adds two **proxied** placeholder `A` records
   (`@` and `www` → `192.0.2.1`, a reserved documentation IP that never
   routes anywhere) so Cloudflare answers for the hostname. As with every
   file here it is additive-only and contains no MX/TXT records. Delete any
   old `A`/`AAAA`/`CNAME` records on `@`/`www` first; touch nothing else.
2. Open the zone → **Rules → Redirect Rules → Create rule**.
3. Rule: **When** "All incoming requests" → **Then** Dynamic redirect,
   expression
   `concat("https://cashrealestateconsulting.com", http.request.uri.path)`,
   status **302** (use 301 only once you're sure this is permanent). The
   rule fires before the placeholder origin is ever contacted.

Email safety is the same story here: a redirect rule and a proxied web
record have no effect on `MX`/`TXT` records. Don't delete or edit any
existing mail records in those zones either.

## 3. (Optional but recommended) Verify the domains on GitHub

GitHub account-level domain verification prevents anyone else from claiming
these domains on GitHub Pages if a deployment ever lapses:

1. GitHub → your avatar → **Settings → Pages → Add a domain**.
2. GitHub gives you a `TXT` record like
   `_github-pages-challenge-gignsky.cashrealestateconsulting.com` with a code.
3. Add that TXT record in Cloudflare (it's a new record — again additive,
   no effect on email) and click **Verify**.

## Cutover: making cashconsults.com the primary later

When the test on `cashrealestateconsulting.com` looks good:

1. Import **`dns/cashconsults.com-github-pages.zone`** into the
   `cashconsults.com` Cloudflare zone (same steps and same email-safety
   rules as section 1).
2. In this repo, change `site/CNAME` to `cashconsults.com` and merge to
   `main` so the deploy publishes the new binding.
3. GitHub → **Settings → Pages → Custom domain**: replace
   `cashrealestateconsulting.com` with `cashconsults.com`; re-tick
   **Enforce HTTPS** once the new certificate is issued.
4. Give `cashrealestateconsulting.com` a redirect rule to
   `https://cashconsults.com` (section 2, with the target swapped) — its
   GitHub Pages A/AAAA records can stay or be deleted; the proxied dummy
   record + redirect rule takes precedence either way once you switch the
   apex/www records to Proxied. Simplest: flip its apex + `www` records to
   Proxied and add the redirect rule.
