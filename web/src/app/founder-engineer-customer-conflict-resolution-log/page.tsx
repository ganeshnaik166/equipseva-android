import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [conflicts, followups, severity, kindBreakdown, outcomeDist, monthly, lessons] = await Promise.all([
    supabase.rpc('list_conflicts_r2582'),
    supabase.rpc('list_repair_followups_r2582'),
    supabase.rpc('top_severity_focus_r2582'),
    supabase.rpc('conflict_kind_breakdown_r2582'),
    supabase.rpc('outcome_distribution_r2582'),
    supabase.rpc('monthly_conflict_trend_r2582'),
    supabase.rpc('lessons_summary_r2582'),
  ]);

  const conflictCols: Column<any>[] = [
    { key: 'conflict_at', header: 'When', render: (r: any) => r.conflict_at ? new Date(r.conflict_at).toLocaleDateString() : '' },
    { key: 'conflict_kind', header: 'Kind', render: (r: any) => r.conflict_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const followupCols: Column<any>[] = [
    { key: 'followup_at', header: 'When', render: (r: any) => r.followup_at ? new Date(r.followup_at).toLocaleDateString() : '' },
    { key: 'followup_kind', header: 'Kind', render: (r: any) => r.followup_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const severityCols: Column<any>[] = [
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'conflict_count', header: 'Total', render: (r: any) => r.conflict_count },
    { key: 'open_count', header: 'Open / In-progress', render: (r: any) => r.open_count },
    { key: 'resolved_count', header: 'Resolved', render: (r: any) => r.resolved_count },
  ];

  const kindCols: Column<any>[] = [
    { key: 'conflict_kind', header: 'Kind', render: (r: any) => r.conflict_kind },
    { key: 'conflict_count', header: 'Count', render: (r: any) => r.conflict_count },
    { key: 'critical_or_high', header: 'Critical or High', render: (r: any) => r.critical_or_high },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'conflict_count', header: 'Count', render: (r: any) => r.conflict_count },
    { key: 'share_pct', header: 'Share %', render: (r: any) => r.share_pct },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => r.month_start ? new Date(r.month_start).toLocaleDateString() : '' },
    { key: 'conflict_count', header: 'Conflicts', render: (r: any) => r.conflict_count },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count },
    { key: 'resolved_count', header: 'Resolved', render: (r: any) => r.resolved_count },
  ];

  const lessonsCols: Column<any>[] = [
    { key: 'conflict_at', header: 'When', render: (r: any) => r.conflict_at ? new Date(r.conflict_at).toLocaleDateString() : '' },
    { key: 'conflict_kind', header: 'Kind', render: (r: any) => r.conflict_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'lesson_md', header: 'Lesson', render: (r: any) => r.lesson_md ?? '' },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1>Engineer & Customer Conflict Resolution Log</h1>
      <p style={{ color: '#666' }}>Track conflicts, resolution paths, outcomes, repair followups, and durable lessons.</p>

      <section style={{ marginTop: 24 }}>
        <h2>Severity focus</h2>
        <DataTable
          rows={(severity.data as any[]) ?? []}
          columns={severityCols}
          emptyMessage="No severity data."
          rowKey={(r: any, i: number) => String(r.severity ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Conflict kind breakdown</h2>
        <DataTable
          rows={(kindBreakdown.data as any[]) ?? []}
          columns={kindCols}
          emptyMessage="No kind data."
          rowKey={(r: any, i: number) => String(r.conflict_kind ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Outcome distribution</h2>
        <DataTable
          rows={(outcomeDist.data as any[]) ?? []}
          columns={outcomeCols}
          emptyMessage="No outcome data."
          rowKey={(r: any, i: number) => String(r.outcome_kind ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Monthly trend</h2>
        <DataTable
          rows={(monthly.data as any[]) ?? []}
          columns={monthlyCols}
          emptyMessage="No monthly trend."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Conflicts</h2>
        <DataTable
          rows={(conflicts.data as any[]) ?? []}
          columns={conflictCols}
          emptyMessage="No conflicts logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Repair followups</h2>
        <DataTable
          rows={(followups.data as any[]) ?? []}
          columns={followupCols}
          emptyMessage="No followups."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Lessons archive</h2>
        <DataTable
          rows={(lessons.data as any[]) ?? []}
          columns={lessonsCols}
          emptyMessage="No lessons captured."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
