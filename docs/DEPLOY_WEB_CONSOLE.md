# Deploy the Web Console to Vercel

> Founder deploy quickstart. Goal: from a fresh clone to a working
> founder console at `https://console.equipseva.com` in under 15 minutes.

---

## 1. Prereqs

You need accounts / tokens for:

- **Vercel** — free tier is enough for the founder console
- **Supabase** — already provisioned (project ref `eyswaywvtartpvtoxtdr`)
- A domain (optional but recommended) — `console.equipseva.com`

Local tools:

```bash
node --version    # 20+ required
npm --version     # 10+
npx --version
```

---

## 2. Copy env vars from Supabase dashboard

Supabase Studio → **Settings → API**. Copy two values:

- `Project URL` (already known: `https://eyswaywvtartpvtoxtdr.supabase.co`)
- `anon public` key (rotates per project — copy current value)

Don't copy the `service_role` key. It NEVER goes anywhere near the
Web Console.

---

## 3. First-time Vercel link

```bash
cd web
npx vercel login        # opens browser, completes auth
npx vercel link         # creates .vercel/ pointing at your team
```

When prompted:

- **Set up and deploy?** Yes
- **Which scope?** Pick your personal team
- **Link to existing project?** No
- **Project name?** `equipseva-console`
- **Directory?** `./` (you're already in `web/`)
- **Override settings?** No
- **Root Directory** detected as `./`

After link, set the Vercel **Root Directory** explicitly so Vercel
doesn't try to build the whole repo:

Vercel dashboard → equipseva-console project → **Settings → General →
Root Directory** → set to `web`.

---

## 4. Set Vercel environment variables

The Web Console reads exactly three NEXT_PUBLIC vars. All three are
safe to bake into the client bundle.

```bash
# Run each from inside web/ — Vercel prompts for the value.
npx vercel env add NEXT_PUBLIC_SUPABASE_URL production
# Paste: https://eyswaywvtartpvtoxtdr.supabase.co

npx vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY production
# Paste: the anon key copied in step 2

npx vercel env add NEXT_PUBLIC_FOUNDER_EMAIL production
# Paste: ganesh1431.dhanavath@gmail.com

# Optional but recommended for share-link URL composition:
npx vercel env add NEXT_PUBLIC_BASE_URL production
# Paste: https://console.equipseva.com  (or the *.vercel.app URL Vercel assigns)
```

Repeat with `preview` instead of `production` if you want preview
deploys to work too. (Founder console doesn't actually need preview
deploys; skip unless you want them.)

---

## 5. First deploy

```bash
cd web
npx vercel --prod
```

Vercel will build, deploy, and print the live URL. Open it in a
browser; you should hit `/login`.

---

## 6. Domain (optional)

Vercel dashboard → equipseva-console → **Settings → Domains** → Add
`console.equipseva.com`. Vercel shows you a CNAME / A-record. Add it
at your DNS provider, wait for verification (usually <2 min).

Update `NEXT_PUBLIC_BASE_URL` to the new domain, then redeploy:

```bash
npx vercel env rm NEXT_PUBLIC_BASE_URL production
npx vercel env add NEXT_PUBLIC_BASE_URL production
# Paste: https://console.equipseva.com
npx vercel --prod
```

---

## 7. Smoke test (do this before announcing the URL)

1. Open the live URL → should redirect to `/login`
2. Enter founder email → "Check your inbox" message
3. Open the magic link from inbox → land on `/dashboard`
4. Click through every TopBar nav item — every route should render
   (empty states are fine; real data is fine; **errors are not**)
5. Try a non-founder email at `/login` → magic link arrives, but
   landing on `/dashboard` should render the "Not authorized" error
   page (the `is_founder()` server-side gate fires)
6. Visit `/share/investor/garbage-token` → should render "Invalid link"

If any of those fail, see RUNBOOK_FOUNDER.md or check Vercel logs.

---

## 8. Wire CI/CD to auto-deploy

The repo already has `.github/workflows/web.yml` doing build + typecheck
on every PR/push touching `web/`. Vercel will auto-deploy on push to
`main` once the GitHub integration is linked:

Vercel dashboard → equipseva-console → **Settings → Git** → connect
the `ganeshnaik166/equipseva-android` repo. Pick `main` as the
production branch.

After that, every merge to main re-deploys automatically. PRs get
preview URLs (if you turned preview deploys on in step 4).

---

## 9. After-deploy housekeeping

- Mint a fresh investor share token (`/investor` → ShareTokensSection)
  to test the public surface end-to-end
- Print `/investor` to PDF as a fallback in case the share link
  surface has unexpected issues
- Bookmark `/dashboard` and `/health` — those are the daily-driver
  routes
- Add `console.equipseva.com` to 1Password as a saved login

---

## 10. What deploy automation does NOT cover

- Database migrations — those still go through `supabase db push --linked`
  on your laptop. Migration CI is a future round.
- Edge function deploys — `supabase functions deploy ...`. Future round.
- Secrets rotation — Supabase anon key, founder email — you have to
  re-run `vercel env add` manually when those change.

---

_Estimated time start-to-finish: 12 minutes if everything goes
smoothly, 20 minutes if you need to wait on DNS._
