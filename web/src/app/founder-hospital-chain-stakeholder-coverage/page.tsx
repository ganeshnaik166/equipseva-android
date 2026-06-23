import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [coverageRes, plansRes, uncoveredRes, highRiskRes, roleSummaryRes, ownerLoadRes, touchedRes] =
    await Promise.all([
      supabase.rpc('list_coverage_r2455'),
      supabase.rpc('list_action_plans_r2455'),
      supabase.rpc('uncovered_focus_r2455'),
      supabase.rpc('high_risk_chains_r2455'),
      supabase.rpc('role_coverage_summary_r2455'),
      supabase.rpc('action_owner_load_r2455'),
      supabase.rpc('recently_touched_summary_r2455'),
    ]);

  const coverage = (coverageRes.data ?? []) as any[];
  const plans = (plansRes.data ?? []) as any[];
  const uncovered = (uncoveredRes.data ?? []) as any[];
  const highRisk = (highRiskRes.data ?? []) as any[];
  const roleSummary = (roleSummaryRes.data ?? []) as any[];
  const ownerLoad = (ownerLoadRes.data ?? []) as any[];
  const touched = (touchedRes.data ?? []) as any[];

  const coverageCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'role_kind', header: 'Role', render: (r: any) => r.role_kind },
    { key: 'is_covered', header: 'Covered?', render: (r: any) => (r.is_covered ? 'yes' : 'no') },
    { key: 'primary_contact_email', header: 'Contact', render: (r: any) => r.primary_contact_email ?? '-' },
    { key: 'last_touch_at', header: 'Last touch', render: (r: any) => (r.last_touch_at ? new Date(r.last_touch_at).toLocaleDateString() : '-') },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength },
    { key: 'risk_level', header: 'Risk', render: (r: any) => r.risk_level },
    { key: 'gap_owner_email', header: 'Gap owner', render: (r: any) => r.gap_owner_email ?? '-' },
    { key: 'gap_notes', header: 'Gap notes', render: (r: any) => r.gap_notes ?? '-' },
  ];

  const planCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'role_kind', header: 'Role', render: (r: any) => r.role_kind },
    { key: 'opened_at', header: 'Opened', render: (r: any) => new Date(r.opened_at).toLocaleDateString() },
    { key: 'recommended_action_md', header: 'Action', render: (r: any) => r.recommended_action_md ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'action_due_at', header: 'Due', render: (r: any) => (r.action_due_at ? new Date(r.action_due_at).toLocaleDateString() : '-') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'closed_at', header: 'Closed', render: (r: any) => (r.closed_at ? new Date(r.closed_at).toLocaleDateString() : '-') },
  ];

  const uncoveredCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'role_kind', header: 'Role', render: (r: any) => r.role_kind },
    { key: 'risk_level', header: 'Risk', render: (r: any) => r.risk_level },
    { key: 'relationship_strength', header: 'Strength', render: (r: any) => r.relationship_strength },
    { key: 'gap_owner_email', header: 'Gap owner', render: (r: any) => r.gap_owner_email ?? '-' },
    { key: 'gap_notes', header: 'Notes', render: (r: any) => r.gap_notes ?? '-' },
  ];

  const highRiskCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'total_roles', header: 'Total roles', render: (r: any) => String(r.total_roles ?? 0) },
    { key: 'covered_roles', header: 'Covered', render: (r: any) => String(r.covered_roles ?? 0) },
    { key: 'high_risk_count', header: 'High risk', render: (r: any) => String(r.high_risk_count ?? 0) },
    { key: 'critical_risk_count', header: 'Critical', render: (r: any) => String(r.critical_risk_count ?? 0) },
    { key: 'coverage_pct', header: 'Coverage %', render: (r: any) => (r.coverage_pct == null ? '-' : String(r.coverage_pct)) },
  ];

  const roleSummaryCols: Column<any>[] = [
    { key: 'role_kind', header: 'Role', render: (r: any) => r.role_kind },
    { key: 'total_chains', header: 'Chains tracked', render: (r: any) => String(r.total_chains ?? 0) },
    { key: 'covered_chains', header: 'Covered', render: (r: any) => String(r.covered_chains ?? 0) },
    { key: 'uncovered_chains', header: 'Uncovered', render: (r: any) => String(r.uncovered_chains ?? 0) },
    { key: 'coverage_pct', header: 'Coverage %', render: (r: any) => (r.coverage_pct == null ? '-' : String(r.coverage_pct)) },
  ];

  const ownerLoadCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? 'unassigned' },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
    { key: 'in_progress_count', header: 'In progress', render: (r: any) => String(r.in_progress_count ?? 0) },
    { key: 'done_count', header: 'Done', render: (r: any) => String(r.done_count ?? 0) },
    { key: 'dropped_count', header: 'Dropped', render: (r: any) => String(r.dropped_count ?? 0) },
    { key: 'overdue_count', header: 'Overdue', render: (r: any) => String(r.overdue_count ?? 0) },
  ];

  const touchedCols: Column<any>[] = [
    { key: 'bucket', header: 'Recency', render: (r: any) => r.bucket },
    { key: 'role_count', header: 'Roles', render: (r: any) => String(r.role_count ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Hospital Chain Stakeholder Coverage
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track who is covered across each hospital chain & who owns the gap. Risk-weighted, action-planned.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>High-risk chains</h2>
        <DataTable
          rows={highRisk}
          columns={highRiskCols}
          emptyMessage="No chains yet."
          rowKey={(r: any, i: number) => String(r.id ?? `${r.chain_name}-${i}`)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Uncovered focus (sorted by risk)</h2>
        <DataTable
          rows={uncovered}
          columns={uncoveredCols}
          emptyMessage="No uncovered roles."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Role coverage summary</h2>
        <DataTable
          rows={roleSummary}
          columns={roleSummaryCols}
          emptyMessage="No role data."
          rowKey={(r: any, i: number) => String(r.role_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Action plans</h2>
        <DataTable
          rows={plans}
          columns={planCols}
          emptyMessage="No action plans yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Owner load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerLoadCols}
          emptyMessage="No actions assigned."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recently touched</h2>
        <DataTable
          rows={touched}
          columns={touchedCols}
          emptyMessage="No touch data."
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All stakeholder coverage</h2>
        <DataTable
          rows={coverage}
          columns={coverageCols}
          emptyMessage="No coverage rows."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
