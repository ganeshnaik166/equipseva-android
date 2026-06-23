import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerShiftHandoverQualityPage() {
  const supabase = await getSupabaseServerClient();

  const [
    handoversRes,
    bugsRes,
    lowQualityRes,
    bugKindsRes,
    offendersRes,
    weeklyRes,
    kindBreakdownRes,
  ] = await Promise.all([
    supabase.rpc('list_handovers_r2454'),
    supabase.rpc('list_loss_bugs_r2454'),
    supabase.rpc('low_quality_handovers_r2454'),
    supabase.rpc('top_loss_bug_kinds_r2454'),
    supabase.rpc('top_outgoing_offenders_r2454'),
    supabase.rpc('weekly_quality_trend_r2454'),
    supabase.rpc('handover_kind_breakdown_r2454'),
  ]);

  const handovers = (handoversRes.data ?? []) as any[];
  const bugs = (bugsRes.data ?? []) as any[];
  const lowQuality = (lowQualityRes.data ?? []) as any[];
  const bugKinds = (bugKindsRes.data ?? []) as any[];
  const offenders = (offendersRes.data ?? []) as any[];
  const weekly = (weeklyRes.data ?? []) as any[];
  const kindBreakdown = (kindBreakdownRes.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleString() : '—');
  const fmtDay = (v: any) => (v ? new Date(v).toLocaleDateString() : '—');

  const handoverCols: Column<any>[] = [
    { key: 'handover_at', header: 'When', render: (r: any) => fmtDate(r.handover_at) },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'handover_kind', header: 'Kind', render: (r: any) => r.handover_kind },
    { key: 'quality_grade', header: 'Grade', render: (r: any) => r.quality_grade },
    { key: 'handover_completeness_pct', header: 'Complete %', render: (r: any) => `${r.handover_completeness_pct}%` },
    { key: 'time_spent_minutes', header: 'Time (min)', render: (r: any) => r.time_spent_minutes },
    { key: 'next_shift_issues_count', header: 'Next-shift issues', render: (r: any) => r.next_shift_issues_count },
    { key: 'loss_of_context_bug_count', header: 'Loss bugs', render: (r: any) => r.loss_of_context_bug_count },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '—' },
  ];

  const bugCols: Column<any>[] = [
    { key: 'discovered_at', header: 'Discovered', render: (r: any) => fmtDate(r.discovered_at) },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'bug_kind', header: 'Kind', render: (r: any) => r.bug_kind },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'root_cause_md', header: 'Root cause', render: (r: any) => r.root_cause_md ?? '—' },
    { key: 'corrective_action_md', header: 'Corrective action', render: (r: any) => r.corrective_action_md ?? '—' },
    { key: 'closed_at', header: 'Closed', render: (r: any) => fmtDate(r.closed_at) },
    { key: 'closed_by_email', header: 'Closed by', render: (r: any) => r.closed_by_email ?? '—' },
  ];

  const lowQualityCols: Column<any>[] = [
    { key: 'handover_at', header: 'When', render: (r: any) => fmtDate(r.handover_at) },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'quality_grade', header: 'Grade', render: (r: any) => r.quality_grade },
    { key: 'handover_completeness_pct', header: 'Complete %', render: (r: any) => `${r.handover_completeness_pct}%` },
    { key: 'next_shift_issues_count', header: 'Next-shift issues', render: (r: any) => r.next_shift_issues_count },
    { key: 'loss_of_context_bug_count', header: 'Loss bugs', render: (r: any) => r.loss_of_context_bug_count },
  ];

  const bugKindCols: Column<any>[] = [
    { key: 'bug_kind', header: 'Bug kind', render: (r: any) => r.bug_kind },
    { key: 'bug_count', header: 'Count', render: (r: any) => r.bug_count },
    { key: 'critical_count', header: 'Critical', render: (r: any) => r.critical_count },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
  ];

  const offenderCols: Column<any>[] = [
    { key: 'outgoing_email', header: 'Outgoing engineer', render: (r: any) => r.outgoing_email ?? '—' },
    { key: 'handover_count', header: 'Handovers', render: (r: any) => r.handover_count },
    { key: 'avg_completeness_pct', header: 'Avg complete %', render: (r: any) => `${r.avg_completeness_pct ?? 0}%` },
    { key: 'total_loss_bugs', header: 'Total loss bugs', render: (r: any) => r.total_loss_bugs },
    { key: 'poor_grade_count', header: 'D/F grades', render: (r: any) => r.poor_grade_count },
  ];

  const weeklyCols: Column<any>[] = [
    { key: 'week_start', header: 'Week start', render: (r: any) => fmtDay(r.week_start) },
    { key: 'handover_count', header: 'Handovers', render: (r: any) => r.handover_count },
    { key: 'avg_completeness_pct', header: 'Avg complete %', render: (r: any) => `${r.avg_completeness_pct ?? 0}%` },
    { key: 'total_next_shift_issues', header: 'Next-shift issues', render: (r: any) => r.total_next_shift_issues },
    { key: 'total_loss_bugs', header: 'Loss bugs', render: (r: any) => r.total_loss_bugs },
  ];

  const kindCols: Column<any>[] = [
    { key: 'handover_kind', header: 'Handover kind', render: (r: any) => r.handover_kind },
    { key: 'handover_count', header: 'Count', render: (r: any) => r.handover_count },
    { key: 'avg_completeness_pct', header: 'Avg complete %', render: (r: any) => `${r.avg_completeness_pct ?? 0}%` },
    { key: 'avg_time_spent_minutes', header: 'Avg time (min)', render: (r: any) => r.avg_time_spent_minutes ?? 0 },
    { key: 'total_loss_bugs', header: 'Loss bugs', render: (r: any) => r.total_loss_bugs },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-10 px-6 py-10">
      <header className="space-y-2">
        <h1 className="text-3xl font-semibold">Engineer Shift Handover Quality</h1>
        <p className="text-sm text-gray-600">
          Handover completeness, time spent, next-shift issues & loss-of-context bugs — r2454.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Recent handovers</h2>
        <DataTable
          rows={handovers}
          columns={handoverCols}
          emptyMessage="No handovers logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Low-quality handovers (grade C/D/F or <70%)</h2>
        <DataTable
          rows={lowQuality}
          columns={lowQualityCols}
          emptyMessage="No low-quality handovers."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Loss-of-context bugs</h2>
        <DataTable
          rows={bugs}
          columns={bugCols}
          emptyMessage="No loss bugs reported."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Top loss-bug kinds</h2>
        <DataTable
          rows={bugKinds}
          columns={bugKindCols}
          emptyMessage="No bug-kind data."
          rowKey={(r: any, i: number) => String(r.bug_kind ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Top outgoing offenders</h2>
        <DataTable
          rows={offenders}
          columns={offenderCols}
          emptyMessage="No outgoing-engineer data."
          rowKey={(r: any, i: number) => String(r.outgoing_engineer_user_id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Weekly quality trend</h2>
        <DataTable
          rows={weekly}
          columns={weeklyCols}
          emptyMessage="No weekly trend yet."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-xl font-semibold">Handover-kind breakdown</h2>
        <DataTable
          rows={kindBreakdown}
          columns={kindCols}
          emptyMessage="No handover-kind data."
          rowKey={(r: any, i: number) => String(r.handover_kind ?? i)}
        />
      </section>
    </main>
  );
}
