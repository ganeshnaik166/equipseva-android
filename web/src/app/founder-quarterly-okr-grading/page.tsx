import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderQuarterlyOkrGradingPage() {
  const supabase = await getSupabaseServerClient();

  const [okrsRes, sessionsRes, statusRes, gradeRes, carryRes, missesRes, trendRes] = await Promise.all([
    supabase.rpc('list_okrs_r2457'),
    supabase.rpc('list_grading_sessions_r2457'),
    supabase.rpc('status_breakdown_r2457'),
    supabase.rpc('grade_distribution_r2457'),
    supabase.rpc('carryover_summary_r2457'),
    supabase.rpc('top_misses_r2457'),
    supabase.rpc('quarterly_trend_r2457'),
  ]);

  const okrs = (okrsRes.data ?? []) as any[];
  const sessions = (sessionsRes.data ?? []) as any[];
  const statusBreakdown = (statusRes.data ?? []) as any[];
  const gradeDist = (gradeRes.data ?? []) as any[];
  const carryover = (carryRes.data ?? []) as any[];
  const misses = (missesRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];

  const okrCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'okr_name', header: 'OKR', render: (r: any) => r.okr_name },
    { key: 'kr_text', header: 'Key Result', render: (r: any) => r.kr_text },
    { key: 'target', header: 'Target', render: (r: any) => `${r.target_value} ${r.target_unit}` },
    { key: 'actual', header: 'Actual', render: (r: any) => `${r.actual_value} ${r.target_unit}` },
    { key: 'grade', header: 'Grade', render: (r: any) => r.grade },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'carryover', header: 'Carryover', render: (r: any) => (r.carryover ? 'yes' : 'no') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
  ];

  const sessionCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'graded_at', header: 'Graded at', render: (r: any) => new Date(r.graded_at).toLocaleString() },
    { key: 'graded_by_email', header: 'Graded by', render: (r: any) => r.graded_by_email },
    { key: 'okr_count', header: 'OKRs', render: (r: any) => r.okr_count },
    { key: 'avg_grade', header: 'Avg grade', render: (r: any) => r.avg_grade },
    { key: 'top_win', header: 'Top win', render: (r: any) => r.top_win },
    { key: 'top_miss', header: 'Top miss', render: (r: any) => r.top_miss },
    { key: 'carryover_count', header: 'Carryover', render: (r: any) => r.carryover_count },
    { key: 'next_quarter_focus_md', header: 'Next quarter focus', render: (r: any) => r.next_quarter_focus_md },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'okr_count', header: 'OKR count', render: (r: any) => r.okr_count },
  ];

  const gradeCols: Column<any>[] = [
    { key: 'grade', header: 'Grade', render: (r: any) => r.grade },
    { key: 'okr_count', header: 'OKR count', render: (r: any) => r.okr_count },
  ];

  const carryoverCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'carryover_count', header: 'Carryover OKRs', render: (r: any) => r.carryover_count },
    { key: 'total_okrs', header: 'Total OKRs', render: (r: any) => r.total_okrs },
  ];

  const missesCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'okr_name', header: 'OKR', render: (r: any) => r.okr_name },
    { key: 'kr_text', header: 'Key result', render: (r: any) => r.kr_text },
    { key: 'target_value', header: 'Target', render: (r: any) => r.target_value },
    { key: 'actual_value', header: 'Actual', render: (r: any) => r.actual_value },
    { key: 'grade', header: 'Grade', render: (r: any) => r.grade },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'avg_grade', header: 'Avg grade', render: (r: any) => r.avg_grade },
    { key: 'okr_count', header: 'OKR count', render: (r: any) => r.okr_count },
    { key: 'carryover_count', header: 'Carryover count', render: (r: any) => r.carryover_count },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder Quarterly OKR Grading</h1>
        <p className="text-sm text-gray-600">
          Quarter &gt; OKR &gt; target & actual &gt; grade &gt; lessons &gt; next-quarter carryover.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">OKRs</h2>
        <DataTable
          rows={okrs}
          columns={okrCols}
          emptyMessage="No OKRs graded yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Grading sessions</h2>
        <DataTable
          rows={sessions}
          columns={sessionCols}
          emptyMessage="No grading sessions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status breakdown</h2>
        <DataTable
          rows={statusBreakdown}
          columns={statusCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Grade distribution</h2>
        <DataTable
          rows={gradeDist}
          columns={gradeCols}
          emptyMessage="No grade data."
          rowKey={(r: any, i: number) => String(r.grade ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Carryover summary</h2>
        <DataTable
          rows={carryover}
          columns={carryoverCols}
          emptyMessage="No carryover data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top misses</h2>
        <DataTable
          rows={misses}
          columns={missesCols}
          emptyMessage="No missed or at-risk OKRs."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>
    </div>
  );
}
