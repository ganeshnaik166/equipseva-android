import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return v.toLocaleString('en-IN');
}

function fmtRupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  if (v >= 10000000) return `Rs ${(v / 10000000).toFixed(2)} Cr`;
  if (v >= 100000) return `Rs ${(v / 100000).toFixed(2)} L`;
  return `Rs ${v.toLocaleString('en-IN')}`;
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  const d = new Date(s);
  if (isNaN(d.getTime())) return '—';
  return d.toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [kpisRes, queueRes, upcomingRes, threatRes, pipelineRes, outcomesRes] = await Promise.all([
    sb.rpc('founder_hpbi_kpis'),
    sb.rpc('founder_hpbi_review_queue'),
    sb.rpc('founder_hpbi_upcoming_due'),
    sb.rpc('founder_hpbi_competitor_threat'),
    sb.rpc('founder_hpbi_pipeline_by_status'),
    sb.rpc('founder_hpbi_recent_outcomes'),
  ]);

  const k: any = kpisRes.data ?? {};
  const queue: any[] = (queueRes.data as any[]) ?? [];
  const upcoming: any[] = (upcomingRes.data as any[]) ?? [];
  const threat: any[] = (threatRes.data as any[]) ?? [];
  const pipeline: any[] = (pipelineRes.data as any[]) ?? [];
  const outcomes: any[] = (outcomesRes.data as any[]) ?? [];

  const kpis: Kpi[] = [
    { label: 'Total tenders tracked', value: fmtInt(k.total_tenders) },
    { label: 'Active in pipeline', value: fmtInt(k.active_tenders) },
    { label: 'Needs founder review', value: fmtInt(k.needs_review) },
    { label: 'Submitted (open)', value: fmtInt(k.submitted_count) },
    { label: 'Won (lifetime)', value: fmtInt(k.won_count) },
    { label: 'Lost (lifetime)', value: fmtInt(k.lost_count) },
    { label: 'Abandoned', value: fmtInt(k.abandoned_count) },
    { label: 'Due within 7 days', value: fmtInt(k.due_in_7d) },
    { label: 'Overdue, unsubmitted', value: fmtInt(k.overdue_unsubmitted) },
    { label: 'Critical priority', value: fmtInt(k.critical_priority) },
    { label: 'High priority', value: fmtInt(k.high_priority) },
    { label: 'Pipeline value', value: fmtRupees(k.pipeline_value_rupees) },
    { label: 'Submitted bid value', value: fmtRupees(k.submitted_bid_value_rupees) },
    { label: 'Won value (lifetime)', value: fmtRupees(k.won_value_rupees) },
    { label: 'Avg win probability', value: `${fmtInt(k.avg_win_probability)}%` },
    { label: 'Avg expected winning price', value: fmtRupees(k.avg_expected_winning_price_rupees) },
  ];

  const queueCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'tender_title', header: 'Tender', render: (r: any) => r.tender_title ?? '—' },
    { key: 'priority', header: 'Priority', render: (r: any) => (r.priority ?? '—').toString().toUpperCase() },
    { key: 'our_submission_status', header: 'Status', render: (r: any) => r.our_submission_status ?? '—' },
    { key: 'due_at', header: 'Due', render: (r: any) => fmtDate(r.due_at) },
    { key: 'estimated_value_rupees', header: 'Est. value', render: (r: any) => fmtRupees(r.estimated_value_rupees) },
    { key: 'win_probability_pct', header: 'Win %', render: (r: any) => `${fmtInt(r.win_probability_pct)}%` },
    { key: 'city', header: 'City', render: (r: any) => r.city ?? '—' },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'tender_title', header: 'Tender', render: (r: any) => r.tender_title ?? '—' },
    { key: 'due_at', header: 'Due', render: (r: any) => fmtDate(r.due_at) },
    { key: 'days_to_due', header: 'Days left', render: (r: any) => fmtInt(r.days_to_due) },
    { key: 'our_submission_status', header: 'Status', render: (r: any) => r.our_submission_status ?? '—' },
    { key: 'estimated_value_rupees', header: 'Est. value', render: (r: any) => fmtRupees(r.estimated_value_rupees) },
    { key: 'our_bid_rupees', header: 'Our bid', render: (r: any) => fmtRupees(r.our_bid_rupees) },
    { key: 'priority', header: 'Priority', render: (r: any) => (r.priority ?? '—').toString().toUpperCase() },
  ];

  const threatCols: Column<any>[] = [
    { key: 'competitor_name', header: 'Competitor', render: (r: any) => r.competitor_name ?? '—' },
    { key: 'competitor_tier', header: 'Tier', render: (r: any) => r.competitor_tier ?? '—' },
    { key: 'appearances', header: 'Tenders seen', render: (r: any) => fmtInt(r.appearances) },
    { key: 'high_threat_count', header: 'High threat', render: (r: any) => fmtInt(r.high_threat_count) },
    { key: 'avg_expected_bid_rupees', header: 'Avg expected bid', render: (r: any) => fmtRupees(r.avg_expected_bid_rupees) },
    { key: 'wins_vs_us', header: 'Wins vs us', render: (r: any) => fmtInt(r.wins_vs_us) },
    { key: 'losses_vs_us', header: 'Losses vs us', render: (r: any) => fmtInt(r.losses_vs_us) },
  ];

  const pipelineCols: Column<any>[] = [
    { key: 'our_submission_status', header: 'Status', render: (r: any) => r.our_submission_status ?? '—' },
    { key: 'tender_count', header: 'Tenders', render: (r: any) => fmtInt(r.tender_count) },
    { key: 'total_estimated_rupees', header: 'Total est.', render: (r: any) => fmtRupees(r.total_estimated_rupees) },
    { key: 'total_our_bid_rupees', header: 'Total our bid', render: (r: any) => fmtRupees(r.total_our_bid_rupees) },
    { key: 'avg_win_probability', header: 'Avg win %', render: (r: any) => `${fmtInt(r.avg_win_probability)}%` },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'tender_title', header: 'Tender', render: (r: any) => r.tender_title ?? '—' },
    { key: 'our_submission_status', header: 'Outcome', render: (r: any) => r.our_submission_status ?? '—' },
    { key: 'our_bid_rupees', header: 'Our bid', render: (r: any) => fmtRupees(r.our_bid_rupees) },
    { key: 'expected_winning_price_rupees', header: 'Expected winning', render: (r: any) => fmtRupees(r.expected_winning_price_rupees) },
    { key: 'due_at', header: 'Due', render: (r: any) => fmtDate(r.due_at) },
    { key: 'reviewed_at', header: 'Reviewed', render: (r: any) => fmtDate(r.reviewed_at) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Hospital Procurement Bid Intel</h1>
        <p className="text-sm text-gray-500">
          Tender pipeline, competitor threat map, founder review queue. Round r1485.
        </p>
      </header>

      <section>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          {kpis.map((kpi) => (
            <div key={kpi.label} className="rounded-xl border border-gray-200 bg-white p-4 shadow-sm">
              <div className="text-xs uppercase tracking-wide text-gray-500">{kpi.label}</div>
              <div className="mt-1 text-xl font-semibold text-gray-900">{kpi.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Founder review queue</h2>
        <p className="text-sm text-gray-500">Tenders flagged for founder triage, sorted by priority then due date.</p>
        <DataTable rowKey={(r: any) => r.id} columns={queueCols} rows={queue} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Upcoming due dates</h2>
        <p className="text-sm text-gray-500">Open tenders with due dates approaching.</p>
        <DataTable rowKey={(r: any) => r.id} columns={upcomingCols} rows={upcoming} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Competitor threat map</h2>
        <p className="text-sm text-gray-500">Who keeps showing up against us, expected bids, and head-to-head record.</p>
        <DataTable rowKey={(r: any) => r.competitor_name} columns={threatCols} rows={threat} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Pipeline by status</h2>
        <DataTable rowKey={(r: any) => r.our_submission_status} columns={pipelineCols} rows={pipeline} />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-semibold">Recent outcomes</h2>
        <p className="text-sm text-gray-500">Closed tenders — won, lost, abandoned, withdrawn, disqualified.</p>
        <DataTable rowKey={(r: any) => r.id} columns={outcomeCols} rows={outcomes} />
      </section>
    </div>
  );
}
