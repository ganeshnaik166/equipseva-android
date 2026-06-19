import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Spot audit rotation summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  engineers_tracked: number;
  engineers_with_any_invite: number;
  engineers_frozen: number;
  engineers_at_risk_2_ignored: number;
  pending_invitations_now: number;
  invitations_created_today: number;
  response_rate_pct: number;
  avg_responses_per_engineer: number;
  rotation_freezes_30d: number;
  rotation_unfreezes_30d: number;
  oldest_unresponded_invite_age_days: number;
};

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function SpotAuditRotationSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_spot_audit_rotation_summary");
  if (error) throw new Error(`founder_spot_audit_rotation_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Spot audit rotation summary ★ r1310</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">v0.5 Phase 8 · auto-invite every 10th completed job · freeze engineers with ≥3 ignored in 90d</p>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Engineers tracked" val={formatNumber(r.engineers_tracked)} />
          <Card title="With any invite" val={formatNumber(r.engineers_with_any_invite)} />
          <Card title="Frozen now" val={formatNumber(r.engineers_frozen)} danger={r.engineers_frozen > 0} sub="≥3 ignored in 90d" />
          <Card title="At risk (2 ignored)" val={formatNumber(r.engineers_at_risk_2_ignored)} danger={r.engineers_at_risk_2_ignored > 0} sub="one more ignore = freeze" />
          <Card title="Pending invites" val={formatNumber(r.pending_invitations_now)} />
          <Card title="Invites created today" val={formatNumber(r.invitations_created_today)} />
          <Card title="Response rate" val={`${Number(r.response_rate_pct).toFixed(1)}%`} ok={r.response_rate_pct >= 60} />
          <Card title="Avg responses/engineer" val={Number(r.avg_responses_per_engineer).toFixed(2)} />
          <Card title="Freezes 30d" val={formatNumber(r.rotation_freezes_30d)} danger={r.rotation_freezes_30d > 0} />
          <Card title="Unfreezes 30d" val={formatNumber(r.rotation_unfreezes_30d)} ok={r.rotation_unfreezes_30d > 0} />
          <Card title="Oldest unresponded (days)" val={formatNumber(r.oldest_unresponded_invite_age_days)} danger={r.oldest_unresponded_invite_age_days > 5} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
      <p className="text-xs text-[var(--color-muted)]">Cron: <code>spot_audit_auto_invite()</code> runs hourly. Creates invitations on every 10th completed job, refreshes compliance tallies, and freezes/unfreezes engineer rotation based on 90d ignored count.</p>
    </div>
  );
}
