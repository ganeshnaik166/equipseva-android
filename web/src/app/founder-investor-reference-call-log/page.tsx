import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return "—";
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return s ?? "—";
  }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let overview: any = null;
  let recent: any[] = [];
  let byStage: any[] = [];
  let perInvestor: any[] = [];
  let perReference: any[] = [];
  let pendingFollowup: any[] = [];
  let signalSummary: any[] = [];

  try {
    const r = await sb.rpc('founder_iref_calls_overview');
    overview = (r.data && r.data[0]) ?? null;
  } catch {
    overview = null;
  }
  try {
    const r = await sb.rpc('founder_iref_calls_recent');
    recent = r.data ?? [];
  } catch {
    recent = [];
  }
  try {
    const r = await sb.rpc('founder_iref_calls_by_stage');
    byStage = r.data ?? [];
  } catch {
    byStage = [];
  }
  try {
    const r = await sb.rpc('founder_iref_calls_per_investor');
    perInvestor = r.data ?? [];
  } catch {
    perInvestor = [];
  }
  try {
    const r = await sb.rpc('founder_iref_calls_per_reference');
    perReference = r.data ?? [];
  } catch {
    perReference = [];
  }
  try {
    const r = await sb.rpc('founder_iref_calls_pending_followup');
    pendingFollowup = r.data ?? [];
  } catch {
    pendingFollowup = [];
  }
  try {
    const r = await sb.rpc('founder_iref_signal_summary');
    signalSummary = r.data ?? [];
  } catch {
    signalSummary = [];
  }

  const kpis: Kpi[] = [
    { label: 'Total calls', value: fmtNum(overview?.total_calls) },
    { label: 'Asked', value: fmtNum(overview?.asked_calls) },
    { label: 'Scheduled', value: fmtNum(overview?.scheduled_calls) },
    { label: 'Done', value: fmtNum(overview?.done_calls) },
    { label: 'Distinct investors', value: fmtNum(overview?.distinct_investors) },
    { label: 'Distinct references', value: fmtNum(overview?.distinct_references) },
    { label: 'Positive signals', value: fmtNum(overview?.positive_signals) },
    { label: 'Red flag signals', value: fmtNum(overview?.red_flag_signals) },
    { label: 'Avg days to schedule', value: fmtNum(overview?.avg_days_to_schedule) },
    { label: 'Avg days to complete', value: fmtNum(overview?.avg_days_to_complete) },
    { label: 'Pending followup', value: fmtNum(pendingFollowup.length) },
    { label: 'Recent (50)', value: fmtNum(recent.length) },
    { label: 'Top investors', value: fmtNum(perInvestor.length) },
    { label: 'Top references', value: fmtNum(perReference.length) },
    { label: 'Stage buckets', value: fmtNum(byStage.length) },
    { label: 'Signal buckets', value: fmtNum(signalSummary.length) },
  ];

  const recentColumns: Column<any>[] = [
    { key: 'investor', header: 'Investor', render: (r: any) => r.prospective_investor_name ?? "—" },
    { key: 'firm', header: 'Firm', render: (r: any) => r.prospective_investor_firm ?? "—" },
    { key: 'reference', header: 'Reference', render: (r: any) => r.portfolio_reference_name ?? "—" },
    { key: 'company', header: 'Company', render: (r: any) => r.portfolio_reference_company ?? "—" },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? "—" },
    { key: 'asked_at', header: 'Asked', render: (r: any) => fmtDate(r.asked_at) },
    { key: 'scheduled_for', header: 'Scheduled', render: (r: any) => fmtDate(r.scheduled_for) },
    { key: 'completed_at', header: 'Completed', render: (r: any) => fmtDate(r.completed_at) },
    { key: 'signal', header: 'Signal', render: (r: any) => r.signal_strength ?? "—" },
  ];

  const stageColumns: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? "—" },
    { key: 'call_count', header: 'Calls', render: (r: any) => fmtNum(r.call_count) },
    { key: 'oldest_asked_at', header: 'Oldest asked', render: (r: any) => fmtDate(r.oldest_asked_at) },
    { key: 'newest_asked_at', header: 'Newest asked', render: (r: any) => fmtDate(r.newest_asked_at) },
  ];

  const investorColumns: Column<any>[] = [
    { key: 'investor', header: 'Investor', render: (r: any) => r.prospective_investor_name ?? "—" },
    { key: 'firm', header: 'Firm', render: (r: any) => r.prospective_investor_firm ?? "—" },
    { key: 'calls_asked', header: 'Calls asked', render: (r: any) => fmtNum(r.calls_asked) },
    { key: 'calls_done', header: 'Calls done', render: (r: any) => fmtNum(r.calls_done) },
    { key: 'positive_pct', header: 'Positive %', render: (r: any) => fmtNum(r.positive_signal_pct) },
    { key: 'latest', header: 'Latest', render: (r: any) => fmtDate(r.latest_call_at) },
  ];

  const referenceColumns: Column<any>[] = [
    { key: 'name', header: 'Reference', render: (r: any) => r.portfolio_reference_name ?? "—" },
    { key: 'company', header: 'Company', render: (r: any) => r.portfolio_reference_company ?? "—" },
    { key: 'total', header: 'Calls given', render: (r: any) => fmtNum(r.total_calls_given) },
    { key: 'cap', header: 'Monthly cap', render: (r: any) => fmtNum(r.monthly_cap) },
    { key: 'goodwill', header: 'Goodwill', render: (r: any) => fmtNum(r.goodwill_balance) },
    { key: 'last_call', header: 'Last call', render: (r: any) => fmtDate(r.last_call_at) },
  ];

  const followupColumns: Column<any>[] = [
    { key: 'investor', header: 'Investor', render: (r: any) => r.prospective_investor_name ?? "—" },
    { key: 'reference', header: 'Reference', render: (r: any) => r.portfolio_reference_name ?? "—" },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? "—" },
    { key: 'asked_at', header: 'Asked', render: (r: any) => fmtDate(r.asked_at) },
    { key: 'days_open', header: 'Days open', render: (r: any) => fmtNum(r.days_open) },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Reference Call Log</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>r1556 — log reference calls between prospective investors and portfolio founders; 3-stage workflow (asked / scheduled / done); per-reference calls-given tracking.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent calls</h2>
        <DataTable columns={recentColumns} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By stage</h2>
        <DataTable columns={stageColumns} rows={byStage} rowKey={(r: any) => r.stage} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Per investor</h2>
        <DataTable columns={investorColumns} rows={perInvestor} rowKey={(r: any) => r.prospective_investor_name} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Per reference (calls-given count)</h2>
        <DataTable columns={referenceColumns} rows={perReference} rowKey={(r: any) => r.portfolio_reference_name} />
      </section>

      <section style={{ marginBottom: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Pending followup</h2>
        <DataTable columns={followupColumns} rows={pendingFollowup} rowKey={(r: any) => r.id} />
      </section>
    </div>
  );
}
