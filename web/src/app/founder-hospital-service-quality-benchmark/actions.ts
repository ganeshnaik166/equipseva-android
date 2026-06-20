'use server';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';

export async function recomputeQuarterAction(fd: FormData) {
  const sb = await getSupabaseServerClient();
  const quarter = String(fd.get('quarter') ?? '');
  await sb.rpc('founder_hospital_sq_recompute_quarter', { p_quarter: quarter });
  revalidatePath('/founder-hospital-service-quality-benchmark');
}

export async function logReviewActionAction(fd: FormData) {
  const sb = await getSupabaseServerClient();
  const hospital_org_id = String(fd.get('hospital_org_id') ?? '');
  const action_type = String(fd.get('action_type') ?? '');
  const note = String(fd.get('note') ?? '');
  await sb.rpc('log_founder_hospital_sq_review_action', {
    p_hospital_org_id: hospital_org_id,
    p_action_type: action_type,
    p_note: note,
  });
  revalidatePath('/founder-hospital-service-quality-benchmark');
}
