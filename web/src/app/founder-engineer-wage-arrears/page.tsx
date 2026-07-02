import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

export const dynamic = 'force-dynamic';

export default async function FounderEngineerWageArrearsPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = {};
  let openAlerts: any[] = [];
  let breaches: any[] = [];
  let clearances: any[] = [];

  try {
    const { data } = await sb.rpc('founder_engineer_wage_arrears_overview');
    overview = (data && data[0]) || {};
  } catch {}

  try {
    const { data } = await sb.rpc('founder_engineer_wage_arrears_open_alerts');
    openAlerts = data || [];
  } catch {}

  try {
    const { data } = await sb.rpc('founder_engineer_wage_arrears_breaches');
    breaches = data || [];
  } catch {}

  try {
    const { data } = await sb.rpc('founder_engineer_wage_arrears_recent_clearances');
    clearances = data || [];
  } catch {}

  const inr = (n: any) => `₹${Number(n || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;

  const openCount = Number(overview.open_alerts || 0);
  const clearedCount = Number(overview.cleared_alerts || 0);
  const escalatedCount = Number(overview.escalated_alerts || 0);
  const totalBacklog = Number(overview.total_backlog_rupees || 0);
  const avgAge = Number(overview.avg_age_days || 0);
  const maxAge = Number(overview.max_age_days || 0);
  const breachCount = Number(overview.sla_breached || 0);
  const cleared7d = Number(overview.cleared_last_7d || 0);
  const avgBacklog = openCount > 0 ? totalBacklog / openCount : 0;
  const breachRate = openCount > 0 ? (breachCount / openCount) * 100 : 0;
  const clearRate = openCount + clearedCount > 0 ? (clearedCount / (openCount + clearedCount)) * 100 : 0;
  const escalationRate = openCount + escalatedCount > 0 ? (escalatedCount / (openCount + escalatedCount)) * 100 : 0;
  const oldestBreach = breaches[0] ? Number(breaches[0].hours_past_sla || 0) : 0;
  const topBacklogEng = openAlerts[0] ? String(openAlerts[0].engineer_name || "—") : "—";
  const topBacklogAmt = openAlerts[0] ? Number(openAlerts[0].backlog_amount_rupees || 0) : 0;
  const lastClearance = clearances[0] ? new Date(clearances[0].created_at).toLocaleDateString() : "—";

  const kpis: Kpi[] = [
    { label: 'Open Alerts', value: String(openCount) },
    { label: 'Total Backlog', value: inr(totalBacklog) },
    { label: 'Avg Backlog / Engineer', value: inr(avgBacklog) },
    { label: 'Avg Age (days)', value: avgAge.toFixed(1) },
    { label: 'Max Age (days)', value: String(maxAge) },
    { label: 'SLA Breached', value: String(breachCount) },
    { label: 'Breach Rate', value: `${breachRate.toFixed(1)}%` },
    { label: 'Oldest Breach (hrs)', value: oldestBreach.toFixed(1) },
    { label: 'Cleared (Total)', value: String(clearedCount) },
    { label: 'Cleared Last 7d', value: String(cleared7d) },
    { label: 'Clear Rate', value: `${clearRate.toFixed(1)}%` },
    { label: 'Escalated', value: String(escalatedCount) },
    { label: 'Escalation Rate', value: `${escalationRate.toFixed(1)}%` },
    { label: 'Top Engineer', value: topBacklogEng },
    { label: 'Top Backlog Amt', value: inr(topBacklogAmt) },
    { label: 'Last Clearance', value: lastClearance },
  ];

  const openCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'engineer_phone', header: 'Phone', render: (r: any) => r.engineer_phone ?? "—" },
    { key: 'backlog_amount_rupees', header: 'Backlog', render: (r: any) => inr(r.backlog_amount_rupees) },
    { key: 'payout_count', header: 'Payouts', render: (r: any) => String(r.payout_count ?? 0) },
    { key: 'oldest_age_days', header: 'Age (days)', render: (r: any) => String(r.oldest_age_days ?? 0) },
    { key: 'sla_breached', header: 'SLA', render: (r: any) => (r.sla_breached ? 'BREACHED' : 'ON-TRACK') },
    { key: 'hours_until_sla', header: 'Hrs to SLA', render: (r: any) => Number(r.hours_until_sla ?? 0).toFixed(1) },
  ];

  const breachCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'backlog_amount_rupees', header: 'Backlog', render: (r: any) => inr(r.backlog_amount_rupees) },
    { key: 'oldest_age_days', header: 'Age (days)', render: (r: any) => String(r.oldest_age_days ?? 0) },
    { key: 'hours_past_sla', header: 'Hrs Past SLA', render: (r: any) => Number(r.hours_past_sla ?? 0).toFixed(1) },
    { key: 'sla_due_at', header: 'SLA Due', render: (r: any) => new Date(r.sla_due_at).toLocaleString() },
  ];

  const clearanceCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? "—" },
    { key: 'action', header: 'Action', render: (r: any) => r.action ?? "—" },
    { key: 'amount_at_action_rupees', header: 'Amount', render: (r: any) => inr(r.amount_at_action_rupees) },
    { key: 'age_days_at_action', header: 'Age (days)', render: (r: any) => String(r.age_days_at_action ?? 0) },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? "—" },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? "—" },
    { key: 'created_at', header: 'When', render: (r: any) => new Date(r.created_at).toLocaleString() },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Engineer Wage Arrears Alert</h1>
        <p className="text-sm text-gray-600">Detect engineers with payout backlog over 30 days. Founder clears within 48h SLA.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border bg-white p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </div>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Open Alerts</h2>
        <DataTable rowKey={(r: any) => r.id} columns={openCols} rows={openAlerts} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">SLA Breaches</h2>
        <DataTable rowKey={(r: any) => r.id} columns={breachCols} rows={breaches} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Clearance Log</h2>
        <DataTable rowKey={(r: any) => r.id} columns={clearanceCols} rows={clearances} />
      </section>
    </div>
  );
}
