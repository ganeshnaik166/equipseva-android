import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Candidate = {
  id: string;
  engineer_user_id: string;
  current_tier: string;
  target_tier: string;
  readiness_score: number;
  status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  pipeline_id: string;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [candidatesRes, topRes, actionsRes] = await Promise.all([
    sb.rpc('list_candidates_r2104'),
    sb.rpc('top_ready_r2104'),
    sb.rpc('recent_actions_r2104'),
  ]);

  const candidates: Candidate[] = (candidatesRes.data as Candidate[]) ?? [];
  const topReady: Candidate[] = (topRes.data as Candidate[]) ?? [];
  const recentActions: ActionRow[] = (actionsRes.data as ActionRow[]) ?? [];

  const candidateColumns: Column<Candidate>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'current_tier', header: 'Current Tier', render: (r: any) => String(r.current_tier ?? '') },
    { key: 'target_tier', header: 'Target Tier', render: (r: any) => String(r.target_tier ?? '') },
    { key: 'readiness_score', header: 'Readiness', render: (r: any) => `${r.readiness_score ?? 0} of 100` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => new Date(r.captured_at).toLocaleString() },
  ];

  const topColumns: Column<Candidate>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'current_tier', header: 'From', render: (r: any) => String(r.current_tier ?? '') },
    { key: 'target_tier', header: 'To', render: (r: any) => String(r.target_tier ?? '') },
    { key: 'readiness_score', header: 'Score', render: (r: any) => String(r.readiness_score ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: 'pipeline_id', header: 'Pipeline', render: (r: any) => String(r.pipeline_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken', render: (r: any) => new Date(r.taken_at).toLocaleString() },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Engineer Promotion Pipeline</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Track engineer promotion candidates from nomination to promoted status. Readiness scored zero to one hundred.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top Ready Candidates</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>
          Highest readiness scores across candidate, in review, and approved statuses.
        </p>
        <DataTable
          rows={topReady}
          columns={topColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All Candidates</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>
          Full pipeline view, most recently captured first.
        </p>
        <DataTable
          rows={candidates}
          columns={candidateColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Actions</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>
          Audit trail of nominations, reviews, approvals, declines, promotions, and escalations.
        </p>
        <DataTable
          rows={recentActions}
          columns={actionColumns}
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
