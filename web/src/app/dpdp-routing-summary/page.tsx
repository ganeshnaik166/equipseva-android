import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "DPDP grievance routing summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_routed: number;
  routed_today: number;
  approaching_sla: number;
  escalated_count: number;
  escalated_today: number;
  by_type_correction: number;
  by_type_erasure: number;
  by_type_portability: number;
  by_type_consent_withdrawal: number;
  by_type_other: number;
  median_age_days: number;
  oldest_unresolved_age_days: number;
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

export default async function DpdpRoutingSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_dpdp_routing_summary");
  if (error) throw new Error(`founder_dpdp_routing_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">DPDP grievance routing summary ★ r1309</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">v0.5 Phase 7 · auto-routes new grievances to officer + auto-escalates approaching 30-day SLA</p>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total routed" val={formatNumber(r.total_routed)} />
          <Card title="Routed today" val={formatNumber(r.routed_today)} />
          <Card title="Approaching SLA (≤5d)" val={formatNumber(r.approaching_sla)} danger={r.approaching_sla > 0} />
          <Card title="Escalated (lifetime)" val={formatNumber(r.escalated_count)} danger={r.escalated_count > 0} sub={`${formatNumber(r.escalated_today)} today`} />
          <Card title="Type: correction" val={formatNumber(r.by_type_correction)} />
          <Card title="Type: erasure" val={formatNumber(r.by_type_erasure)} />
          <Card title="Type: portability" val={formatNumber(r.by_type_portability)} />
          <Card title="Type: consent withdrawal" val={formatNumber(r.by_type_consent_withdrawal)} />
          <Card title="Type: other" val={formatNumber(r.by_type_other)} />
          <Card title="Median age (days)" val={Number(r.median_age_days).toFixed(1)} />
          <Card title="Oldest unresolved (days)" val={formatNumber(r.oldest_unresolved_age_days)} danger={r.oldest_unresolved_age_days > 25} />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
      <p className="text-xs text-[var(--color-muted)]">Cron: <code>dpdp_route_and_escalate()</code> runs every hour. Routes new grievances to the assigned officer in <code>dpdp_grievance_officers</code> (founder owns all 5 types by default) and escalates any approaching the 30-day SLA breach to <code>escalated=true</code>.</p>
    </div>
  );
}
