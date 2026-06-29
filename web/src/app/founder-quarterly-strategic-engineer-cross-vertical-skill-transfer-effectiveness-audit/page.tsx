import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Transfer = {
  id: string;
  engineer_name: string;
  source_vertical: string;
  target_vertical: string;
  transfer_quarter: string;
  baseline_proficiency_score: number;
  post_transfer_score: number;
  hours_invested: number;
  first_solo_job_at: string | null;
  certified_at: string | null;
  effectiveness_grade: string;
  retention_180d: boolean;
};

type GradeRow = { grade: string; transfers: number; avg_uplift: number; retained: number };
type QuarterRow = { transfer_quarter: string; attempts: number; certified: number; avg_hours: number; a_grade: number };
type PairingRow = { pairing: string; attempts: number; avg_uplift: number; cert_rate_pct: number };
type SummaryRow = {
  id: string;
  quarter_label: string;
  vertical_pair: string;
  transfers_attempted: number;
  transfers_certified: number;
  avg_uplift_points: number;
  avg_hours_to_certify: number;
  roi_label: string;
  notes: string | null;
  reviewed_at: string | null;
};
type RoiRow = { roi_label: string; pairs: number; total_attempts: number; total_certified: number; avg_uplift: number };
type KpiRow = { metric: string; value: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [transfers, grades, quarters, pairings, summaries, roi, kpis] = await Promise.all([
    supabase.rpc('r3025_list_transfers'),
    supabase.rpc('r3025_grade_distribution'),
    supabase.rpc('r3025_quarter_summary'),
    supabase.rpc('r3025_top_pairings'),
    supabase.rpc('r3025_quarterly_summaries'),
    supabase.rpc('r3025_roi_breakdown'),
    supabase.rpc('r3025_kpi_overview'),
  ]);

  const transferCols: Column<Transfer>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'From', accessor: (r) => r.source_vertical },
    { header: 'To', accessor: (r) => r.target_vertical },
    { header: 'Qtr', accessor: (r) => r.transfer_quarter },
    { header: 'Base', accessor: (r) => r.baseline_proficiency_score },
    { header: 'Post', accessor: (r) => r.post_transfer_score },
    { header: 'Hours', accessor: (r) => r.hours_invested },
    { header: 'Grade', accessor: (r) => r.effectiveness_grade },
    { header: 'Retained 180d', accessor: (r) => (r.retention_180d ? 'yes' : 'no') },
    { header: 'Certified At', accessor: (r) => r.certified_at ?? '—' },
  ];

  const gradeCols: Column<GradeRow>[] = [
    { header: 'Grade', accessor: (r) => r.grade },
    { header: 'Transfers', accessor: (r) => r.transfers },
    { header: 'Avg Uplift', accessor: (r) => r.avg_uplift },
    { header: 'Retained', accessor: (r) => r.retained },
  ];

  const quarterCols: Column<QuarterRow>[] = [
    { header: 'Quarter', accessor: (r) => r.transfer_quarter },
    { header: 'Attempts', accessor: (r) => r.attempts },
    { header: 'Certified', accessor: (r) => r.certified },
    { header: 'Avg Hours', accessor: (r) => r.avg_hours },
    { header: 'A-grade', accessor: (r) => r.a_grade },
  ];

  const pairingCols: Column<PairingRow>[] = [
    { header: 'Pairing', accessor: (r) => r.pairing },
    { header: 'Attempts', accessor: (r) => r.attempts },
    { header: 'Avg Uplift', accessor: (r) => r.avg_uplift },
    { header: 'Cert Rate %', accessor: (r) => r.cert_rate_pct },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter_label },
    { header: 'Pair', accessor: (r) => r.vertical_pair },
    { header: 'Attempts', accessor: (r) => r.transfers_attempted },
    { header: 'Certified', accessor: (r) => r.transfers_certified },
    { header: 'Uplift', accessor: (r) => r.avg_uplift_points },
    { header: 'Hrs/Cert', accessor: (r) => r.avg_hours_to_certify },
    { header: 'ROI', accessor: (r) => r.roi_label },
    { header: 'Notes', accessor: (r) => r.notes ?? '—' },
  ];

  const roiCols: Column<RoiRow>[] = [
    { header: 'ROI', accessor: (r) => r.roi_label },
    { header: 'Pairs', accessor: (r) => r.pairs },
    { header: 'Attempts', accessor: (r) => r.total_attempts },
    { header: 'Certified', accessor: (r) => r.total_certified },
    { header: 'Avg Uplift', accessor: (r) => r.avg_uplift },
  ];

  const kpiCols: Column<KpiRow>[] = [
    { header: 'Metric', accessor: (r) => r.metric },
    { header: 'Value', accessor: (r) => r.value },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Strategic Engineer Cross-Vertical Skill Transfer Effectiveness Audit</h1>
        <p className="text-sm text-gray-600">Round r3025 · Batch 430 milestone · founder console</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">KPI Overview</h2>
        <DataTable rows={(kpis.data ?? []) as KpiRow[]} columns={kpiCols} emptyMessage="No KPIs" rowKey={(r, i) => String((r as KpiRow).metric ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Grade Distribution</h2>
        <DataTable rows={(grades.data ?? []) as GradeRow[]} columns={gradeCols} emptyMessage="No grades" rowKey={(r, i) => String((r as GradeRow).grade ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarter Summary</h2>
        <DataTable rows={(quarters.data ?? []) as QuarterRow[]} columns={quarterCols} emptyMessage="No quarters" rowKey={(r, i) => String((r as QuarterRow).transfer_quarter ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Pairings by Uplift</h2>
        <DataTable rows={(pairings.data ?? []) as PairingRow[]} columns={pairingCols} emptyMessage="No pairings" rowKey={(r, i) => String((r as PairingRow).pairing ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">ROI Breakdown</h2>
        <DataTable rows={(roi.data ?? []) as RoiRow[]} columns={roiCols} emptyMessage="No ROI rows" rowKey={(r, i) => String((r as RoiRow).roi_label ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Pair Summaries</h2>
        <DataTable rows={(summaries.data ?? []) as SummaryRow[]} columns={summaryCols} emptyMessage="No summaries" rowKey={(r, i) => String((r as SummaryRow).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Transfers</h2>
        <DataTable rows={(transfers.data ?? []) as Transfer[]} columns={transferCols} emptyMessage="No transfers" rowKey={(r, i) => String((r as Transfer).id ?? i)} />
      </section>
    </main>
  );
}
