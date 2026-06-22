import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCrossFunctionalInitiativeMapPage() {
  const sb = await getSupabaseServerClient();

  const [allRes, activeRes, recentRes] = await Promise.all([
    sb.rpc('list_initiatives_r2066'),
    sb.rpc('active_initiatives_r2066'),
    sb.rpc('recent_actions_r2066'),
  ]);

  const all = (allRes.data ?? []) as Array<Record<string, unknown>>;
  const active = (activeRes.data ?? []) as Array<Record<string, unknown>>;
  const recent = (recentRes.data ?? []) as Array<Record<string, unknown>>;

  const allCols: Column<Record<string, unknown>>[] = [
    { key: 'initiative_label', header: 'Initiative', render: (r: any) => String(r.initiative_label ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'expected_completion_date', header: 'Expected', render: (r: any) => r.expected_completion_date ? String(r.expected_completion_date) : '' },
    { key: 'total_budget_rupees', header: 'Budget (rupees)', render: (r: any) => r.total_budget_rupees != null ? String(r.total_budget_rupees) : '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(String(r.captured_at)).toLocaleString() : '' },
  ];

  const activeCols: Column<Record<string, unknown>>[] = [
    { key: 'initiative_label', header: 'Initiative', render: (r: any) => String(r.initiative_label ?? '') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => String(r.owner_email ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'expected_completion_date', header: 'Expected', render: (r: any) => r.expected_completion_date ? String(r.expected_completion_date) : '' },
    { key: 'total_budget_rupees', header: 'Budget (rupees)', render: (r: any) => r.total_budget_rupees != null ? String(r.total_budget_rupees) : '' },
  ];

  const recentCols: Column<Record<string, unknown>>[] = [
    { key: 'initiative_label', header: 'Initiative', render: (r: any) => String(r.initiative_label ?? '') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken at', render: (r: any) => r.taken_at ? new Date(String(r.taken_at)).toLocaleString() : '' },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 600 }}>Founder Cross-Functional Initiative Map</h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Map cross-functional initiatives spanning multiple teams. Track status, owners, budgets, and action history.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Active initiatives</h2>
        <DataTable
          rows={active}
          columns={activeCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All initiatives</h2>
        <DataTable
          rows={all}
          columns={allCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent actions</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
