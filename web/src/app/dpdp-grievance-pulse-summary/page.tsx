import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "DPDP grievance pulse summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  grievances_total: number;
  grievances_open: number;
  grievances_in_review: number;
  grievances_resolved: number;
  grievances_escalated: number;
  sla_breached_open: number;
  sla_at_risk_72h: number;
  type_erasure_open: number;
  type_correction_open: number;
  type_breach_notif_open: number;
  avg_resolution_days: number;
  filed_today: number;
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

export default async function DpdpGrievancePulseSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_dpdp_grievance_pulse_summary");
  if (error) throw new Error(`founder_dpdp_grievance_pulse_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">DPDP grievance pulse</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI DPDP §32 compliance snapshot · open + SLA-breach + erasure/correction backlog + 90d avg-resolution</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Grievances total" val={formatNumber(r.grievances_total)} sub="all-time filed" />
          <Card title="Open" val={formatNumber(r.grievances_open)} danger={r.grievances_open > 0} sub="awaiting first review" />
          <Card title="In review" val={formatNumber(r.grievances_in_review)} sub="founder actively handling" />
          <Card title="Resolved" val={formatNumber(r.grievances_resolved)} ok={r.grievances_resolved > 0} sub="lifetime closed" />
          <Card title="Escalated to DPB" val={formatNumber(r.grievances_escalated)} danger={r.grievances_escalated > 0} sub="Data Protection Board" />
          <Card title="SLA breached (open)" val={formatNumber(r.sla_breached_open)} danger={r.sla_breached_open > 0} sub="past deadline — §33 penalty risk" />
          <Card title="SLA at risk ≤72h" val={formatNumber(r.sla_at_risk_72h)} danger={r.sla_at_risk_72h > 0} sub="deadline within 72h" />
          <Card title="Erasure open" val={formatNumber(r.type_erasure_open)} sub="deletion_request backlog" />
          <Card title="Correction open" val={formatNumber(r.type_correction_open)} sub="correction_request backlog" />
          <Card title="Breach-notif open" val={formatNumber(r.type_breach_notif_open)} danger={r.type_breach_notif_open > 0} sub="72h §10 mandatory window" />
          <Card title="Avg resolution days 90d" val={`${Number(r.avg_resolution_days).toFixed(2)}d`} ok={r.avg_resolution_days > 0 && r.avg_resolution_days < 7} danger={r.avg_resolution_days >= 25} sub="must stay well under 30" />
          <Card title="Filed today" val={formatNumber(r.filed_today)} ok={r.filed_today === 0} danger={r.filed_today > 0} sub="new grievances (IST day)" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
