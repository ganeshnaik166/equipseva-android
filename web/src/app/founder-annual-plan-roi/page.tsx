import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return '₹' + v.toLocaleString('en-IN', { maximumFractionDigits: 0 });
}

function pct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  if (!isFinite(v)) return '—';
  return v.toFixed(1) + '%';
}

export default async function FounderAnnualPlanRoiPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const currentYear = new Date().getFullYear();
  const priorYear = currentYear - 1;

  let overview: any = null;
  let priorOverview: any = null;
  let byPillar: any[] = [];
  let topHits: any[] = [];
  let topMisses: any[] = [];
  let lessons: any[] = [];
  let carryForward: any[] = [];
  let yearCompare: any[] = [];

  try {
    const r = await sb.rpc('founder_annual_plan_roi_overview', { p_year: currentYear });
    overview = (r.data && r.data[0]) || null;
  } catch {}
  try {
    const r = await sb.rpc('founder_annual_plan_roi_overview', { p_year: priorYear });
    priorOverview = (r.data && r.data[0]) || null;
  } catch {}
  try {
    const r = await sb.rpc('founder_annual_plan_roi_by_pillar', { p_year: currentYear });
    byPillar = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_annual_plan_top_hits', { p_year: currentYear, p_limit: 10 });
    topHits = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_annual_plan_top_misses', { p_year: currentYear, p_limit: 10 });
    topMisses = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_annual_plan_lessons_list', { p_year: currentYear });
    lessons = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_annual_plan_carry_forward', { p_year: currentYear });
    carryForward = r.data || [];
  } catch {}
  try {
    const r = await sb.rpc('founder_annual_plan_year_compare', { p_year_a: priorYear, p_year_b: currentYear });
    yearCompare = r.data || [];
  } catch {}

  const kpis: Kpi[] = [
    { label: 'Plan Year', value: String(currentYear) },
    { label: 'Pillars Tracked', value: String(overview?.pillars_total ?? 0) },
    { label: 'Pillars Hit', value: String(overview?.pillars_hit ?? 0) },
    { label: 'Pillars Exceeded', value: String(overview?.pillars_exceeded ?? 0) },
    { label: 'Pillars Missed', value: String(overview?.pillars_missed ?? 0) },
    { label: 'Predicted Total', value: rupees(overview?.predicted_total_rupees) },
    { label: 'Actual Total', value: rupees(overview?.actual_total_rupees) },
    { label: 'Investment Total', value: rupees(overview?.investment_total_rupees) },
    { label: 'Blended ROI', value: pct(overview?.blended_roi_pct) },
    { label: 'Top Hits Listed', value: String(topHits.length) },
    { label: 'Top Misses Listed', value: String(topMisses.length) },
    { label: 'Lessons Logged', value: String(lessons.length) },
    { label: 'Carry-Forward Items', value: String(carryForward.length) },
    { label: 'Prior Year Actual', value: rupees(priorOverview?.actual_total_rupees) },
    { label: 'Prior Year ROI', value: pct(priorOverview?.blended_roi_pct) },
    { label: 'YoY Pillars Compared', value: String(yearCompare.length) },
  ];

  const pillarCols: Column<any>[] = [
    { key: 'pillar', header: 'Pillar', render: (r: any) => r.pillar ?? '—' },
    { key: 'predicted_value_rupees', header: 'Predicted', render: (r: any) => rupees(r.predicted_value_rupees) },
    { key: 'actual_value_rupees', header: 'Actual', render: (r: any) => rupees(r.actual_value_rupees) },
    { key: 'investment_rupees', header: 'Investment', render: (r: any) => rupees(r.investment_rupees) },
    { key: 'variance_pct', header: 'Variance', render: (r: any) => pct(r.variance_pct) },
    { key: 'roi_pct', header: 'ROI', render: (r: any) => pct(r.roi_pct) },
    { key: 'verdict', header: 'Verdict', render: (r: any) => r.verdict ?? '—' },
  ];

  const hitCols: Column<any>[] = [
    { key: 'pillar', header: 'Pillar', render: (r: any) => r.pillar ?? '—' },
    { key: 'actual_value_rupees', header: 'Actual', render: (r: any) => rupees(r.actual_value_rupees) },
    { key: 'roi_pct', header: 'ROI', render: (r: any) => pct(r.roi_pct) },
    { key: 'variance_pct', header: 'Variance', render: (r: any) => pct(r.variance_pct) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const missCols: Column<any>[] = [
    { key: 'pillar', header: 'Pillar', render: (r: any) => r.pillar ?? '—' },
    { key: 'predicted_value_rupees', header: 'Predicted', render: (r: any) => rupees(r.predicted_value_rupees) },
    { key: 'actual_value_rupees', header: 'Actual', render: (r: any) => rupees(r.actual_value_rupees) },
    { key: 'variance_pct', header: 'Variance', render: (r: any) => pct(r.variance_pct) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const lessonCols: Column<any>[] = [
    { key: 'pillar', header: 'Pillar', render: (r: any) => r.pillar ?? '—' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '—' },
    { key: 'lesson', header: 'Lesson', render: (r: any) => r.lesson ?? '—' },
    { key: 'follow_up_action', header: 'Follow-up', render: (r: any) => r.follow_up_action ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'carry_to_next_year', header: 'Carry', render: (r: any) => (r.carry_to_next_year ? 'yes' : 'no') },
  ];

  const compareCols: Column<any>[] = [
    { key: 'pillar', header: 'Pillar', render: (r: any) => r.pillar ?? '—' },
    { key: 'actual_a', header: String(priorYear), render: (r: any) => rupees(r.actual_a) },
    { key: 'actual_b', header: String(currentYear), render: (r: any) => rupees(r.actual_b) },
    { key: 'delta_rupees', header: 'Δ ₹', render: (r: any) => rupees(r.delta_rupees) },
    { key: 'delta_pct', header: 'Δ %', render: (r: any) => pct(r.delta_pct) },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Annual Plan ROI Tracker</h1>
        <p className="text-sm text-gray-600">Predictions vs actuals · ROI per pillar · lessons fed into next year</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {kpis.map((k) => (
          <div key={k.label} className="border rounded p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">ROI by Pillar ({currentYear})</h2>
        <DataTable columns={pillarCols} rows={byPillar} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Hits</h2>
        <DataTable columns={hitCols} rows={topHits} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Misses</h2>
        <DataTable columns={missCols} rows={topMisses} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Lessons Learned</h2>
        <DataTable columns={lessonCols} rows={lessons} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">YoY Compare ({priorYear} vs {currentYear})</h2>
        <DataTable columns={compareCols} rows={yearCompare} rowKey={(r: any) => r.pillar} />
      </section>
    </div>
  );
}
