import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [iterationsRes, feedbackRes, objectionsRes, recentRes] = await Promise.all([
    sb.rpc('list_pitch_iterations_r1921', { p_limit: 100 }),
    sb.rpc('list_pitch_feedback_r1921', { p_limit: 100 }),
    sb.rpc('top_pitch_objections_r1921', { p_limit: 20 }),
    sb.rpc('recent_pitch_feedback_r1921', { p_days: 30, p_limit: 50 }),
  ]);

  const iterations: any[] = (iterationsRes.data as any[]) ?? [];
  const feedback: any[] = (feedbackRes.data as any[]) ?? [];
  const objections: any[] = (objectionsRes.data as any[]) ?? [];
  const recent: any[] = (recentRes.data as any[]) ?? [];

  const iterationCols: Column<any>[] = [
    { key: 'version_label', header: 'Version', render: (r: any) => String(r.version_label ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'pitched_to_md', header: 'Pitched To', render: (r: any) => String(r.pitched_to_md ?? '').slice(0, 80) },
    { key: 'feedback_summary_md', header: 'Summary', render: (r: any) => String(r.feedback_summary_md ?? '').slice(0, 80) },
    { key: 'drafted_at', header: 'Drafted', render: (r: any) => r.drafted_at ? new Date(r.drafted_at).toLocaleDateString() : '' },
    { key: 'last_pitched_at', header: 'Last Pitched', render: (r: any) => r.last_pitched_at ? new Date(r.last_pitched_at).toLocaleDateString() : '' },
    { key: 'feedback_count', header: 'Feedback', render: (r: any) => String(r.feedback_count ?? 0) },
  ];

  const feedbackCols: Column<any>[] = [
    { key: 'version_label', header: 'Version', render: (r: any) => String(r.version_label ?? '') },
    { key: 'feedback_type', header: 'Type', render: (r: any) => String(r.feedback_type ?? '') },
    { key: 'feedback_md', header: 'Feedback', render: (r: any) => String(r.feedback_md ?? '').slice(0, 120) },
    { key: 'by_investor_email', header: 'Investor', render: (r: any) => String(r.by_investor_email ?? '') },
    { key: 'received_at', header: 'Received', render: (r: any) => r.received_at ? new Date(r.received_at).toLocaleDateString() : '' },
  ];

  const objectionCols: Column<any>[] = [
    { key: 'feedback_type', header: 'Type', render: (r: any) => String(r.feedback_type ?? '') },
    { key: 'occurrences', header: 'Occurrences', render: (r: any) => String(r.occurrences ?? 0) },
    { key: 'last_received', header: 'Last Received', render: (r: any) => r.last_received ? new Date(r.last_received).toLocaleDateString() : '' },
    { key: 'sample_md', header: 'Sample', render: (r: any) => String(r.sample_md ?? '').slice(0, 120) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'received_at', header: 'When', render: (r: any) => r.received_at ? new Date(r.received_at).toLocaleString() : '' },
    { key: 'version_label', header: 'Version', render: (r: any) => String(r.version_label ?? '') },
    { key: 'feedback_type', header: 'Type', render: (r: any) => String(r.feedback_type ?? '') },
    { key: 'feedback_md', header: 'Feedback', render: (r: any) => String(r.feedback_md ?? '').slice(0, 140) },
    { key: 'by_investor_email', header: 'Investor', render: (r: any) => String(r.by_investor_email ?? '') },
  ];

  const draftCount = iterations.filter((r) => r.status === 'draft').length;
  const usedCount = iterations.filter((r) => r.status === 'used_in_meeting').length;
  const archivedCount = iterations.filter((r) => r.status === 'archived').length;
  const objectionTotal = objections.reduce((sum: number, r: any) => sum + Number(r.occurrences ?? 0), 0);

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Investor Pitch Iteration Log</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track pitch deck versions and the feedback received from each investor meeting.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 32 }}>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Iterations</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{iterations.length}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Drafts</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{draftCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Used In Meeting</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{usedCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Archived</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{archivedCount}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e7eb', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Objections and Concerns</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{objectionTotal}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Pitch Deck Iterations</h2>
        <DataTable rows={iterations} columns={iterationCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Top Objections and Concerns</h2>
        <DataTable rows={objections} columns={objectionCols} rowKey={(r: any, i: number) => String(r.feedback_type ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Recent Feedback (last 30 days)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Logged Feedback</h2>
        <DataTable rows={feedback} columns={feedbackCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
