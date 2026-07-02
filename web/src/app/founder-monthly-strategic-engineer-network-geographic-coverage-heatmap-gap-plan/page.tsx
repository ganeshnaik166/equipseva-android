import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [overview, critical, tiers, states, pipeline, mix, topActions] = await Promise.all([
    supabase.rpc('founder_r2949_coverage_overview'),
    supabase.rpc('founder_r2949_critical_cells'),
    supabase.rpc('founder_r2949_tier_breakdown'),
    supabase.rpc('founder_r2949_state_summary'),
    supabase.rpc('founder_r2949_gap_actions_pipeline'),
    supabase.rpc('founder_r2949_action_type_mix'),
    supabase.rpc('founder_r2949_top_gap_actions'),
  ]);

  const ov = (overview.data ?? [])[0] ?? null;

  const criticalCols: Column<any>[] = [
    { key: 'city', header: 'City' },
    { key: 'state_code', header: 'State' },
    { key: 'tier', header: 'Tier' },
    { key: 'active_engineers', header: 'Engineers' },
    { key: 'open_jobs', header: 'Open Jobs' },
    { key: 'sla_breach_pct', header: 'SLA Breach %' },
    { key: 'coverage_score', header: 'Coverage' },
    { key: 'notes', header: 'Notes' },
  ];

  const tierCols: Column<any>[] = [
    { key: 'tier', header: 'Tier' },
    { key: 'cells', header: 'Cells' },
    { key: 'engineers', header: 'Engineers' },
    { key: 'avg_coverage', header: 'Avg Coverage' },
    { key: 'critical_count', header: 'Critical' },
  ];

  const stateCols: Column<any>[] = [
    { key: 'state_code', header: 'State' },
    { key: 'cells', header: 'Cells' },
    { key: 'engineers', header: 'Engineers' },
    { key: 'hospitals', header: 'Hospitals' },
    { key: 'avg_sla_breach', header: 'Avg SLA Breach %' },
    { key: 'avg_coverage', header: 'Avg Coverage' },
  ];

  const pipelineCols: Column<any>[] = [
    { key: 'status', header: 'Status' },
    { key: 'action_count', header: 'Actions' },
    { key: 'total_engineers', header: 'Engineers Target' },
    { key: 'total_budget', header: 'Budget (paise)' },
    { key: 'avg_impact', header: 'Avg Impact' },
  ];

  const mixCols: Column<any>[] = [
    { key: 'action_type', header: 'Action Type' },
    { key: 'n', header: 'Count' },
    { key: 'target_engineers', header: 'Engineers' },
    { key: 'budget', header: 'Budget' },
  ];

  const topCols: Column<any>[] = [
    { key: 'city', header: 'City' },
    { key: 'state_code', header: 'State' },
    { key: 'action_type', header: 'Action' },
    { key: 'target_engineers', header: 'Engineers' },
    { key: 'budget_rupees', header: 'Budget' },
    { key: 'deadline', header: 'Deadline' },
    { key: 'status', header: 'Status' },
    { key: 'expected_impact_score', header: 'Impact' },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>
          Founder Monthly Strategic Engineer-Network Geographic Coverage Heatmap & Gap Plan
        </h1>
        <p style={{ color: '#666' }}>
          Monthly view: where bench is healthy vs. critical, and the action plan to close gaps.
        </p>
      </header>

      {ov && (
        <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
          <div><b>Total Cells:</b> {ov.total_cells}</div>
          <div><b>Critical:</b> {ov.critical_cells}</div>
          <div><b>Strained:</b> {ov.strained_cells}</div>
          <div><b>Watch:</b> {ov.watch_cells}</div>
          <div><b>Healthy:</b> {ov.healthy_cells}</div>
          <div><b>Engineers:</b> {ov.total_engineers}</div>
          <div><b>Open Jobs:</b> {ov.total_open_jobs}</div>
          <div><b>Avg Coverage:</b> {ov.avg_coverage}</div>
        </section>
      )}

      <section>
        <h2>Critical Cells</h2>
        <DataTable
          rows={critical.data ?? []}
          columns={criticalCols}
          emptyMessage="No critical cells"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2>Tier Breakdown</h2>
        <DataTable
          rows={tiers.data ?? []}
          columns={tierCols}
          emptyMessage="No tiers"
          rowKey={(r, i) => String(r.tier ?? i)}
        />
      </section>

      <section>
        <h2>State Summary</h2>
        <DataTable
          rows={states.data ?? []}
          columns={stateCols}
          emptyMessage="No states"
          rowKey={(r, i) => String(r.state_code ?? i)}
        />
      </section>

      <section>
        <h2>Gap Action Pipeline</h2>
        <DataTable
          rows={pipeline.data ?? []}
          columns={pipelineCols}
          emptyMessage="No actions"
          rowKey={(r, i) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2>Action Type Mix</h2>
        <DataTable
          rows={mix.data ?? []}
          columns={mixCols}
          emptyMessage="No mix"
          rowKey={(r, i) => String(r.action_type ?? i)}
        />
      </section>

      <section>
        <h2>Top Gap Actions (by Impact)</h2>
        <DataTable
          rows={topActions.data ?? []}
          columns={topCols}
          emptyMessage="No actions"
          rowKey={(r, i) => String(i)}
        />
      </section>
    </main>
  );
}
