import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPersonalDecisionLogPage() {
  const sb = await getSupabaseServerClient();

  const [decisionsRes, byStatusRes, retrosRes] = await Promise.all([
    sb.rpc('list_decisions_r1922'),
    sb.rpc('decisions_by_status_r1922'),
    sb.rpc('recent_retros_r1922'),
  ]);

  const decisions: any[] = Array.isArray(decisionsRes.data) ? decisionsRes.data : [];
  const byStatus: any[] = Array.isArray(byStatusRes.data) ? byStatusRes.data : [];
  const retros: any[] = Array.isArray(retrosRes.data) ? retrosRes.data : [];

  const decisionCols: Column<any>[] = [
    { key: 'decision_label', header: 'Decision', render: (r: any) => String(r.decision_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'decided_at', header: 'Decided', render: (r: any) => r.decided_at ? new Date(r.decided_at).toLocaleDateString() : 'unknown' },
    { key: 'context_md', header: 'Context', render: (r: any) => String(r.context_md ?? '').slice(0, 140) },
    { key: 'reasoning_md', header: 'Reasoning', render: (r: any) => String(r.reasoning_md ?? '').slice(0, 140) },
    { key: 'retro_at', header: 'Retro at', render: (r: any) => r.retro_at ? new Date(r.retro_at).toLocaleDateString() : 'pending' },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'decision_count', header: 'Count', render: (r: any) => String(r.decision_count ?? 0) },
  ];

  const retroCols: Column<any>[] = [
    { key: 'decision_label', header: 'Decision', render: (r: any) => String(r.decision_label ?? '') },
    { key: 'status', header: 'Outcome', render: (r: any) => String(r.status ?? '') },
    { key: 'retro_at', header: 'Retro at', render: (r: any) => r.retro_at ? new Date(r.retro_at).toLocaleString() : 'unknown' },
    { key: 'retro_md', header: 'Retro notes', render: (r: any) => String(r.retro_md ?? '').slice(0, 200) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 16 }}>Founder Personal Decision Log</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track personal founder decisions for retro. Log reasoning and alternatives considered. Mark wins, losses, reversed, or active.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Decisions by status</h2>
        <DataTable rows={byStatus} columns={statusCols} rowKey={(r: any, i: number) => String(r.status ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent retros</h2>
        <DataTable rows={retros} columns={retroCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All decisions (latest 200)</h2>
        <DataTable rows={decisions} columns={decisionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
