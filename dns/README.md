# DNS setup — pointing the domains at GitHub Pages

The goal: serve this repo's GitHub Pages deployment on **cashconsults.com**,
with the other domains redirecting to it, **without touching any email DNS**.

**Current phase: CUTOVER to `cashconsults.com` as the primary domain**
(previously the site was tested on `cashrealestateconsulting.com`).

| Domain                        | Role                                                        |
| ----------------------------- | ---------------------------------------------------------- |
| `cashconsults.com`            | **Primary** — bound to this repo via `site/CNAME`          |
| `cashrealestateconsulting.com`| Redirect to the primary (`cashrealestateconsulting.com-redirect.zone`) |
| `drrupp.org`                  | Redirect to the primary (`drrupp.org-redirect.zone`)       |

(`rupp.life` was originally part of this plan but is reserved for another
project — nothing here touches it.)

A GitHub Pages site can be bound to exactly **one** custom domain, so every
non-primary domain is handled with Cloudflare redirect rules rather than by
pointing it at GitHub directly (GitHub would answer 404 for hostnames it
doesn't know about).

**Every file here is additive-only and contains no `MX`/`TXT` records, so
importing any of them cannot affect email** — but each has a manual pre-step
(deleting the old web records) that you must do by hand, described below.

## 1. cashconsults.com — import the GitHub Pages zone file

The file to upload is **`dns/cashconsults.com-github-pages.zone`**.

### Why this cannot break email

A Cloudflare DNS import is **additive only** — it adds the records in the
file and never deletes or edits anything already in the zone. The file
contains only `A`/`AAAA` records for the apex and one `CNAME` for `www`.
It contains **no `MX`, no `TXT`, no SPF/DKIM/DMARC** records, so mail
routing, sender authentication, and verification records are untouched no
matter what.

### Steps

1. Log in to the Cloudflare dashboard and open the **cashconsults.com** zone.
2. **(Recommended) Export a backup first:** DNS → Records →
   *Import and Export* → **Export DNS records**. Keep that file — it is your
   full current zone, email records included.
3. **Delete only the old web records, by hand:** in DNS → Records, delete any
   existing `A`, `AAAA`, or `CNAME` records whose **Name** is exactly
   `cashconsults.com` (shown as `@`) or `www` — these point at the old
   hosting and would conflict.
   **Do not delete anything else.** Specifically leave alone:
   - every `MX` record
   - every `TXT` record (SPF lives here, e.g. `v=spf1 ...`, plus DKIM/DMARC
     and any site-verification records)
   - anything named like `mail`, `smtp`, `imap`, `pop`, `autodiscover`,
     `autoconfig`, `_dmarc`, `*._domainkey`, or any `SRV` record
4. **Import:** DNS → Records → *Import and Export* → **Import DNS records** →
   select `cashconsults.com-github-pages.zone`.
   **Uncheck "Proxy imported DNS records"** so the records arrive DNS-only
   (grey cloud). GitHub can't issue the HTTPS certificate for the domain
   while Cloudflare proxies it.
5. Confirm the result: the apex should now have four `A` and four `AAAA`
   records to `185.199.10x.153` / `2606:50c0:800x::153`, and `www` should be
   a `CNAME` to `gignsky.github.io` — all grey-cloud. Every MX/TXT record
   should be exactly as it was.

Then, in **GitHub → Settings → Pages → Custom domain**, set
`cashconsults.com` (replacing `cashrealestateconsulting.com`). Once GitHub's
DNS check passes and the certificate is issued, tick **Enforce HTTPS**. You
can optionally flip the apex + `www` records to Proxied (orange cloud) with
SSL/TLS mode **Full (strict)** afterward — but DNS-only works fine and is the
simplest correct state.

## 2. Redirect domains — cashrealestateconsulting.com and drrupp.org

Both of these should send visitors to the primary. Each has its own
`-redirect.zone` file (`cashrealestateconsulting.com-redirect.zone`,
`drrupp.org-redirect.zone`) that adds two **proxied** placeholder `A` records
(`@` and `www` → `192.0.2.1`, a reserved documentation IP that never routes
anywhere) so Cloudflare answers for the hostname; a Redirect Rule then does
the actual redirect before that dead IP is ever contacted.

For each domain:

1. **Import the domain's `-redirect.zone` file** via DNS → Records →
   *Import and Export* → **Import DNS records**. Leave "Proxy imported DNS
   records" **checked** (or verify the records show orange-cloud afterward) —
   the redirect only fires on proxied records.
2. **Delete the old web records by hand.** For
   **cashrealestateconsulting.com** specifically (per the 2026-07-07 export,
   which currently holds this repo's testing-phase Pages records), delete:
   - the four apex `A` records (`185.199.108-111.153`)
   - the four apex `AAAA` records (`2606:50c0:800x::153`)
   - the `www` `CNAME` → `gignsky.github.io`

   For **drrupp.org**, delete any leftover `A`/`AAAA`/`CNAME` on `@`/`www`.
   In both zones, **keep every `MX` and `TXT` record** (Cloudflare Email
   Routing MX ×3, SPF, DKIM, DMARC, and any verification TXT) — the import
   and the redirect rule never touch them.
3. Open the zone → **Rules → Redirect Rules → Create rule**. Set **When**
   "All incoming requests" → **Then** Dynamic redirect, expression:

   ```
   concat("https://cashconsults.com", http.request.uri.path)
   ```

   status **302** (use 301 only once you're sure this is permanent), tick
   **Preserve query string**, and **Deploy**.

A redirect rule and a proxied web record have no effect on `MX`/`TXT`
records, so email keeps working throughout.

> **Note:** the redirect lands visitors on `cashconsults.com`, so it only
> shows the site once cashconsults.com itself is live on Pages (section 1).
> Until then a redirect domain will forward correctly but may hit a GitHub
> 404.

> **`testing.drrupp.org`:** this catch-all rule would otherwise redirect it
> to bare `cashconsults.com`, dropping the `testing.` subdomain. See
> [`CLOUDFLARE_MIGRATION.md`](../CLOUDFLARE_MIGRATION.md#testingdrrupporg)
> for the extra record + higher-priority rule needed to land it on
> `testing.cashconsults.com` instead.

## 3. (Optional but recommended) Verify the domains on GitHub

GitHub account-level domain verification prevents anyone else from claiming
these domains on GitHub Pages if a deployment ever lapses:

1. GitHub → your avatar → **Settings → Pages → Add a domain**.
2. GitHub gives you a `TXT` record like
   `_github-pages-challenge-gignsky.cashconsults.com` with a code.
3. Add that TXT record in Cloudflare (it's a new record — again additive,
   no effect on email) and click **Verify**.
