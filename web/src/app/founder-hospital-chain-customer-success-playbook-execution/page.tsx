import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    runsRes,
    deviationsRes,
    lowAdherenceRes,
    severityRes,
    kindSummaryRes,
    outcomeDistRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_runs_r2483'),
    supabase.rpc('list_deviations_r2483'),
    supabase.rpc('low_adherence_focus_r2483'),
    supabase.rpc('top_deviation_severity_r2483'),
    supabase.rpc('playbook_kind_summary_r2483'),
    supabase.rpc('outcome_distribution_r2483'),
    supabase.rpc('owner_load_r2483'),
  ]);

  const runs = (runsRes.data ?? []) as any[];
  const deviations = (deviationsRes.data ?? []) as any[];
  const lowAdherence = (lowAdherenceRes.data ?? []) as any[];
  const severity = (severityRes.data ?? []) as any[];
  const kindSummary = (kindSummaryRes.data ?? []) as any[];
  const outcomeDist = (outcomeDistRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];

  const runCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'playbook_kind', header: 'Playbook', render: (r: any) => r.playbook_kind },
    { key: 'execution_stage', header: 'Stage', render: (r: any) => r.execution_stage },
    { key: 'adherence_pct', header: 'Adherence %', render: (r: any) => `${r.adherence_pct}%` },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const devCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'step_skipped', header: 'Step Skipped', render: (r: any) => r.step_skipped },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'deviation_reason', header: 'Reason', render: (r: any) => r.deviation_reason ?? '-' },
    { key: 'kill_action_md', header: 'Kill Action', render: (r: any) => r.kill_action_md ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const lowAdherenceCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'playbook_kind', header: 'Playbook', render: (r: any) => r.playbook_kind },
    { key: 'execution_stage', header: 'Stage', render: (r: any) => r.execution_stage },
    { key: 'adherence_pct', header: 'Adherence %', render: (r: any) => `${r.adherence_pct}%` },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const severityCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'total_deviations', header: 'Total', render: (r: any) => r.total_deviations },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
    { key: 'closed_count', header: 'Closed', render: (r: any) => r.closed_count },
  ];

  const kindCols: Column<any>[] = [
    { key: 'playbook_kind', header: 'Playbook', render: (r: any) => r.playbook_kind },
    { key: 'run_count', header: 'Runs', render: (r: any) => r.run_count },
    { key: 'avg_adherence', header: 'Avg Adherence', render: (r: any) => r.avg_adherence },
    { key: 'success_count', header: 'Successes', render: (r: any) => r.success_count },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'run_count', header: 'Runs', render: (r: any) => r.run_count },
    { key: 'avg_adherence', header: 'Avg Adherence', render: (r: any) => r.avg_adherence },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'active_runs', header: 'Active Runs', render: (r: any) => r.active_runs },
    { key: 'total_runs', header: 'Total Runs', render: (r: any) => r.total_runs },
    { key: 'avg_adherence', header: 'Avg Adherence', render: (r: any) => r.avg_adherence },
    { key: 'open_deviations', header: 'Open Deviations', render: (r: any) => r.open_deviations },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital Chain Customer Success Playbook Execution
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Round 2483 — Chain × playbook × execution stage × adherence × outcome × deviation kill.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Low Adherence Focus (<75%)</h2>
        <DataTable
          rows={lowAdherence}
          columns={lowAdherenceCols}
          emptyMessage="No low-adherence runs."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Deviation Severity Breakdown</h2>
        <DataTable
          rows={severity}
          columns={severityCols}
          emptyMessage="No deviations logged."
          rowKey={(r: any, i: number) => String(r.severity ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Playbook Kind Summary</h2>
        <DataTable
          rows={kindSummary}
          columns={kindCols}
          emptyMessage="No playbook runs."
          rowKey={(r: any, i: number) => String(r.playbook_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Outcome Distribution</h2>
        <DataTable
          rows={outcomeDist}
          columns={outcomeCols}
          emptyMessage="No outcomes."
          rowKey={(r: any, i: number) => String(r.outcome_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owners assigned."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Playbook Runs</h2>
        <DataTable
          rows={runs}
          columns={runCols}
          emptyMessage="No runs logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>All Deviations</h2>
        <DataTable
          rows={deviations}
          columns={devCols}
          emptyMessage="No deviations logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
