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

## Tables — `DataTable` column shapes

`src/components/DataTable.tsx` accepts three column shapes, all first-class:

| shape | example | cell |
|---|---|---|
| keyed (canonical) | `{ key: 'jobs', header: 'Jobs', render?: (row, i) => … }` | `render(row, i)` if given, else `row[key]` |
| accessor | `{ header: 'Jobs', accessor: (row) => row.jobs }` | `accessor(row)`; `null`/`undefined`/`""` → `—` |
| cell | `{ header: 'Jobs', cell: (row, i) => … }` | `cell(row, i)` |

The accessor/cell shapes are what ~125 generated founder pages were written against; until 2026-09-16 the component
only knew the keyed shape, so those pages type-failed (web CI red since June) and rendered `—` in every cell.
`npm test` renders all three shapes and asserts real values; CI runs it after `npm run typecheck`.

When a table's columns are written inline with different parameter annotations per column, TypeScript infers the
row type from the first one and the rest fail — give the table an explicit row type instead:
`<DataTable<ShareRow> rows={rows} columns={[{ key: 'x', header: 'X', render: (r) => r.x }]} … />`.
