import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [queue, leaderboard, coaching, kinds] = await Promise.all([
    sb.rpc('epwqa_pending_queue_r2226'),
    sb.rpc('epwqa_engineer_leaderboard_r2226'),
    sb.rpc('epwqa_coaching_feed_r2226'),
    sb.rpc('epwqa_kind_distribution_r2226'),
  ]);

  const queueRows: any[] = (queue.data as any[]) ?? [];
  const leaderRows: any[] = (leaderboard.data as any[]) ?? [];
  const coachRows: any[] = (coaching.data as any[]) ?? [];
  const kindRows: any[] = (kinds.data as any[]) ?? [];

  const queueCols: Column<any>[] = [
    { key: 'submitted_at', header: 'Submitted', render: (r: any) => String(r.submitted_at ?? '').slice(0, 16).replace('T', ' ') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'walkthrough_kind', header: 'Kind', render: (r: any) => String(r.walkthrough_kind ?? '') },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => String(r.equipment_label ?? '') },
    { key: 'photos', header: 'Photos', render: (r: any) => `${r.photo_count ?? 0} / ${r.expected_photo_count ?? 0}` },
    { key: 'coverage_pct', header: 'Coverage', render: (r: any) => `${r.coverage_pct ?? 0}%` },
    { key: 'audit_status', header: 'Status', render: (r: any) => String(r.audit_status ?? '') },
  ];

  const leaderCols: Column<any>[] = [
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'submissions_30d', header: 'Subs 30d', render: (r: any) => String(r.submissions_30d ?? 0) },
    { key: 'rated_30d', header: 'Rated 30d', render: (r: any) => String(r.rated_30d ?? 0) },
    { key: 'avg_clarity', header: 'Clarity', render: (r: any) => String(r.avg_clarity ?? '-') },
    { key: 'avg_completeness', header: 'Complete', render: (r: any) => String(r.avg_completeness ?? '-') },
    { key: 'avg_accuracy', header: 'Accuracy', render: (r: any) => String(r.avg_accuracy ?? '-') },
    { key: 'needs_coaching_count', header: 'Coaching', render: (r: any) => String(r.needs_coaching_count ?? 0) },
    { key: 'rejects_count', header: 'Rejects', render: (r: any) => String(r.rejects_count ?? 0) },
  ];

  const coachCols: Column<any>[] = [
    { key: 'logged_at', header: 'Logged', render: (r: any) => String(r.logged_at ?? '').slice(0, 16).replace('T', ' ') },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => String(r.engineer_email ?? '') },
    { key: 'coach_email', header: 'Coach', render: (r: any) => String(r.coach_email ?? '') },
    { key: 'coaching_theme', header: 'Theme', render: (r: any) => String(r.coaching_theme ?? '') },
    { key: 'coaching_note', header: 'Note', render: (r: any) => String(r.coaching_note ?? '') },
    { key: 'required_followup', header: 'Followup?', render: (r: any) => (r.required_followup ? 'yes' : 'no') },
    { key: 'followup_deadline', header: 'Deadline', render: (r: any) => String(r.followup_deadline ?? '') },
    { key: 'resolved_at', header: 'Resolved', render: (r: any) => String(r.resolved_at ?? '') },
  ];

  const kindCols: Column<any>[] = [
    { key: 'walkthrough_kind', header: 'Kind', render: (r: any) => String(r.walkthrough_kind ?? '') },
    { key: 'total_submissions', header: 'Total', render: (r: any) => String(r.total_submissions ?? 0) },
    { key: 'avg_photos', header: 'Avg Photos', render: (r: any) => String(r.avg_photos ?? '-') },
    { key: 'pct_needs_coaching', header: '% Coaching', render: (r: any) => `${r.pct_needs_coaching ?? 0}%` },
    { key: 'pct_rejected', header: '% Reject', render: (r: any) => `${r.pct_rejected ?? 0}%` },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>
        Engineer Photo Walkthrough — Quality Audit
      </h1>
      <p style={{ color: '#555', marginBottom: 16 }}>
        Pending submissions, engineer leaderboard, coaching log & kind mix.
      </p>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Pending audit queue</h2>
        <DataTable<any> columns={queueCols} rows={queueRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer leaderboard (30d)</h2>
        <DataTable<any> columns={leaderCols} rows={leaderRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Coaching log feed</h2>
        <DataTable<any> columns={coachCols} rows={coachRows} rowKey={(_, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Walkthrough kind distribution</h2>
        <DataTable<any> columns={kindCols} rows={kindRows} rowKey={(_, i) => String(i)} />
      </section>
    </div>
  );
}
