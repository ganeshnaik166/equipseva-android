import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3">
      <div className="text-xs text-neutral-500">{label}</div>
      <div className="mt-1 text-lg font-semibold text-neutral-900">{value}</div>
    </div>
  );
}

function fmtNum(n: any, digits = 2): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!isFinite(v)) return "—";
  return v.toFixed(digits);
}
function fmtPct(n: any): string {
  if (n === null || n === undefined) return "—";
  return `${Number(n).toFixed(1)}%`;
}
function fmtDate(v: any): string {
  if (!v) return "—";
  try { return new Date(v).toLocaleDateString('en-IN'); } catch { return "—"; }
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [kpiRes, trendRes, dimRes, standingRes, detractorRes, outstandingRes, weightsRes] = await Promise.all([
    supabase.rpc('founder_hssv2_kpi_snapshot'),
    supabase.rpc('founder_hssv2_quarterly_trend'),
    supabase.rpc('founder_hssv2_dimension_breakdown'),
    supabase.rpc('founder_hssv2_hospital_standing'),
    supabase.rpc('founder_hssv2_detractor_outreach'),
    supabase.rpc('founder_hssv2_outstanding'),
    supabase.rpc('founder_hssv2_weights_view'),
  ]);

  const kpi: any = (kpiRes.data && (kpiRes.data as any)[0]) || {};
  const trend: any[] = (trendRes.data as any[]) || [];
  const dims: any[] = (dimRes.data as any[]) || [];
  const standing: any[] = (standingRes.data as any[]) || [];
  const detractors: any[] = (detractorRes.data as any[]) || [];
  const outstanding: any[] = (outstandingRes.data as any[]) || [];
  const weights: any[] = (weightsRes.data as any[]) || [];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? "—" },
    { key: 'surveys_sent', header: 'Sent', render: (r: any) => r.surveys_sent ?? 0 },
    { key: 'surveys_submitted', header: 'Submitted', render: (r: any) => r.surveys_submitted ?? 0 },
    { key: 'response_rate_pct', header: 'Response Rate', render: (r: any) => fmtPct(r.response_rate_pct) },
    { key: 'avg_composite', header: 'Avg Composite', render: (r: any) => fmtNum(r.avg_composite) },
    { key: 'nps_score', header: 'NPS', render: (r: any) => fmtNum(r.nps_score, 1) },
  ];

  const dimCols: Column<any>[] = [
    { key: 'display_label', header: 'Dimension', render: (r: any) => r.display_label ?? "—" },
    { key: 'weight', header: 'Weight', render: (r: any) => fmtPct(Number(r.weight ?? 0) * 100) },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => fmtNum(r.avg_score) },
    { key: 'weighted_contribution', header: 'Weighted Contribution', render: (r: any) => fmtNum(r.weighted_contribution, 3) },
    { key: 'responses', header: 'Responses', render: (r: any) => r.responses ?? 0 },
  ];

  const standingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "—" },
    { key: 'city', header: 'City', render: (r: any) => r.city || "—" },
    { key: 'composite_score', header: 'Composite', render: (r: any) => fmtNum(r.composite_score) },
    { key: 'nps_band', header: 'Band', render: (r: any) => r.nps_band ?? "—" },
    { key: 'prior_composite', header: 'Prior', render: (r: any) => fmtNum(r.prior_composite) },
    { key: 'delta', header: 'Delta', render: (r: any) => fmtNum(r.delta) },
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => fmtDate(r.submitted_at) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
  ];

  const detractorCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "—" },
    { key: 'city', header: 'City', render: (r: any) => r.city || "—" },
    { key: 'composite_score', header: 'Composite', render: (r: any) => fmtNum(r.composite_score) },
    { key: 'worst_dim', header: 'Worst Dimension', render: (r: any) => r.worst_dim ?? "—" },
    { key: 'worst_dim_score', header: 'Worst Score', render: (r: any) => r.worst_dim_score ?? "—" },
    { key: 'comment', header: 'Comment', render: (r: any) => r.comment ? String(r.comment).slice(0, 80) : "—" },
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => fmtDate(r.submitted_at) },
  ];

  const outstandingCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? "—" },
    { key: 'city', header: 'City', render: (r: any) => r.city || "—" },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? "—" },
    { key: 'sent_at', header: 'Sent', render: (r: any) => fmtDate(r.sent_at) },
    { key: 'quarter_end', header: 'Due', render: (r: any) => fmtDate(r.quarter_end) },
    { key: 'days_open', header: 'Days Open', render: (r: any) => r.days_open ?? 0 },
    { key: 'is_overdue', header: 'Overdue', render: (r: any) => r.is_overdue ? 'yes' : 'no' },
  ];

  const weightCols: Column<any>[] = [
    { key: 'display_label', header: 'Dimension', render: (r: any) => r.display_label ?? "—" },
    { key: 'weight', header: 'Weight', render: (r: any) => fmtNum(r.weight, 3) },
    { key: 'weight_pct', header: 'Weight %', render: (r: any) => fmtPct(r.weight_pct) },
    { key: 'updated_at', header: 'Updated', render: (r: any) => fmtDate(r.updated_at) },
  ];

  return (
    <main className="mx-auto max-w-6xl px-4 py-6">
      <header className="mb-4">
        <h1 className="text-xl font-semibold text-neutral-900">Hospital Satisfaction Survey v2</h1>
        <p className="text-sm text-neutral-600">Quarterly 8-dimension survey · weighted composite · quarter-over-quarter trend.</p>
      </header>

      <section className="mb-6">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <Kpi label="Surveys sent (Q)" value={String(kpi.surveys_sent_q ?? 0)} />
          <Kpi label="Submitted (Q)" value={String(kpi.surveys_submitted_q ?? 0)} />
          <Kpi label="Response rate" value={fmtPct(kpi.response_rate_pct)} />
          <Kpi label="Avg composite" value={fmtNum(kpi.avg_composite)} />
          <Kpi label="Promoters" value={String(kpi.promoter_count ?? 0)} />
          <Kpi label="Passives" value={String(kpi.passive_count ?? 0)} />
          <Kpi label="Detractors" value={String(kpi.detractor_count ?? 0)} />
          <Kpi label="NPS" value={fmtNum(kpi.nps_score, 1)} />
          <Kpi label="Best dimension" value={kpi.best_dimension ?? "—"} />
          <Kpi label="Best dim score" value={fmtNum(kpi.best_dimension_score)} />
          <Kpi label="Worst dimension" value={kpi.worst_dimension ?? "—"} />
          <Kpi label="Worst dim score" value={fmtNum(kpi.worst_dimension_score)} />
          <Kpi label="Hospitals covered" value={String(kpi.hospitals_covered ?? 0)} />
          <Kpi label="Hospitals total" value={String(kpi.hospitals_total ?? 0)} />
          <Kpi label="Overdue surveys" value={String(kpi.overdue_count ?? 0)} />
          <Kpi label="QoQ delta" value={fmtNum(kpi.composite_qoq_delta)} />
        </div>
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-sm font-semibold text-neutral-800">Quarterly trend (last 8 quarters)</h2>
        <DataTable<any> rows={trend} columns={trendCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-sm font-semibold text-neutral-800">Dimension breakdown (current quarter)</h2>
        <DataTable<any> rows={dims} columns={dimCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-sm font-semibold text-neutral-800">Hospital standing</h2>
        <DataTable<any> rows={standing} columns={standingCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-sm font-semibold text-neutral-800">Detractors needing outreach</h2>
        <DataTable<any> rows={detractors} columns={detractorCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-sm font-semibold text-neutral-800">Outstanding surveys</h2>
        <DataTable<any> rows={outstanding} columns={outstandingCols} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="mb-2 text-sm font-semibold text-neutral-800">Dimension weights (config)</h2>
        <DataTable<any> rows={weights} columns={weightCols} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
