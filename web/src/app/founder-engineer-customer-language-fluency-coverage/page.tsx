import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [fluency, actions, noCoverage, topCost, distribution, hospitalSummary, weeklyTrend] = await Promise.all([
    supabase.rpc('list_fluency_r2490'),
    supabase.rpc('list_coverage_actions_r2490'),
    supabase.rpc('no_coverage_focus_r2490'),
    supabase.rpc('top_translator_cost_r2490'),
    supabase.rpc('language_distribution_r2490'),
    supabase.rpc('hospital_language_summary_r2490'),
    supabase.rpc('weekly_translator_trend_r2490'),
  ]);

  const fluencyCols: Column<any>[] = [
    { key: 'language_name', header: 'Language', render: (r: any) => r.language_name },
    { key: 'proficiency_level', header: 'Proficiency', render: (r: any) => r.proficiency_level },
    { key: 'gap_kind', header: 'Gap', render: (r: any) => r.gap_kind },
    { key: 'translator_used', header: 'Translator', render: (r: any) => (r.translator_used ? 'yes' : 'no') },
    { key: 'translator_cost_rupees', header: 'Cost (Rs)', render: (r: any) => `Rs ${r.translator_cost_rupees}` },
    { key: 'assessor_email', header: 'Assessor', render: (r: any) => r.assessor_email },
    { key: 'assessed_at', header: 'Assessed', render: (r: any) => new Date(r.assessed_at).toLocaleDateString() },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'language_name', header: 'Language', render: (r: any) => r.language_name },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'action_at', header: 'Started', render: (r: any) => new Date(r.action_at).toLocaleDateString() },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => (r.follow_up_at ? new Date(r.follow_up_at).toLocaleDateString() : '') },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const noCoverageCols: Column<any>[] = [
    { key: 'language_name', header: 'Language', render: (r: any) => r.language_name },
    { key: 'fluency_records', header: 'Records', render: (r: any) => r.fluency_records },
    { key: 'translator_sessions', header: 'Translator sessions', render: (r: any) => r.translator_sessions },
    { key: 'total_translator_cost', header: 'Total cost (Rs)', render: (r: any) => `Rs ${r.total_translator_cost}` },
  ];

  const topCostCols: Column<any>[] = [
    { key: 'language_name', header: 'Language', render: (r: any) => r.language_name },
    { key: 'sessions', header: 'Sessions', render: (r: any) => r.sessions },
    { key: 'total_cost_rupees', header: 'Total (Rs)', render: (r: any) => `Rs ${r.total_cost_rupees}` },
  ];

  const distributionCols: Column<any>[] = [
    { key: 'language_name', header: 'Language', render: (r: any) => r.language_name },
    { key: 'proficiency_level', header: 'Proficiency', render: (r: any) => r.proficiency_level },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => r.engineer_count },
  ];

  const hospitalCols: Column<any>[] = [
    { key: 'hospital_user_id', header: 'Hospital user', render: (r: any) => (r.hospital_user_id ? String(r.hospital_user_id).slice(0, 8) : '(none)') },
    { key: 'gap_kind', header: 'Gap', render: (r: any) => r.gap_kind },
    { key: 'language_count', header: 'Languages', render: (r: any) => r.language_count },
    { key: 'translator_sessions', header: 'Translator sessions', render: (r: any) => r.translator_sessions },
    { key: 'translator_cost', header: 'Cost (Rs)', render: (r: any) => `Rs ${r.translator_cost}` },
  ];

  const trendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week', render: (r: any) => new Date(r.week_start).toLocaleDateString() },
    { key: 'translator_sessions', header: 'Sessions', render: (r: any) => r.translator_sessions },
    { key: 'translator_cost', header: 'Cost (Rs)', render: (r: any) => `Rs ${r.translator_cost}` },
  ];

  return (
    <div className="p-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Engineer & Customer Language Fluency Coverage</h1>
        <p className="text-sm text-gray-600 mt-1">
          Language &gt; engineer &gt; proficiency &gt; hospital &gt; gap & translator usage. Spot no-coverage languages before they bite.
        </p>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">No-coverage focus</h2>
        <DataTable
          rows={noCoverage.data ?? []}
          columns={noCoverageCols}
          emptyMessage="No no-coverage languages flagged."
          rowKey={(r: any, i: number) => String(r.language_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top translator cost by language</h2>
        <DataTable
          rows={topCost.data ?? []}
          columns={topCostCols}
          emptyMessage="No translator costs recorded."
          rowKey={(r: any, i: number) => String(r.language_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Language distribution</h2>
        <DataTable
          rows={distribution.data ?? []}
          columns={distributionCols}
          emptyMessage="No fluency records."
          rowKey={(r: any, i: number) => String((r.language_name ?? '') + '-' + (r.proficiency_level ?? '') + '-' + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospital language summary</h2>
        <DataTable
          rows={hospitalSummary.data ?? []}
          columns={hospitalCols}
          emptyMessage="No hospital-mapped fluency records."
          rowKey={(r: any, i: number) => String((r.hospital_user_id ?? 'none') + '-' + (r.gap_kind ?? '') + '-' + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly translator trend</h2>
        <DataTable
          rows={weeklyTrend.data ?? []}
          columns={trendCols}
          emptyMessage="No weekly trend data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Fluency records</h2>
        <DataTable
          rows={fluency.data ?? []}
          columns={fluencyCols}
          emptyMessage="No fluency records yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Coverage actions</h2>
        <DataTable
          rows={actions.data ?? []}
          columns={actionCols}
          emptyMessage="No coverage actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
