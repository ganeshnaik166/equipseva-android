'use server';
import { revalidatePath } from 'next/cache';
import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';

const PATH = '/founder-marketing-utm-campaign-tracker';

export async function createCampaign(formData: FormData) {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc('log_founder_utm_campaign_create', {
    p_name: String(formData.get('name') || '').trim(),
    p_channel: String(formData.get('channel') || 'other'),
    p_utm_source: String(formData.get('utm_source') || '').trim(),
    p_utm_medium: String(formData.get('utm_medium') || '').trim(),
    p_utm_campaign: String(formData.get('utm_campaign') || '').trim(),
    p_utm_term: (formData.get('utm_term') as string) || null,
    p_utm_content: (formData.get('utm_content') as string) || null,
    p_spend_rupees: Number(formData.get('spend_rupees') || 0),
    p_notes: (formData.get('notes') as string) || null,
  });
  if (error) throw new Error(error.message);
  revalidatePath(PATH);
}

export async function updateSpend(formData: FormData) {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc('log_founder_utm_campaign_update_spend', {
    p_id: String(formData.get('id') || ''),
    p_spend_rupees: Number(formData.get('spend_rupees') || 0),
  });
  if (error) throw new Error(error.message);
  revalidatePath(PATH);
}

export async function setStatus(formData: FormData) {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc('log_founder_utm_campaign_set_status', {
    p_id: String(formData.get('id') || ''),
    p_status: String(formData.get('status') || 'active'),
  });
  if (error) throw new Error(error.message);
  revalidatePath(PATH);
}

export async function logTouch(formData: FormData) {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc('log_founder_utm_touch', {
    p_campaign_id: String(formData.get('campaign_id') || ''),
    p_touch_kind: String(formData.get('touch_kind') || 'lead'),
    p_lead_email: (formData.get('lead_email') as string) || null,
    p_lead_phone: (formData.get('lead_phone') as string) || null,
    p_revenue_rupees: Number(formData.get('revenue_rupees') || 0),
  });
  if (error) throw new Error(error.message);
  revalidatePath(PATH);
}
