import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [specs, assessments, topEng, plateau, kindSum, monthly, recDist] = await Promise.all([
    supabase.rpc('list_specializations_r2534'),
    supabase.rpc('list_assessments_r2534'),
    supabase.rpc('top_depth_engineers_r2534'),
    supabase.rpc('plateau_focus_r2534'),
    supabase.rpc('equipment_kind_summary_r2534'),
    supabase.rpc('monthly_depth_trend_r2534'),
    supabase.rpc('recommendation_distribution_r2534'),
  ]);

  const specRows = (specs.data ?? []) as any[];
  const assessRows = (assessments.data ?? []) as any[];
  const topRows = (topEng.data ?? []) as any[];
  const plateauRows = (plateau.data ?? []) as any[];
  const kindRows = (kindSum.data ?? []) as any[];
  const monthlyRows = (monthly.data ?? []) as any[];
  const recRows = (recDist.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString() : '—');
  const fmtMonth = (v: any) =>
    v ? new Date(v).toLocaleDateString(undefined, { year: 'numeric', month: 'short' }) : '—';
  const fmtNum = (v: any, d = 2) =>
    v === null || v === undefined ? '—' : Number(v).toFixed(d);

  const specCols: Column<any>[] = [
    { key: 'model', header: 'Equipment Model', render: (r: any) => r.equipment_model ?? '—' },
    { key: 'kind', header: 'Kind', render: (r: any) => r.equipment_kind ?? '—' },
    { key: 'owner', header: 'Engineer', render: (r: any) => r.owner_email ?? '—' },
    { key: 'jobs', header: 'Jobs Done', render: (r: any) => r.jobs_done ?? 0 },
    { key: 'depth', header: 'Depth Score', render: (r: any) => `${r.depth_score ?? 0} / 100` },
    {
      key: 'cert',
      header: 'Certification',
      render: (r: any) => r.certification_status ?? '—',
    },
    {
      key: 'dimret',
      header: 'Diminishing %',
      render: (r: any) => `${fmtNum(r.diminishing_returns_pct, 2)}%`,
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'last', header: 'Last Assessed', render: (r: any) => fmtDate(r.last_assessed_at) },
  ];

  const assessCols: Column<any>[] = [
    { key: 'when', header: 'Assessed At', render: (r: any) => fmtDate(r.assessed_at) },
    { key: 'model', header: 'Equipment Model', render: (r: any) => r.equipment_model ?? '—' },
    { key: 'pre', header: 'Pre Score', render: (r: any) => r.pre_score ?? 0 },
    { key: 'post', header: 'Post Score', render: (r: any) => r.post_score ?? 0 },
    {
      key: 'delta',
      header: 'Gain Δ',
      render: (r: any) => {
        const d = Number(r.gain_delta ?? 0);
        const color = d > 0 ? '#0a7d2c' : d < 0 ? '#b00020' : 'inherit';
        return <span style={{ color, fontWeight: 600 }}>{d >= 0 ? '+' : ''}{d}</span>;
      },
    },
    { key: 'rec', header: 'Recommendation', render: (r: any) => r.recommendation ?? '—' },
    { key: 'assessor', header: 'Assessor', render: (r: any) => r.assessor_email ?? '—' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const topCols: Column<any>[] = [
    { key: 'owner', header: 'Engineer', render: (r: any) => r.owner_email ?? '—' },
    { key: 'spec', header: 'Specializations', render: (r: any) => r.specializations ?? 0 },
    { key: 'avg', header: 'Avg Depth', render: (r: any) => fmtNum(r.avg_depth, 2) },
    { key: 'jobs', header: 'Total Jobs', render: (r: any) => r.total_jobs ?? 0 },
    { key: 'top', header: 'Top Model', render: (r: any) => r.top_model ?? '—' },
  ];

  const plateauCols: Column<any>[] = [
    { key: 'owner', header: 'Engineer', render: (r: any) => r.owner_email ?? '—' },
    { key: 'model', header: 'Equipment Model', render: (r: any) => r.equipment_model ?? '—' },
    { key: 'kind', header: 'Kind', render: (r: any) => r.equipment_kind ?? '—' },
    { key: 'depth', header: 'Depth', render: (r: any) => r.depth_score ?? 0 },
    {
      key: 'dim',
      header: 'Diminishing %',
      render: (r: any) => `${fmtNum(r.diminishing_returns_pct, 2)}%`,
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'last', header: 'Last Assessed', render: (r: any) => fmtDate(r.last_assessed_at) },
    { key: 'sug', header: 'Suggested', render: (r: any) => r.suggested_action ?? '—' },
  ];

  const kindCols: Column<any>[] = [
    { key: 'kind', header: 'Equipment Kind', render: (r: any) => r.equipment_kind ?? '—' },
    { key: 'spec', header: 'Specialists', render: (r: any) => r.specialists ?? 0 },
    { key: 'avg', header: 'Avg Depth', render: (r: any) => fmtNum(r.avg_depth, 2) },
    { key: 'jobs', header: 'Total Jobs', render: (r: any) => r.total_jobs ?? 0 },
    { key: 'cert', header: 'Certified', render: (r: any) => r.certified_count ?? 0 },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'm', header: 'Month', render: (r: any) => fmtMonth(r.month_start) },
    { key: 'n', header: 'Assessments', render: (r: any) => r.assessments ?? 0 },
    { key: 'pre', header: 'Avg Pre', render: (r: any) => fmtNum(r.avg_pre, 2) },
    { key: 'post', header: 'Avg Post', render: (r: any) => fmtNum(r.avg_post, 2) },
    {
      key: 'gain',
      header: 'Avg Gain',
      render: (r: any) => {
        const g = Number(r.avg_gain ?? 0);
        const color = g > 0 ? '#0a7d2c' : g < 0 ? '#b00020' : 'inherit';
        return <span style={{ color, fontWeight: 600 }}>{fmtNum(g, 2)}</span>;
      },
    },
  ];

  const recCols: Column<any>[] = [
    { key: 'rec', header: 'Recommendation', render: (r: any) => r.recommendation ?? '—' },
    { key: 'n', header: 'Count', render: (r: any) => r.n ?? 0 },
    { key: 'avg', header: 'Avg Gain', render: (r: any) => fmtNum(r.avg_gain, 2) },
    { key: 'last', header: 'Last At', render: (r: any) => fmtDate(r.last_at) },
  ];

  return (
    <div className="space-y-8 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Engineer Equipment Specialization & Depth Curve</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Track engineer depth per equipment model. Spot plateau & decay early so we can
          cross-train, refresh certs, or diversify before diminishing returns &gt;= 15% hit revenue.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Specializations</h2>
        <DataTable
          columns={specCols}
          rows={specRows}
          emptyMessage="No specializations yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Plateau & Decay Focus</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Rows where status is plateau/decay OR diminishing returns &gt;= 15%.
        </p>
        <DataTable
          columns={plateauCols}
          rows={plateauRows}
          emptyMessage="No plateau/decay engineers — healthy curve."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top Depth Engineers</h2>
        <DataTable
          columns={topCols}
          rows={topRows}
          emptyMessage="No engineers ranked."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Equipment Kind Summary</h2>
        <DataTable
          columns={kindCols}
          rows={kindRows}
          emptyMessage="No equipment kinds."
          rowKey={(r: any, i: number) => String(r.equipment_kind ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Depth Curve Assessments</h2>
        <DataTable
          columns={assessCols}
          rows={assessRows}
          emptyMessage="No assessments yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Monthly Depth Trend</h2>
        <DataTable
          columns={monthlyCols}
          rows={monthlyRows}
          emptyMessage="No monthly trend."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Recommendation Distribution</h2>
        <DataTable
          columns={recCols}
          rows={recRows}
          emptyMessage="No recommendations."
          rowKey={(r: any, i: number) => String(r.recommendation ?? i)}
        />
      </section>
    </div>
  );
}
