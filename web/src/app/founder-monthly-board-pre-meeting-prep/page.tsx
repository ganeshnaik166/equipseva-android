import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [prepRes, outcomesRes, topPrepRes, kindDistRes, funnelRes, trendRes, accuracyRes] = await Promise.all([
    supabase.rpc('list_prep_r2645'),
    supabase.rpc('list_outcomes_r2645'),
    supabase.rpc('top_prep_hours_focus_r2645'),
    supabase.rpc('outcome_kind_distribution_r2645'),
    supabase.rpc('status_funnel_r2645'),
    supabase.rpc('monthly_prep_trend_r2645'),
    supabase.rpc('question_accuracy_summary_r2645'),
  ]);

  const prep = (prepRes.data ?? []) as any[];
  const outcomes = (outcomesRes.data ?? []) as any[];
  const topPrep = (topPrepRes.data ?? []) as any[];
  const kindDist = (kindDistRes.data ?? []) as any[];
  const funnel = (funnelRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const accuracy = (accuracyRes.data ?? []) as any[];

  const prepCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'meeting_at', header: 'Meeting At', render: (r: any) => r.meeting_at ? new Date(r.meeting_at).toLocaleString() : '' },
    { key: 'agenda_md', header: 'Agenda', render: (r: any) => r.agenda_md },
    { key: 'anticipated_questions_md', header: 'Anticipated Qs', render: (r: any) => r.anticipated_questions_md },
    { key: 'our_asks_md', header: 'Our Asks', render: (r: any) => r.our_asks_md },
    { key: 'prep_hours', header: 'Prep Hours', render: (r: any) => String(r.prep_hours ?? 0) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'observed_at', header: 'Observed At', render: (r: any) => r.observed_at ? new Date(r.observed_at).toLocaleString() : '' },
    { key: 'outcome_kind', header: 'Outcome', render: (r: any) => r.outcome_kind },
    { key: 'question_accuracy_pct', header: 'Q Accuracy %', render: (r: any) => String(r.question_accuracy_pct ?? 0) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const topPrepCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'prep_hours', header: 'Prep Hours', render: (r: any) => String(r.prep_hours ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'meeting_at', header: 'Meeting At', render: (r: any) => r.meeting_at ? new Date(r.meeting_at).toLocaleString() : '' },
  ];

  const kindDistCols: Column<any>[] = [
    { key: 'outcome_kind', header: 'Outcome Kind', render: (r: any) => r.outcome_kind },
    { key: 'outcome_count', header: 'Count', render: (r: any) => String(r.outcome_count ?? 0) },
    { key: 'avg_accuracy_pct', header: 'Avg Accuracy %', render: (r: any) => String(r.avg_accuracy_pct ?? 0) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'prep_count', header: 'Prep Count', render: (r: any) => String(r.prep_count ?? 0) },
    { key: 'total_prep_hours', header: 'Total Prep Hours', render: (r: any) => String(r.total_prep_hours ?? 0) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'meeting_at', header: 'Meeting At', render: (r: any) => r.meeting_at ? new Date(r.meeting_at).toLocaleString() : '' },
    { key: 'prep_hours', header: 'Prep Hours', render: (r: any) => String(r.prep_hours ?? 0) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const accuracyCols: Column<any>[] = [
    { key: 'outcomes_logged', header: 'Outcomes Logged', render: (r: any) => String(r.outcomes_logged ?? 0) },
    { key: 'avg_accuracy_pct', header: 'Avg Accuracy %', render: (r: any) => String(r.avg_accuracy_pct ?? 0) },
    { key: 'min_accuracy_pct', header: 'Min %', render: (r: any) => String(r.min_accuracy_pct ?? 0) },
    { key: 'max_accuracy_pct', header: 'Max %', render: (r: any) => String(r.max_accuracy_pct ?? 0) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Founder &gt; Monthly Board Pre-Meeting Prep</h1>
        <p className="text-sm text-gray-600">Track monthly board prep hours, anticipated questions, and post-meeting outcomes.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Prep Sessions</h2>
        <DataTable
          rows={prep}
          columns={prepCols}
          emptyMessage="No prep sessions logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Board Outcomes</h2>
        <DataTable
          rows={outcomes}
          columns={outcomeCols}
          emptyMessage="No outcomes recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Prep-Hours Focus</h2>
        <DataTable
          rows={topPrep}
          columns={topPrepCols}
          emptyMessage="No prep data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Outcome Kind Distribution</h2>
        <DataTable
          rows={kindDist}
          columns={kindDistCols}
          emptyMessage="No outcomes yet."
          rowKey={(r: any, i: number) => String(r.outcome_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No status data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Prep Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Question Accuracy Summary</h2>
        <DataTable
          rows={accuracy}
          columns={accuracyCols}
          emptyMessage="No accuracy data."
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>
    </div>
  );
}
