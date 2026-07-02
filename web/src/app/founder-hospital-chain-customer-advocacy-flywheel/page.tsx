import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function rupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return '₹' + Number(n).toLocaleString('en-IN');
}

function dt(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return String(s);
  }
}

function monthLabel(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleDateString('en-IN', { year: 'numeric', month: 'short' });
  } catch {
    return String(s);
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [advocates, activities, topScore, kindSummary, lapsed, bonusPipe, monthly] = await Promise.all([
    supabase.rpc('list_advocates_r2495'),
    supabase.rpc('list_activities_r2495'),
    supabase.rpc('top_score_advocates_r2495'),
    supabase.rpc('activity_kind_summary_r2495'),
    supabase.rpc('lapsed_focus_r2495'),
    supabase.rpc('bonus_pipeline_r2495'),
    supabase.rpc('monthly_activity_trend_r2495'),
  ]);

  const advocateRows: any[] = advocates.data ?? [];
  const activityRows: any[] = activities.data ?? [];
  const topRows: any[] = topScore.data ?? [];
  const kindRows: any[] = kindSummary.data ?? [];
  const lapsedRows: any[] = lapsed.data ?? [];
  const bonusRows: any[] = bonusPipe.data ?? [];
  const monthlyRows: any[] = monthly.data ?? [];

  const advocateCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'advocate_name', header: 'Advocate', render: (r: any) => r.advocate_name },
    { key: 'advocate_email', header: 'Email', render: (r: any) => r.advocate_email },
    { key: 'advocate_score', header: 'Score', render: (r: any) => `${r.advocate_score}/100` },
    { key: 'referrals_made', header: 'Refs', render: (r: any) => r.referrals_made },
    { key: 'case_studies_count', header: 'Cases', render: (r: any) => r.case_studies_count },
    { key: 'linkedin_posts_count', header: 'LinkedIn', render: (r: any) => r.linkedin_posts_count },
    { key: 'conference_talks_count', header: 'Talks', render: (r: any) => r.conference_talks_count },
    { key: 'total_bonus_rupees', header: 'Bonus Paid', render: (r: any) => rupees(r.total_bonus_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'last_activity_at', header: 'Last Activity', render: (r: any) => dt(r.last_activity_at) },
  ];

  const activityCols: Column<any>[] = [
    { key: 'activity_at', header: 'When', render: (r: any) => dt(r.activity_at) },
    { key: 'advocate_name', header: 'Advocate', render: (r: any) => r.advocate_name },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'activity_kind', header: 'Kind', render: (r: any) => r.activity_kind },
    { key: 'value_estimate_rupees', header: 'Value', render: (r: any) => rupees(r.value_estimate_rupees) },
    { key: 'bonus_paid_rupees', header: 'Bonus', render: (r: any) => rupees(r.bonus_paid_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const topCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'advocate_name', header: 'Advocate', render: (r: any) => r.advocate_name },
    { key: 'advocate_score', header: 'Score', render: (r: any) => `${r.advocate_score}/100` },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'total_bonus_rupees', header: 'Bonus Paid', render: (r: any) => rupees(r.total_bonus_rupees) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'activity_kind', header: 'Kind', render: (r: any) => r.activity_kind },
    { key: 'activity_count', header: 'Total', render: (r: any) => r.activity_count },
    { key: 'completed_count', header: 'Completed', render: (r: any) => r.completed_count },
    { key: 'total_value_rupees', header: 'Value', render: (r: any) => rupees(r.total_value_rupees) },
    { key: 'total_bonus_rupees', header: 'Bonus', render: (r: any) => rupees(r.total_bonus_rupees) },
  ];

  const lapsedCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'advocate_name', header: 'Advocate', render: (r: any) => r.advocate_name },
    { key: 'advocate_email', header: 'Email', render: (r: any) => r.advocate_email },
    { key: 'advocate_score', header: 'Score', render: (r: any) => `${r.advocate_score}/100` },
    { key: 'last_activity_at', header: 'Last', render: (r: any) => dt(r.last_activity_at) },
    { key: 'days_since_activity', header: 'Days Quiet', render: (r: any) => r.days_since_activity },
  ];

  const bonusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'activity_count', header: 'Count', render: (r: any) => r.activity_count },
    { key: 'bonus_paid_rupees', header: 'Bonus Paid', render: (r: any) => rupees(r.bonus_paid_rupees) },
    { key: 'value_estimate_rupees', header: 'Value', render: (r: any) => rupees(r.value_estimate_rupees) },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => monthLabel(r.month_start) },
    { key: 'activity_count', header: 'Activities', render: (r: any) => r.activity_count },
    { key: 'completed_count', header: 'Completed', render: (r: any) => r.completed_count },
    { key: 'bonus_paid_rupees', header: 'Bonus', render: (r: any) => rupees(r.bonus_paid_rupees) },
    { key: 'value_estimate_rupees', header: 'Value', render: (r: any) => rupees(r.value_estimate_rupees) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Customer Advocacy Flywheel</h1>
        <p className="text-sm text-gray-600 mt-1">
          Chain × advocate score × referrals & case studies × LinkedIn & conferences => bonus pipeline.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Score Advocates</h2>
        <DataTable
          rows={topRows}
          columns={topCols}
          emptyMessage="No advocates yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Advocates</h2>
        <DataTable
          rows={advocateRows}
          columns={advocateCols}
          emptyMessage="No advocates yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Activities</h2>
        <DataTable
          rows={activityRows}
          columns={activityCols}
          emptyMessage="No activities yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Activity Kind Summary</h2>
        <DataTable
          rows={kindRows}
          columns={kindCols}
          emptyMessage="No activity"
          rowKey={(r: any, i: number) => String(r.activity_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Lapsed Focus (re-engage)</h2>
        <DataTable
          rows={lapsedRows}
          columns={lapsedCols}
          emptyMessage="None lapsed"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Bonus Pipeline</h2>
        <DataTable
          rows={bonusRows}
          columns={bonusCols}
          emptyMessage="No bonus rows"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Activity Trend</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No trend yet"
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>
    </div>
  );
}
