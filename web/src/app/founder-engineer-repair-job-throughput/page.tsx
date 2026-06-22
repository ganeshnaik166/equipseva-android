import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ThroughputRow = {
  id: string;
  engineer_user_id: string;
  period_label: string;
  total_jobs_completed: number;
  avg_minutes_per_job: number;
  first_time_fix_rate_pct: number;
  status: string;
  captured_at: string;
};

type ActionRow = {
  id: string;
  throughput_id: string;
  action_type: string;
  taken_at: string;
  by_email: string;
  notes_md: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [throughputsRes, topRes, recentActionsRes] = await Promise.all([
    sb.rpc('list_throughputs_r2052'),
    sb.rpc('top_throughput_r2052'),
    sb.rpc('recent_actions_r2052'),
  ]);

  const throughputs: ThroughputRow[] = (throughputsRes.data as ThroughputRow[]) ?? [];
  const top: ThroughputRow[] = (topRes.data as ThroughputRow[]) ?? [];
  const recentActions: ActionRow[] = (recentActionsRes.data as ActionRow[]) ?? [];

  const throughputColumns: Column<ThroughputRow>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'total_jobs_completed', header: 'Jobs Done', render: (r: any) => String(r.total_jobs_completed ?? 0) },
    { key: 'avg_minutes_per_job', header: 'Avg Min/Job', render: (r: any) => String(r.avg_minutes_per_job ?? 0) },
    { key: 'first_time_fix_rate_pct', header: 'First-Time Fix pct', render: (r: any) => `${Number(r.first_time_fix_rate_pct ?? 0).toFixed(2)} pct` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const topColumns: Column<ThroughputRow>[] = [
    { key: 'period_label', header: 'Period', render: (r: any) => String(r.period_label ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
    { key: 'total_jobs_completed', header: 'Jobs', render: (r: any) => String(r.total_jobs_completed ?? 0) },
    { key: 'first_time_fix_rate_pct', header: 'FTF pct', render: (r: any) => `${Number(r.first_time_fix_rate_pct ?? 0).toFixed(2)} pct` },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'throughput_id', header: 'Throughput', render: (r: any) => String(r.throughput_id ?? '').slice(0, 8) },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '') },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
        Engineer Repair Job Throughput
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track jobs completed, average time per job, and first-time fix rate per engineer. Log coaching, training, escalations, recognition, and promotions tied to throughput periods.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          All Throughput Periods ({throughputs.length})
        </h2>
        <DataTable
          rows={throughputs}
          columns={throughputColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Top Throughput (by jobs completed)
        </h2>
        <DataTable
          rows={top}
          columns={topColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent Throughput Actions ({recentActions.length})
        </h2>
        <DataTable
          rows={recentActions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
