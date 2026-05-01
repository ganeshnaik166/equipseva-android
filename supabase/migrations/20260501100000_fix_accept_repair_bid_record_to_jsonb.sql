-- Fix accept_repair_bid: declared `RETURNS jsonb` but `v_job` was a record,
-- so `return v_job` returned a single-field row whose textual representation
-- starts with `(` — PostgREST then fails to parse it as JSON and the client
-- gets "Something went wrong. Please try again." instead of the assigned job.
--
-- Repro: hospital owner signs in, opens a Requested job with one Pending bid,
-- taps "Accept this bid". RPC errors with code 22P02 / "invalid input syntax
-- for type json".
--
-- Fix: declare v_job as jsonb directly, and use repair_jobs.* in the
-- RETURNING clause so to_jsonb gets the row, not the table reference.

create or replace function public.accept_repair_bid(p_bid_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_bid record;
  v_engineer_id uuid;
  v_job jsonb;
begin
  select b.id, b.repair_job_id, b.engineer_user_id, b.status, rj.hospital_user_id, rj.status as job_status
    into v_bid
    from public.repair_job_bids b
    join public.repair_jobs rj on rj.id = b.repair_job_id
   where b.id = p_bid_id
   for update of rj;

  if not found then
    raise exception 'Bid not found' using errcode = 'P0002';
  end if;

  if v_bid.hospital_user_id <> auth.uid() then
    raise exception 'Only the hospital owner can accept bids' using errcode = '42501';
  end if;

  if v_bid.status <> 'pending' then
    raise exception 'Only pending bids can be accepted' using errcode = '22023';
  end if;

  if v_bid.job_status <> 'requested' then
    raise exception 'Job is no longer open for bids' using errcode = '22023';
  end if;

  select e.id into v_engineer_id
    from public.engineers e
   where e.user_id = v_bid.engineer_user_id
   limit 1;

  if v_engineer_id is null then
    raise exception 'Engineer profile not found for bid' using errcode = 'P0002';
  end if;

  update public.repair_job_bids
     set status = 'accepted',
         updated_at = now()
   where id = p_bid_id;

  update public.repair_job_bids
     set status = 'rejected',
         updated_at = now()
   where repair_job_id = v_bid.repair_job_id
     and id <> p_bid_id
     and status = 'pending';

  update public.repair_jobs
     set engineer_id = v_engineer_id,
         status = 'assigned',
         updated_at = now()
   where id = v_bid.repair_job_id
   returning to_jsonb(repair_jobs.*) into v_job;

  return v_job;
end;
$$;
