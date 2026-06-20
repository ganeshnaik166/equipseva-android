'use server';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { revalidatePath } from 'next/cache';

export async function logStandupEntry(fd: FormData) {
  const sb = await getSupabaseServerClient();
  const author_role = String(fd.get('author_role') ?? 'founder');
  const shipped_yesterday = String(fd.get('shipped_yesterday') ?? '');
  const intent_today = String(fd.get('intent_today') ?? '');
  const mood = String(fd.get('mood') ?? 'green');
  const hours = fd.get('hours_worked');
  await sb.rpc('log_standup_entry', {
    p_author_role: author_role,
    p_shipped_yesterday: shipped_yesterday,
    p_intent_today: intent_today,
    p_mood: mood,
    p_hours_worked: hours ? Number(hours) : null,
  });
  revalidatePath('/founder-daily-standup-log');
}

export async function logStandupBlocker(fd: FormData) {
  const sb = await getSupabaseServerClient();
  const entry_id = String(fd.get('entry_id') ?? '');
  const severity = String(fd.get('severity') ?? 'p2');
  const category = String(fd.get('category') ?? 'engineering');
  const title = String(fd.get('title') ?? '');
  const detail = String(fd.get('detail') ?? '');
  await sb.rpc('log_standup_blocker', {
    p_entry_id: entry_id,
    p_severity: severity,
    p_category: category,
    p_title: title,
    p_detail: detail,
  });
  revalidatePath('/founder-daily-standup-log');
}

export async function resolveStandupBlocker(fd: FormData) {
  const sb = await getSupabaseServerClient();
  const blocker_id = String(fd.get('blocker_id') ?? '');
  const resolved_note = String(fd.get('resolved_note') ?? '');
  await sb.rpc('resolve_standup_blocker', { p_blocker_id: blocker_id, p_resolved_note: resolved_note });
  revalidatePath('/founder-daily-standup-log');
}

export async function deleteStandupEntry(fd: FormData) {
  const sb = await getSupabaseServerClient();
  const entry_id = String(fd.get('entry_id') ?? '');
  await sb.rpc('delete_standup_entry', { p_entry_id: entry_id });
  revalidatePath('/founder-daily-standup-log');
}
