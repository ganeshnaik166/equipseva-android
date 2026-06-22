import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type HealthRow = {
  id: string;
  investor_id_label: string;
  relationship_score: number;
  last_signal_md: string | null;
  signal_type: string;
  status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  health_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [healthsRes, atRiskRes, recentRes] = await Promise.all([
    sb.rpc('list_healths_r2094'),
    sb.rpc('at_risk_r2094'),
    sb.rpc('recent_actions_r2094'),
  ]);

  const healths: HealthRow[] = (healthsRes.data as HealthRow[]) ?? [];
  const atRisk: HealthRow[] = (atRiskRes.data as HealthRow[]) ?? [];
  const recent: ActionRow[] = (recentRes.data as ActionRow[]) ?? [];

  const healthCols: Column<HealthRow>[] = [
    { key: 'investor_id_label', header: 'Investor', render: (r: any) => r.investor_id_label },
    { key: 'relationship_score', header: 'Score', render: (r: any) => String(r.relationship_score) },
    { key: 'signal_type', header: 'Signal', render: (r: any) => r.signal_type },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const atRiskCols: Column<HealthRow>[] = [
    { key: 'investor_id_label', header: 'Investor', render: (r: any) => r.investor_id_label },
    { key: 'relationship_score', header: 'Score', render: (r: any) => String(r.relationship_score) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'signal_type', header: 'Signal', render: (r: any) => r.signal_type },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const actionCols: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '' },
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'notes_md', header: 'Notes', render: (r: any) => r.notes_md ?? '' },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Founder Investor Relationship Health</h1>
        <p style={{ color: '#555' }}>Score investor relationships, capture signals, log engagement actions, and surface at-risk relationships before they slip away.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Relationship Health Snapshots</h2>
        <DataTable rows={healths} columns={healthCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>At-Risk Relationships</h2>
        <p style={{ color: '#777', marginBottom: 8 }}>Status of at risk, critical, or lost, OR score under fifty.</p>
        <DataTable rows={atRisk} columns={atRiskCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Relationship Actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
