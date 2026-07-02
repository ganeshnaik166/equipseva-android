import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: any): string {
  const v = Number(n);
  if (!Number.isFinite(v)) return '0';
  return v.toLocaleString('en-IN');
}

function fmtRupees(n: any): string {
  const v = Number(n);
  if (!Number.isFinite(v)) return '₹0';
  return '₹' + v.toLocaleString('en-IN');
}

function fmtPct(n: any): string {
  const v = Number(n);
  if (!Number.isFinite(v)) return '0%';
  return v.toFixed(1) + '%';
}

function fmtDate(s: any): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return String(s); }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let atRisk: any[] = [];
  let recentCalls: any[] = [];
  let pendingFollowups: any[] = [];
  let bandDist: any[] = [];

  try {
    const r = await sb.rpc('founder_eng6mo_kpis');
    kpis = (r.data as any) ?? {};
  } catch (_e) { kpis = {}; }

  try {
    const r = await sb.rpc('founder_eng6mo_at_risk_engineers');
    atRisk = (r.data as any[]) ?? [];
  } catch (_e) { atRisk = []; }

  try {
    const r = await sb.rpc('founder_eng6mo_recent_calls');
    recentCalls = (r.data as any[]) ?? [];
  } catch (_e) { recentCalls = []; }

  try {
    const r = await sb.rpc('founder_eng6mo_pending_followups');
    pendingFollowups = (r.data as any[]) ?? [];
  } catch (_e) { pendingFollowups = []; }

  try {
    const r = await sb.rpc('founder_eng6mo_risk_band_distribution');
    bandDist = (r.data as any[]) ?? [];
  } catch (_e) { bandDist = []; }

  try { await sb.rpc('log_founder_eng6mo_view'); } catch (_e) {}

  const kpiCards: Kpi[] = [
    { label: 'Snapshot Date', value: kpis.snapshot_date ? String(kpis.snapshot_date) : '—' },
    { label: 'Tracked Engineers', value: fmtInt(kpis.total_engineers_tracked) },
    { label: 'Approaching 6-mo', value: fmtInt(kpis.approaching_6mo) },
    { label: 'Critical Risk', value: fmtInt(kpis.critical) },
    { label: 'Warn Risk', value: fmtInt(kpis.warn) },
    { label: 'Watch Risk', value: fmtInt(kpis.watch) },
    { label: 'Safe', value: fmtInt(kpis.safe) },
    { label: 'Past 6-mo Mark', value: fmtInt(kpis.past_6mo) },
    { label: 'Avg Risk Score', value: String(kpis.avg_risk_score ?? 0) },
    { label: 'Calls (30d)', value: fmtInt(kpis.calls_30d) },
    { label: 'Saved (30d)', value: fmtInt(kpis.saved_30d) },
    { label: 'Will Churn (30d)', value: fmtInt(kpis.will_churn_30d) },
    { label: 'No Answer (30d)', value: fmtInt(kpis.no_answer_30d) },
    { label: 'Pending Followups (7d)', value: fmtInt(kpis.pending_followups_7d) },
    { label: 'Save Rate', value: fmtPct(kpis.save_rate_pct) },
    { label: 'Churn Rate', value: fmtPct(kpis.churn_rate_pct) },
  ];

  const atRiskCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'engineer_phone', header: 'Phone', render: (r: any) => r.engineer_phone ?? '—' },
    { key: 'risk_band', header: 'Band', render: (r: any) => r.risk_band ?? '—' },
    { key: 'risk_score', header: 'Score', render: (r: any) => String(r.risk_score ?? 0) },
    { key: 'days_since_onboard', header: 'Days Onboard', render: (r: any) => fmtInt(r.days_since_onboard) },
    { key: 'days_to_6mo_mark', header: 'Days to 6-mo', render: (r: any) => fmtInt(r.days_to_6mo_mark) },
    { key: 'jobs_last_30d', header: 'Jobs (30d)', render: (r: any) => fmtInt(r.jobs_last_30d) },
    { key: 'earnings_last_30d_rupees', header: 'Earn (30d)', render: (r: any) => fmtRupees(r.earnings_last_30d_rupees) },
    { key: 'avg_rating_last_30d', header: 'Rating (30d)', render: (r: any) => r.avg_rating_last_30d ?? '—' },
    { key: 'cached_tier', header: 'Tier', render: (r: any) => r.cached_tier ?? '—' },
    { key: 'last_call_outcome', header: 'Last Call', render: (r: any) => r.last_call_outcome ?? '—' },
  ];

  const callsCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'called_at', header: 'Called At', render: (r: any) => fmtDate(r.called_at) },
    { key: 'duration_minutes', header: 'Mins', render: (r: any) => r.duration_minutes ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
    { key: 'retention_offer', header: 'Offer', render: (r: any) => r.retention_offer ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const followupCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'engineer_phone', header: 'Phone', render: (r: any) => r.engineer_phone ?? '—' },
    { key: 'last_outcome', header: 'Last Outcome', render: (r: any) => r.last_outcome ?? '—' },
    { key: 'followup_due_at', header: 'Due At', render: (r: any) => fmtDate(r.followup_due_at) },
    { key: 'days_until_due', header: 'Days Until', render: (r: any) => r.days_until_due ?? '—' },
  ];

  const bandCols: Column<any>[] = [
    { key: 'risk_band', header: 'Band', render: (r: any) => r.risk_band ?? '—' },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => fmtInt(r.engineer_count) },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => String(r.avg_score ?? 0) },
    { key: 'avg_jobs_30d', header: 'Avg Jobs (30d)', render: (r: any) => String(r.avg_jobs_30d ?? 0) },
    { key: 'avg_earnings_30d_rupees', header: 'Avg Earn (30d)', render: (r: any) => fmtRupees(r.avg_earnings_30d_rupees) },
  ];

  return (
    <main className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer 6-Month Retention Tracker</h1>
        <p className="text-sm text-gray-600">
          At-risk engineers approaching the 6-month mark (industry's highest churn point).
          Founder personal-call list to save churning engineers.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">KPIs</h2>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {kpiCards.map((k, i) => (
            <div key={i} className="border rounded p-3">
              <div className="text-xs text-gray-500">{k.label}</div>
              <div className="text-lg font-semibold">{k.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">At-Risk Engineers (Personal-Call List)</h2>
        <DataTable rows={atRisk} columns={atRiskCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Pending Follow-ups (Next 14 days)</h2>
        <DataTable rows={pendingFollowups} columns={followupCols} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Risk Band Distribution</h2>
        <DataTable rows={bandDist} columns={bandCols} rowKey={(r: any) => r.risk_band} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Calls</h2>
        <DataTable rows={recentCalls} columns={callsCols} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
