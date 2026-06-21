import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

type BenchRow = {
  id: string;
  equipment_category: string;
  primary_engineer_count: number;
  backup_engineer_count: number;
  total_capable: number;
  min_required: number;
  status: string;
  recomputed_at: string;
};

type ActionRow = {
  id: string;
  category: string;
  action_type: string;
  target_count: number;
  action_at: string;
  status: string;
  notes: string | null;
};

type AtRiskRow = {
  equipment_category: string;
  total_capable: number;
  min_required: number;
  shortfall: number;
  status: string;
};

type SummaryRow = {
  total_categories: number;
  overstaffed_count: number;
  balanced_count: number;
  at_risk_count: number;
  critical_shortage_count: number;
  total_engineers: number;
  avg_bench_depth: number | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [benchRes, actionsRes, atRiskRes, summaryRes] = await Promise.all([
    sb.rpc('list_bench_r1792'),
    sb.rpc('list_bench_actions_r1792'),
    sb.rpc('at_risk_bench_categories_r1792'),
    sb.rpc('bench_redundancy_summary_r1792'),
  ]);

  const bench: BenchRow[] = (benchRes.data as BenchRow[]) || [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[]) || [];
  const atRisk: AtRiskRow[] = (atRiskRes.data as AtRiskRow[]) || [];
  const summary: SummaryRow | null =
    Array.isArray(summaryRes.data) && summaryRes.data.length > 0
      ? (summaryRes.data[0] as SummaryRow)
      : null;

  const benchCols: Column<BenchRow>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category },
    { key: 'primary_engineer_count', header: 'Primary', render: (r: any) => r.primary_engineer_count },
    { key: 'backup_engineer_count', header: 'Backup', render: (r: any) => r.backup_engineer_count },
    { key: 'total_capable', header: 'Total', render: (r: any) => r.total_capable },
    { key: 'min_required', header: 'Min Req', render: (r: any) => r.min_required },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    {
      key: 'recomputed_at',
      header: 'Recomputed',
      render: (r: any) => (r.recomputed_at ? new Date(r.recomputed_at).toLocaleString() : '-'),
    },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category },
    { key: 'action_type', header: 'Type', render: (r: any) => r.action_type },
    { key: 'target_count', header: 'Target', render: (r: any) => r.target_count },
    {
      key: 'action_at',
      header: 'When',
      render: (r: any) => (r.action_at ? new Date(r.action_at).toLocaleString() : '-'),
    },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes || '-' },
  ];

  const atRiskCols: Column<AtRiskRow>[] = [
    { key: 'equipment_category', header: 'Category', render: (r: any) => r.equipment_category },
    { key: 'total_capable', header: 'Capable', render: (r: any) => r.total_capable },
    { key: 'min_required', header: 'Min Required', render: (r: any) => r.min_required },
    { key: 'shortfall', header: 'Shortfall', render: (r: any) => r.shortfall },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer Bench Strength Tracker
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Track engineer roster strength per equipment category for redundancy. Surfaces
        at-risk and critically-short categories so we can hire, cross-train, or contract before
        coverage breaks.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Redundancy Summary
        </h2>
        {summary ? (
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))',
              gap: '12px',
            }}
          >
            <div style={{ padding: '12px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
              <div style={{ fontSize: '12px', color: '#666' }}>Total Categories</div>
              <div style={{ fontSize: '22px', fontWeight: 700 }}>{summary.total_categories}</div>
            </div>
            <div style={{ padding: '12px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
              <div style={{ fontSize: '12px', color: '#666' }}>Overstaffed</div>
              <div style={{ fontSize: '22px', fontWeight: 700 }}>{summary.overstaffed_count}</div>
            </div>
            <div style={{ padding: '12px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
              <div style={{ fontSize: '12px', color: '#666' }}>Balanced</div>
              <div style={{ fontSize: '22px', fontWeight: 700 }}>{summary.balanced_count}</div>
            </div>
            <div style={{ padding: '12px', border: '1px solid #f59e0b', borderRadius: '8px' }}>
              <div style={{ fontSize: '12px', color: '#92400e' }}>At Risk</div>
              <div style={{ fontSize: '22px', fontWeight: 700, color: '#92400e' }}>
                {summary.at_risk_count}
              </div>
            </div>
            <div style={{ padding: '12px', border: '1px solid #dc2626', borderRadius: '8px' }}>
              <div style={{ fontSize: '12px', color: '#991b1b' }}>Critical Shortage</div>
              <div style={{ fontSize: '22px', fontWeight: 700, color: '#991b1b' }}>
                {summary.critical_shortage_count}
              </div>
            </div>
            <div style={{ padding: '12px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
              <div style={{ fontSize: '12px', color: '#666' }}>Total Engineers</div>
              <div style={{ fontSize: '22px', fontWeight: 700 }}>{summary.total_engineers}</div>
            </div>
            <div style={{ padding: '12px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
              <div style={{ fontSize: '12px', color: '#666' }}>Avg Bench Depth</div>
              <div style={{ fontSize: '22px', fontWeight: 700 }}>
                {summary.avg_bench_depth ?? '-'}
              </div>
            </div>
          </div>
        ) : (
          <div style={{ color: '#666' }}>No summary yet. Run refresh.</div>
        )}
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Bench Strength by Category
        </h2>
        <DataTable
          rows={bench}
          columns={benchCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          At-Risk Categories (shortfall &gt; 0)
        </h2>
        <DataTable
          rows={atRisk}
          columns={atRiskCols}
          rowKey={(r: any, i: number) => String(r.equipment_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Planned & In-Progress Actions
        </h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
