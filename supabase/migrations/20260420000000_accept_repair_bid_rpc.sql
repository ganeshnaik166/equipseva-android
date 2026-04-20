-- Atomic bid acceptance path used by hospitals from the repair-job detail
-- screen. The client only holds SELECT/INSERT/UPDATE permissions via RLS on
-- repair_jobs and repair_job_bids for their own rows — it has no policy that
-- lets a hospital flip a bid's status or set engineer_id on a job. This
-- SECURITY DEFINER RPC runs the whole transition atomically under the
-- function's owner role so the hospital can accept one bid without
-- round-tripping the engineer-id lookup to the client.
--
-- Steps:
--   1. Load the target bid; make sure the caller is the hospital owner of
--      the parent job and the job is still in a state that can be assigned.
--   2. Resolve the engineer row id from the bid's engineer_user_id.
--      repair_jobs.engineer_id FKs to engineers.id, not auth.uid — so we
--      have to translate before writing.
--   3. Flip the chosen bid to 'accepted', reject all other pending bids on
--      the same job, and move the job to 'assigned' with the engineer set.
-- The function returns the updated repair_jobs row as JSONB so the client
-- can refresh its detail screen without a second fetch.

create or replace function public.accept_repair_bid(p_bid_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_bid record;
  v_engineer_id uuid;
  v_job record;
begin
  -- 1. Lock the target bid + parent job. Using FOR UPDATE on the job row
  -- serialises concurrent accept attempts so only the first one wins.
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

  -- Only accept while the job is still open. Once assigned/in_progress/etc.
  -- the engineer is already chosen; swapping mid-flight is a different flow.
  if v_bid.job_status <> 'requested' then
    raise exception 'Job is no longer open for bids' using errcode = '22023';
  end if;

  -- 2. Translate the engineer's auth user id into an engineers.id row id.
  select e.id into v_engineer_id
    from public.engineers e
   where e.user_id = v_bid.engineer_user_id
   limit 1;

  if v_engineer_id is null then
    raise exception 'Engineer profile not found for bid' using errcode = 'P0002';
  end if;

  -- 3. Flip the chosen bid to accepted.
  update public.repair_job_bids
     set status = 'accepted',
         updated_at = now()
   where id = p_bid_id;

  -- Reject the remaining pending bids on the same job so engineers see their
  -- own bid state update without polling for the job's status change.
  update public.repair_job_bids
     set status = 'rejected',
         updated_at = now()
   where repair_job_id = v_bid.repair_job_id
     and id <> p_bid_id
     and status = 'pending';

  -- Assign the engineer on the parent job.
  update public.repair_jobs
     set engineer_id = v_engineer_id,
         status = 'assigned',
         updated_at = now()
   where id = v_bid.repair_job_id
   returning to_jsonb(repair_jobs) into v_job;

  return v_job;
end;
$$;

-- Only authenticated callers can invoke it; anon (public) signups never reach
-- this code path.
revoke all on function public.accept_repair_bid(uuid) from public;
grant execute on function public.accept_repair_bid(uuid) to authenticated;
