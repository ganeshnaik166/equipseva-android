import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column  } from "@/components/DataTable";

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function num(n: number | null | undefined): string {
  return Number(n ?? 0).toLocaleString('en-IN');
}

function pct(n: number | null | undefined): string {
  const v = Number(n ?? 0) * 100;
  return v.toFixed(1) + '%';
}

function days(n: number | null | undefined): string {
  return Number(n ?? 0).toFixed(1) + 'd';
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let recent: any[] = [];
  let pending: any[] = [];
  let byReason: any[] = [];
  let trend: any[] = [];
  let topHospitals: any[] = [];
  let funnel: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_tier_downgrade_kpis');
    kpis = (r.data && r.data[0]) || {};
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_tier_downgrade_recent', { p_limit: 50 });
    recent = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_tier_downgrade_pending');
    pending = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_tier_downgrade_by_reason');
    byReason = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_tier_downgrade_trend_weekly');
    trend = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_tier_downgrade_top_hospitals');
    topHospitals = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('rpc_founder_tier_downgrade_approval_funnel');
    funnel = r.data || [];
  } catch {}
  try {
    await sb.rpc('log_founder_tier_downgrade_view', { p_section: 'index' });
  } catch {}

  const cards: Kpi[] = [
    { label: 'Total events', value: num(kpis.total_events) },
    { label: 'Events 30d', value: num(kpis.events_30d) },
    { label: 'Events 7d', value: num(kpis.events_7d) },
    { label: 'Pending', value: num(kpis.events_pending) },
    { label: 'Approved', value: num(kpis.events_approved) },
    { label: 'Rejected', value: num(kpis.events_rejected) },
    { label: 'AMC lost 30d', value: rupees(kpis.amc_value_lost_30d) },
    { label: 'AMC lost total', value: rupees(kpis.amc_value_lost_total) },
    { label: 'MRR delta 30d', value: rupees(kpis.mrr_delta_30d) },
    { label: 'Unique hospitals 30d', value: num(kpis.unique_hospitals_30d) },
    { label: 'Non-payment 30d', value: num(kpis.reason_non_payment_30d) },
    { label: 'SLA breach 30d', value: num(kpis.reason_sla_breach_30d) },
    { label: 'Low volume 30d', value: num(kpis.reason_low_volume_30d) },
    { label: 'Complaints 30d', value: num(kpis.reason_complaints_30d) },
    { label: 'Avg days to approve', value: days(kpis.avg_days_to_approval) },
    { label: 'Churn rate 30d', value: pct(kpis.churn_rate_30d) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'from_tier', header: 'From', render: (r: any) => r.from_tier ?? '—' },
    { key: 'to_tier', header: 'To', render: (r: any) => r.to_tier ?? '—' },
    { key: 'reason_code', header: 'Reason', render: (r: any) => r.reason_code ?? '—' },
    { key: 'amc_value_lost_rupees', header: 'AMC lost', render: (r: any) => rupees(r.amc_value_lost_rupees) },
    { key: 'founder_approval_status', header: 'Status', render: (r: any) => r.founder_approval_status ?? '—' },
    { key: 'created_at', header: 'Created', render: (r: any) => (r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '—') },
  ];

  const pendingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'from_tier', header: 'From', render: (r: any) => r.from_tier ?? '—' },
    { key: 'to_tier', header: 'To', render: (r: any) => r.to_tier ?? '—' },
    { key: 'reason_code', header: 'Reason', render: (r: any) => r.reason_code ?? '—' },
    { key: 'reason_note', header: 'Note', render: (r: any) => r.reason_note ?? '—' },
    { key: 'amc_value_lost_rupees', header: 'AMC lost', render: (r: any) => rupees(r.amc_value_lost_rupees) },
    { key: 'age_days', header: 'Age', render: (r: any) => days(r.age_days) },
  ];

  const reasonCols: Column<any>[] = [
    { key: 'display_label', header: 'Reason', render: (r: any) => r.display_label ?? '—' },
    { key: 'events_30d', header: 'Events 30d', render: (r: any) => num(r.events_30d) },
    { key: 'events_90d', header: 'Events 90d', render: (r: any) => num(r.events_90d) },
    { key: 'amc_value_lost_30d', header: 'AMC lost 30d', render: (r: any) => rupees(r.amc_value_lost_30d) },
    { key: 'severity_weight', header: 'Severity', render: (r: any) => num(r.severity_weight) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => (r.week_start ? new Date(r.week_start).toLocaleDateString('en-IN') : '—') },
    { key: 'event_count', header: 'Events', render: (r: any) => num(r.event_count) },
    { key: 'unique_hospitals', header: 'Hospitals', render: (r: any) => num(r.unique_hospitals) },
    { key: 'amc_value_lost_rupees', header: 'AMC lost', render: (r: any) => rupees(r.amc_value_lost_rupees) },
    { key: 'churned_count', header: 'Churned', render: (r: any) => num(r.churned_count) },
  ];

  const topCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'downgrade_events', header: 'Events', render: (r: any) => num(r.downgrade_events) },
    { key: 'total_amc_lost_rupees', header: 'AMC lost', render: (r: any) => rupees(r.total_amc_lost_rupees) },
    { key: 'last_event_at', header: 'Last event', render: (r: any) => (r.last_event_at ? new Date(r.last_event_at).toLocaleString('en-IN') : '—') },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">Hospital tier downgrade ledger</h1>
        <p className="text-sm text-neutral-600">r1530 — every downgrade event, reason, approval & trend.</p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4 mb-8">
        {cards.map((k) => (
          <div key={k.label} className="rounded-lg border border-neutral-200 p-4">
            <div className="text-xs uppercase tracking-wide text-neutral-500">{k.label}</div>
            <div className="mt-1 text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-2">Recent downgrade events</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-2">Pending founder approval</h2>
        <DataTable rows={pending} columns={pendingCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-2">By reason</h2>
        <DataTable rows={byReason} columns={reasonCols} rowKey={(r: any) => r.reason_code} />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-2">Weekly trend (12 weeks)</h2>
        <DataTable rows={trend} columns={trendCols} rowKey={(r: any) => String(r.week_start)} />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-2">Top downgrading hospitals</h2>
        <DataTable rows={topHospitals} columns={topCols} rowKey={(r: any) => r.hospital_org_id} />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-2">Approval funnel</h2>
        <ul className="text-sm">
          {funnel.map((f: any) => (
            <li key={f.status} className="flex justify-between border-b py-1">
              <span>{f.status}</span>
              <span>{num(f.event_count)} events · {rupees(f.amc_value_rupees)} · avg {days(f.avg_age_days)}</span>
            </li>
          ))}
        </ul>
      </section>
    </main>
  );
}
