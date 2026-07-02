import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(v: any, digits = 0): string {
  if (v === null || v === undefined) return '-';
  const n = typeof v === 'number' ? v : Number(v);
  if (!Number.isFinite(n)) return '-';
  return n.toLocaleString('en-IN', { maximumFractionDigits: digits, minimumFractionDigits: digits });
}

function fmtDate(v: any): string {
  if (!v) return '-';
  try { return new Date(v).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }); } catch { return String(v); }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [summaryRes, atRiskRes, championsRes, bandRes, interventionsRes, trendRes, efficacyRes] = await Promise.all([
    sb.rpc('founder_cs_health_summary'),
    sb.rpc('founder_cs_health_at_risk', { p_limit: 50 }),
    sb.rpc('founder_cs_health_champions', { p_limit: 50 }),
    sb.rpc('founder_cs_health_band_breakdown'),
    sb.rpc('founder_cs_health_recent_interventions', { p_limit: 50 }),
    sb.rpc('founder_cs_health_score_trend', { p_days: 30 }),
    sb.rpc('founder_cs_health_intervention_efficacy'),
  ]);

  const summary = (summaryRes.data ?? [])[0] ?? {};
  const atRisk = (atRiskRes.data ?? []) as any[];
  const champions = (championsRes.data ?? []) as any[];
  const bands = (bandRes.data ?? []) as any[];
  const interventions = (interventionsRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const efficacy = (efficacyRes.data ?? []) as any[];

  const kpis: Kpi[] = [
    { label: 'Total accounts', value: fmtNum(summary.total_accounts) },
    { label: 'At-risk', value: fmtNum(summary.at_risk_count) },
    { label: 'Watch', value: fmtNum(summary.watch_count) },
    { label: 'Steady', value: fmtNum(summary.steady_count) },
    { label: 'Champions', value: fmtNum(summary.champion_count) },
    { label: 'Avg score', value: fmtNum(summary.avg_score, 1) },
    { label: 'Median score', value: fmtNum(summary.median_score, 1) },
    { label: 'Open interventions', value: fmtNum(summary.open_interventions) },
    { label: 'Recovered (lifetime)', value: fmtNum(summary.closed_recovered) },
    { label: 'Churned (lifetime)', value: fmtNum(summary.closed_churned) },
    { label: 'Bands tracked', value: fmtNum(bands.length) },
    { label: 'At-risk listed', value: fmtNum(atRisk.length) },
    { label: 'Champions listed', value: fmtNum(champions.length) },
    { label: 'Recent interventions', value: fmtNum(interventions.length) },
    { label: 'Trend days', value: fmtNum(trend.length) },
    { label: 'Intervention types', value: fmtNum(efficacy.length) },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'org_name', header: 'Account', render: (r: any) => r.org_name ?? '-' },
    { key: 'composite_score', header: 'Score', render: (r: any) => fmtNum(r.composite_score, 1) },
    { key: 'band', header: 'Band', render: (r: any) => r.band ?? '-' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
    { key: 'rationale', header: 'Rationale', render: (r: any) => r.rationale ?? '-' },
  ];

  const championCols: Column<any>[] = [
    { key: 'org_name', header: 'Account', render: (r: any) => r.org_name ?? '-' },
    { key: 'composite_score', header: 'Score', render: (r: any) => fmtNum(r.composite_score, 1) },
    { key: 'nps_score', header: 'NPS', render: (r: any) => fmtNum(r.nps_score, 1) },
    { key: 'captured_at', header: 'Captured', render: (r: any) => fmtDate(r.captured_at) },
  ];

  const bandCols: Column<any>[] = [
    { key: 'band', header: 'Band', render: (r: any) => r.band ?? '-' },
    { key: 'account_count', header: 'Accounts', render: (r: any) => fmtNum(r.account_count) },
    { key: 'avg_score', header: 'Avg', render: (r: any) => fmtNum(r.avg_score, 1) },
    { key: 'min_score', header: 'Min', render: (r: any) => fmtNum(r.min_score, 1) },
    { key: 'max_score', header: 'Max', render: (r: any) => fmtNum(r.max_score, 1) },
  ];

  const interventionCols: Column<any>[] = [
    { key: 'org_name', header: 'Account', render: (r: any) => r.org_name ?? '-' },
    { key: 'intervention_type', header: 'Type', render: (r: any) => r.intervention_type ?? '-' },
    { key: 'opened_at', header: 'Opened', render: (r: any) => fmtDate(r.opened_at) },
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmtDate(r.closed_at) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '-' },
  ];

  const efficacyCols: Column<any>[] = [
    { key: 'intervention_type', header: 'Type', render: (r: any) => r.intervention_type ?? '-' },
    { key: 'total_opened', header: 'Opened', render: (r: any) => fmtNum(r.total_opened) },
    { key: 'recovered', header: 'Recovered', render: (r: any) => fmtNum(r.recovered) },
    { key: 'churned', header: 'Churned', render: (r: any) => fmtNum(r.churned) },
    { key: 'recovery_rate_pct', header: 'Recovery %', render: (r: any) => fmtNum(r.recovery_rate_pct, 1) },
  ];

  return (
    <div className="mx-auto max-w-7xl px-4 py-8 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold tracking-tight">Customer-success health-score ladder</h1>
        <p className="text-sm text-gray-600">NPS + AMC cadence + ticket volume + escalations rolled into a 1-100 score. r1483.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
            <div className="text-xs uppercase tracking-wide text-gray-500">{k.label}</div>
            <div className="mt-1 text-xl font-semibold text-gray-900">{k.value}</div>
          </div>
        ))}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">At-risk accounts (lowest scores first)</h2>
        <DataTable<any> columns={atRiskCols} rows={atRisk} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Champion candidates</h2>
        <DataTable<any> columns={championCols} rows={champions} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Band breakdown</h2>
        <DataTable<any> columns={bandCols} rows={bands} rowKey={(r: any) => r.band} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent interventions</h2>
        <DataTable<any> columns={interventionCols} rows={interventions} rowKey={(r: any) => r.id} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Intervention efficacy</h2>
        <DataTable<any> columns={efficacyCols} rows={efficacy} rowKey={(r: any) => r.intervention_type} />
      </section>
    </div>
  );
}
