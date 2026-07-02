import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerPipPage() {
  const sb = await getSupabaseServerClient();

  const [pipsRes, summaryRes, completionsRes] = await Promise.all([
    sb.rpc('list_pips_r1856'),
    sb.rpc('active_pips_summary_r1856'),
    sb.rpc('recent_completions_r1856'),
  ]);

  const pips: any[] = Array.isArray(pipsRes.data) ? pipsRes.data : [];
  const summary: any = Array.isArray(summaryRes.data) ? summaryRes.data[0] : summaryRes.data;
  const completions: any[] = Array.isArray(completionsRes.data) ? completionsRes.data : [];

  const pipCols: Column<any>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? r.engineer_user_id?.slice(0, 8)}</span> },
    { key: 'started', header: 'Started', render: (r: any) => <span>{r.started_on ?? '—'}</span> },
    { key: 'duration', header: 'Days', render: (r: any) => <span>{r.duration_days}</span> },
    { key: 'focus', header: 'Focus', render: (r: any) => <span>{Array.isArray(r.focus_areas) ? r.focus_areas.join(', ') : '—'}</span> },
    { key: 'mentor', header: 'Mentor', render: (r: any) => <span>{r.mentor_email ?? '—'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'checkins', header: 'Check-ins', render: (r: any) => <span>{r.check_in_count ?? 0}</span> },
    { key: 'avg', header: 'Avg score', render: (r: any) => <span>{r.avg_progress != null ? Number(r.avg_progress).toFixed(1) : '—'}</span> },
  ];

  const completionCols: Column<any>[] = [
    { key: 'engineer', header: 'Engineer', render: (r: any) => <span>{r.engineer_email ?? r.engineer_user_id?.slice(0, 8)}</span> },
    { key: 'status', header: 'Outcome', render: (r: any) => <span>{r.status}</span> },
    { key: 'decided', header: 'Decided', render: (r: any) => <span>{r.decided_at ? new Date(r.decided_at).toLocaleDateString() : '—'}</span> },
    { key: 'duration', header: 'Days', render: (r: any) => <span>{r.duration_days}</span> },
    { key: 'focus', header: 'Focus', render: (r: any) => <span>{Array.isArray(r.focus_areas) ? r.focus_areas.join(', ') : '—'}</span> },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Engineer PIP (r1856)</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Performance improvement plans for at-risk engineers. Track focus areas, mentor assignments & check-in cadence.
      </p>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Active summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, minmax(0,1fr))', gap: 12 }}>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Active PIPs</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.active_count ?? 0}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Avg duration (days)</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.avg_duration != null ? Number(summary.avg_duration).toFixed(1) : '—'}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>With mentor</div>
            <div style={{ fontSize: 22, fontWeight: 700 }}>{summary?.with_mentor_count ?? 0}</div>
          </div>
          <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 12, color: '#666' }}>Overdue (past end date)</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: (summary?.overdue_count ?? 0) > 0 ? '#b91c1c' : '#111' }}>{summary?.overdue_count ?? 0}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>All PIPs</h2>
        <DataTable rows={pips} columns={pipCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recent completions</h2>
        <DataTable rows={completions} columns={completionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>RPCs</h2>
        <ul style={{ fontSize: 13, color: '#444', lineHeight: 1.7 }}>
          <li><code>list_pips_r1856()</code> — all PIPs with check-in stats</li>
          <li><code>start_pip_r1856(engineer, days, focus[], targets_md, mentor)</code></li>
          <li><code>list_check_ins_r1856(pip_id)</code></li>
          <li><code>log_check_in_r1856(pip_id, score 1-10, on_track, note_md)</code></li>
          <li><code>complete_pip_r1856(pip_id, status)</code> — passed / failed / voluntary_separation / extended</li>
          <li><code>active_pips_summary_r1856()</code></li>
          <li><code>recent_completions_r1856()</code></li>
        </ul>
      </section>
    </div>
  );
}