"use server";

import { revalidatePath } from "next/cache";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export async function mintInvestorShareToken(input: {
  label: string;
  expiresInDays: number;
  maxViews: number;
}): Promise<
  | { ok: true; tokenId: string; rawToken: string; expiresAt: string; shareUrl: string }
  | { ok: false; error: string }
> {
  await requireFounder();
  if (input.label.trim().length < 3)
    return { ok: false, error: "Label min 3 chars" };
  if (input.expiresInDays < 1 || input.expiresInDays > 90)
    return { ok: false, error: "Expiry must be 1..90 days" };
  if (input.maxViews < 1 || input.maxViews > 1000)
    return { ok: false, error: "Max views must be 1..1000" };

  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_mint_investor_share_token", {
    p_label: input.label.trim(),
    p_expires_in_days: input.expiresInDays,
    p_max_views: input.maxViews,
  });
  if (error || !data) {
    console.error("founder_mint_investor_share_token failed:", error);
    return { ok: false, error: "Could not mint token. Check server logs." };
  }
  const row = Array.isArray(data) ? data[0] : data;
  // Build the share URL using the request's own origin via NEXT_PUBLIC env (best-effort).
  // If NEXT_PUBLIC_BASE_URL isn't set, fall back to a relative URL.
  const base = process.env.NEXT_PUBLIC_BASE_URL ?? "";
  const shareUrl = `${base}/share/investor/${row.raw_token}`;
  revalidatePath("/investor");
  return {
    ok: true,
    tokenId: row.token_id,
    rawToken: row.raw_token,
    expiresAt: row.expires_at,
    shareUrl,
  };
}

export async function revokeInvestorShareToken(
  tokenId: string,
  reason: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  await requireFounder();
  if (reason.trim().length < 5)
    return { ok: false, error: "Reason min 5 chars" };
  const supabase = await getSupabaseServerClient();
  const { error } = await supabase.rpc("founder_revoke_investor_share_token", {
    p_token_id: tokenId,
    p_reason: reason.trim(),
  });
  if (error) {
    console.error("founder_revoke_investor_share_token failed:", error);
    return { ok: false, error: "Could not revoke token. Check server logs." };
  }
  revalidatePath("/investor");
  return { ok: true };
}
