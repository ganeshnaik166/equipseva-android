# Scaling map — EquipSeva v2

Concrete plan for keeping the app responsive as MAU grows from launch
through 10K → 100K → 1M users. Updated 2026-05-04.

## Cliffs already addressed

These were the *real* scaling cliffs at moderate volumes; the
2026-05-04 perf pass shipped them:

- **Engineer-directory ranking** (`engineers_directory_search`) sorted
  by `rating_avg DESC, total_jobs DESC` over a full table scan. Now
  backed by a partial index keyed on
  `(rating_avg DESC, total_jobs DESC) WHERE verification_status='verified'`
  + a city-rated index for district filters.
- **Open-jobs feed** (`list_nearby_repair_jobs`) filtered
  `status IN ('requested','assigned')` over a full scan. Partial index
  on `(status, created_at DESC)` covers the predicate verbatim.
- **Hospital active-jobs list** (`fetchByHospitalUser`) had no index
  on `hospital_user_id`; added composite
  `(hospital_user_id, status, created_at DESC)`.
- **Engineer rating aggregator** trigger recomputes
  `rating_avg / total_jobs` from `repair_jobs` filtered to the engineer
  + completed status. New partial index
  `(engineer_id, completed_at DESC) WHERE status='completed'`.
- **Recent reviews RPC** (`engineer_recent_reviews`) — same engineer
  filter plus `hospital_review IS NOT NULL`. Tighter partial index
  `WHERE status='completed' AND hospital_review IS NOT NULL`.
- **Bid lifecycle queries** (engineer "My Bids", hospital detail bid
  list) — composite indexes on
  `(engineer_user_id, status, created_at DESC)` and
  `(repair_job_id, status, amount_rupees)`.
- **Notifications unread badge** — was scanning entire user inbox;
  added partial index `(user_id) WHERE is_read=false`.
- **Admin pending queues** (`admin_pending_engineers`,
  `admin_pending_seller_verifications`) returned ALL pending rows in
  one shot. Now take `p_limit` (default 50, max 200) + `p_offset`.
  Existing Android call sites stay compatible — defaults apply.
- **TTL helpers** for the three tables with unbounded growth:
  `purge_old_notifications` (read + 90d), `purge_old_content_reports`
  (reviewed + 1y), `purge_old_device_integrity_checks` (passing 30d /
  failing 1y). Wire to pg_cron OR a Supabase scheduled edge function
  once the app crosses ~10K MAU.

## Cliffs deferred (with rationale)

- **PostGIS migration** for `list_nearby_repair_jobs` haversine. The
  current Postgres-side haversine with the `(status, created_at)`
  partial index is fine through ~100K open jobs. PostGIS becomes
  worthwhile when the open-job pool exceeds 100K AND distance ranking
  is the dominant cost. Until then, the migration risk + cross-cutting
  schema reshape isn't justified.
- **`send_push_notification` batching.** Today the trigger fires one
  edge-function invocation per `notifications` row. At ~1000+
  notifications/min this would saturate the Pro-plan 100-concurrent
  edge-function limit. Move to a `push_notification_queue` table +
  cron-batched flusher when invocation telemetry shows the ceiling
  approaching. (Sentry / Supabase logs will catch this.)
- **Notifications `REPLICA IDENTITY` change.** Switching from `FULL`
  to `DEFAULT` reduces realtime replication bandwidth, but the change
  is risky on a live DB and the volume isn't there yet.
- **Chat-message TTL.** Soft-deleted rows could be purged after 30
  days, but deleted-message restore is a likely future feature.
  Storage cost stays minor under 100K MAU. Revisit when avg
  conversation length crosses ~1000 messages.
- **`pg_trgm` GIN index** on `profiles.full_name` for the directory's
  ILIKE search. Cheap to add later; meaningful only when the
  directory holds 100K+ engineers.
- **Edge-function rate limiting** on `request-call-session` /
  `verify-razorpay-payment`. Adds DoS-resistance but doesn't move the
  scalability needle until paid traffic is real.

## Plan tiers — Supabase

| MAU | Plan | Cost | Why |
|---|---|---|---|
| <10K | Free / Pro | $0 / $25 | Free tier covers 50K MAU but Pro buys daily backups + better Realtime cap (500 channels) |
| 10K-100K | Pro / Team | $25 / $599 | Team unlocks 2500 Realtime channels + 1TB DB + read replicas |
| 100K-1M | Team + add-ons | $599 + read-replicas + larger DB | Replicas serve hot read paths (directory, open jobs); primary handles writes |
| 1M+ | Enterprise | Custom | Dedicated infra + unlimited Realtime + SLAs |

## Plan tiers — Exotel (phone masking)

| MAU | ExoPhones | Voice cost / mo | Strategy |
|---|---|---|---|
| <10K | 1 | ₹500 + ~₹500-2K talk | Single ExoPhone, click-to-call mode |
| 10K-100K | 2-3 | ₹1.5K + ~₹5-15K talk | Pool ExoPhones across regions to reduce inter-circle charges |
| 100K-1M | dedicated SIP-trunk | negotiable | Move to direct SIP integration, drop per-call markup |

## Monitoring guardrails

Check once a month for the first 6 months:

1. `EXPLAIN ANALYZE` on the engineer-directory RPC for the top
   district. If `Seq Scan` on `engineers` reappears, the partial
   index isn't being picked → check the query's WHERE clause matches
   the index predicate verbatim.
2. Supabase dashboard → Realtime → channel count. >70% of plan cap
   means it's time to upgrade tier OR pool channels client-side.
3. Edge-function dashboard → `send_push_notification` p99 latency.
   >2s means the queue is building; ship the batching refactor.
4. `notifications` row count by user. Hot users with >10K notifications
   need accelerated TTL or pagination on the inbox query.

## Rollout discipline

- New RPCs ALWAYS take `LIMIT` (clamped server-side, default ≤50). No
  exceptions even for "tiny" tables — a tiny table at 10K users is no
  longer tiny at 1M.
- New tables ALWAYS get an index on the FK columns used by RLS
  policies. The
  `repair_job_cost_revisions_select_participant` policy joins to
  `repair_jobs(id)` which is fine because PK; if you join to a
  non-PK column, add the index up front.
- Long-lived rows (audit / event tables) ALWAYS ship with a TTL
  helper in the same migration. Schedule wiring is ops; the helper
  itself is the developer's responsibility.
- Realtime subscriptions ALWAYS filter at the realtime layer (not
  just RLS) — `filter("user_id", FilterOperator.EQ, userId)`.
  Without it, every connected client receives every row's broadcast
  and discards locally.
