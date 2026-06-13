# EquipSeva Founder Console

v0 read-mostly Next.js shell over the founder_* Supabase RPCs.

## Setup

```bash
cd web
npm install
cp .env.example .env.local   # then fill in SUPABASE_ANON_KEY
npm run dev                  # http://localhost:3000
```

## Auth

Magic link only. Sign in at `/login` with `ganesh1431.dhanavath@gmail.com`.
The `is_founder()` RPC gate rejects every other email server-side, so
even if the client UI is bypassed every founder RPC returns
`ERRCODE 42501` for non-founders.

## Pages (v0)

| Route        | RPC                                                         |
| ------------ | ----------------------------------------------------------- |
| `/dashboard` | `founder_hero_kpis`                                         |
| `/disputes`  | `founder_dispute_queue`                                     |
| `/risk`      | `founder_open_collusion_flags` + `founder_open_duplicate_flags` |

The risk page wires two server actions to `founder_resolve_collusion_flag`
and `founder_resolve_duplicate_flag` — confirm-or-mark-false-positive in
one click.

## Deploy to Vercel

```bash
npx vercel link        # set Root Directory = web
npx vercel env add NEXT_PUBLIC_SUPABASE_URL
npx vercel env add NEXT_PUBLIC_SUPABASE_ANON_KEY
npx vercel env add NEXT_PUBLIC_FOUNDER_EMAIL
npx vercel --prod
```

## Explicitly NOT in v0

- No design system (raw Tailwind utility classes)
- No tests yet — founder is sole user
- No realtime / SSE / polling — page reload is fine
- No drill-down pages — founder uses Android app for decisive actions
- 39 of 42 founder RPCs unwired — add as needs surface
