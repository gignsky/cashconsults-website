# DNS setup — pointing the domains at GitHub Pages

The goal: serve the "Site in Progress" page from this repo's GitHub Pages
deployment on all four domains, **without touching any email DNS**.

| Domain                        | Role                                        |
| ----------------------------- | ------------------------------------------- |
| `cashconsults.com`            | Primary — bound to this repo via `site/CNAME` |
| `cashrealestateconsulting.com`| Redirects to `cashconsults.com` (see below) |
| `drrupp.org`                  | Redirects to `cashconsults.com` (see below) |
| `rupp.life`                   | Redirects to `cashconsults.com` (see below) |

A GitHub Pages site can be bound to exactly **one** custom domain, so the
other three domains are handled with Cloudflare redirect rules rather than
by pointing them at GitHub directly (GitHub would answer 404 for hostnames
it doesn't know about).

## 1. cashconsults.com — import the zone file

The file to upload is **`dns/cashconsults.com-github-pages.zone`**.

### Why this cannot break email

A Cloudflare DNS import is **additive only** — it adds the records in the
file and never deletes or edits anything already in the zone. The file
contains only `A`/`AAAA` records for the apex and one `CNAME` for `www`.
It contains **no `MX`, no `TXT`, no SPF/DKIM/DMARC** records, so your mail
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
4. **Import:** DNS → Records → *Import and Export* →
   **Import DNS records** → select `cashconsults.com-github-pages.zone`.
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

## 2. The other three domains — redirect rules

For each of `cashrealestateconsulting.com`, `drrupp.org`, and `rupp.life`
(assuming they are also on Cloudflare):

1. Open the zone → **Rules → Redirect Rules → Create rule**.
2. If the zone has no `A` record on the apex, add a dummy proxied record so
   Cloudflare answers for the hostname:
   `A` record, Name `@`, IPv4 `192.0.2.1`, **Proxied (orange cloud)** —
   `192.0.2.1` is a reserved documentation IP that never routes anywhere;
   the redirect rule fires before the origin is ever contacted. Add the same
   for `www` if you want `www.` to redirect too.
3. Rule: **When** Hostname *contains* the domain (or use "All incoming
   requests" for the whole zone) → **Then** Dynamic redirect,
   expression `concat("https://cashconsults.com", http.request.uri.path)`,
   status **302** (use 301 only once you're sure this is permanent).

Email safety is the same story here: a redirect rule and a proxied web
record have no effect on `MX`/`TXT` records. Don't delete or edit any
existing mail records in those zones either.

Later, when a domain gets its own site, delete its redirect rule and give it
its own repo/deployment (a GitHub Pages site can only carry one custom
domain, so separate sites means separate repos or a multi-domain host).

## 3. (Optional but recommended) Verify the domains on GitHub

GitHub account-level domain verification prevents anyone else from claiming
these domains on GitHub Pages if a deployment ever lapses:

1. GitHub → your avatar → **Settings → Pages → Add a domain**.
2. GitHub gives you a `TXT` record like
   `_github-pages-challenge-gignsky.cashconsults.com` with a code.
3. Add that TXT record in Cloudflare (it's a new record — again additive,
   no effect on email) and click **Verify**.
