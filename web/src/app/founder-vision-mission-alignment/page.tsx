import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderVisionMissionAlignmentPage() {
  const sb = await getSupabaseServerClient();

  const [decisionsRes, misalignedRes, actionsRes] = await Promise.all([
    sb.rpc('r2146_list_decisions'),
    sb.rpc('r2146_misaligned'),
    sb.rpc('r2146_recent_actions'),
  ]);

  const decisions: any[] = Array.isArray(decisionsRes.data) ? decisionsRes.data : [];
  const misaligned: any[] = Array.isArray(misalignedRes.data) ? misalignedRes.data : [];
  const actions: any[] = Array.isArray(actionsRes.data) ? actionsRes.data : [];

  const decisionCols: Column<any>[] = [
    { key: 'decision_label', header: 'Decision', render: (r: any) => String(r.decision_label ?? '') },
    { key: 'vision_alignment_score', header: 'Vision Score', render: (r: any) => String(r.vision_alignment_score ?? '') },
    { key: 'mission_alignment_score', header: 'Mission Score', render: (r: any) => String(r.mission_alignment_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured At', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const misalignedCols: Column<any>[] = [
    { key: 'decision_label', header: 'Decision', render: (r: any) => String(r.decision_label ?? '') },
    { key: 'vision_alignment_score', header: 'Vision Score', render: (r: any) => String(r.vision_alignment_score ?? '') },
    { key: 'mission_alignment_score', header: 'Mission Score', render: (r: any) => String(r.mission_alignment_score ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured At', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'decision_id', header: 'Decision Id', render: (r: any) => String(r.decision_id ?? '').slice(0, 8) },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Founder Vision-Mission Alignment</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track alignment of decisions to company vision and mission. Score range zero to one hundred. Items with score under fifty surface as misaligned.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Decisions</h2>
        <DataTable rows={decisions} columns={decisionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Misaligned Decisions</h2>
        <p style={{ color: '#666', marginBottom: 8 }}>
          Decisions flagged misaligned or scoring under fifty on either axis.
        </p>
        <DataTable rows={misaligned} columns={misalignedCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent Actions Log</h2>
        <DataTable rows={actions} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
