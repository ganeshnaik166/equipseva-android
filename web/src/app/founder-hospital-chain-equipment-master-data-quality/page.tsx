import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function HospitalChainEquipmentMasterDataQualityPage() {
  const supabase = await getSupabaseServerClient();

  const [
    qualityRes,
    actionsRes,
    focusRes,
    gradeRes,
    actionKindRes,
    weeklyRes,
    ownerRes,
  ] = await Promise.all([
    supabase.rpc('list_master_quality_r2523'),
    supabase.rpc('list_cleanup_actions_r2523'),
    supabase.rpc('top_low_quality_focus_r2523'),
    supabase.rpc('grade_distribution_r2523'),
    supabase.rpc('action_kind_summary_r2523'),
    supabase.rpc('weekly_cleanup_trend_r2523'),
    supabase.rpc('owner_load_r2523'),
  ]);

  const quality = (qualityRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const focus = (focusRes.data ?? []) as any[];
  const grade = (gradeRes.data ?? []) as any[];
  const actionKind = (actionKindRes.data ?? []) as any[];
  const weekly = (weeklyRes.data ?? []) as any[];
  const owner = (ownerRes.data ?? []) as any[];

  const qualityCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'completeness_pct', header: 'Complete %', render: (r: any) => `${r.completeness_pct}%` },
    { key: 'quality_grade', header: 'Grade', render: (r: any) => r.quality_grade },
    { key: 'stale_fields_count', header: 'Stale', render: (r: any) => r.stale_fields_count },
    { key: 'duplicate_record_count', header: 'Dupes', render: (r: any) => r.duplicate_record_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
    {
      key: 'last_audit_at',
      header: 'Last Audit',
      render: (r: any) => (r.last_audit_at ? new Date(r.last_audit_at).toLocaleDateString() : '-'),
    },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    {
      key: 'action_at',
      header: 'When',
      render: (r: any) => new Date(r.action_at).toLocaleString(),
    },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const focusCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'completeness_pct', header: 'Complete %', render: (r: any) => `${r.completeness_pct}%` },
    { key: 'quality_grade', header: 'Grade', render: (r: any) => r.quality_grade },
    { key: 'duplicate_record_count', header: 'Dupes', render: (r: any) => r.duplicate_record_count },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const gradeCols: Column<any>[] = [
    { key: 'quality_grade', header: 'Grade', render: (r: any) => r.quality_grade },
    { key: 'record_count', header: 'Records', render: (r: any) => r.record_count },
    { key: 'avg_completeness', header: 'Avg Complete %', render: (r: any) => `${r.avg_completeness}%` },
  ];

  const actionKindCols: Column<any>[] = [
    { key: 'action_kind', header: 'Action Kind', render: (r: any) => r.action_kind },
    { key: 'total_actions', header: 'Total', render: (r: any) => r.total_actions },
    { key: 'positive_outcomes', header: 'Positive', render: (r: any) => r.positive_outcomes },
    { key: 'open_or_in_progress', header: 'Open/WIP', render: (r: any) => r.open_or_in_progress },
  ];

  const weeklyCols: Column<any>[] = [
    {
      key: 'week_start',
      header: 'Week',
      render: (r: any) => new Date(r.week_start).toLocaleDateString(),
    },
    { key: 'actions_taken', header: 'Actions', render: (r: any) => r.actions_taken },
    { key: 'done_count', header: 'Done', render: (r: any) => r.done_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'records_owned', header: 'Records', render: (r: any) => r.records_owned },
    { key: 'avg_completeness', header: 'Avg Complete %', render: (r: any) => `${r.avg_completeness}%` },
    { key: 'open_actions', header: 'Open Actions', render: (r: any) => r.open_actions },
  ];

  return (
    <main className="p-6 space-y-8">
      <div>
        <h1 className="text-2xl font-bold">Hospital Chain Equipment Master Data Quality</h1>
        <p className="text-sm text-gray-600 mt-1">
          Equipment master record completeness, stale fields & duplicate cleanup across hospital chains.
        </p>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Low-Quality Focus (Grade C/D/F or amber/red)</h2>
        <DataTable
          rows={focus}
          columns={focusCols}
          emptyMessage="No low-quality records flagged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Grade Distribution</h2>
        <DataTable
          rows={grade}
          columns={gradeCols}
          emptyMessage="No grade data"
          rowKey={(r: any, i: number) => String(r.quality_grade ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={owner}
          columns={ownerCols}
          emptyMessage="No owners assigned"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cleanup Action Kind Summary</h2>
        <DataTable
          rows={actionKind}
          columns={actionKindCols}
          emptyMessage="No actions yet"
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Weekly Cleanup Trend</h2>
        <DataTable
          rows={weekly}
          columns={weeklyCols}
          emptyMessage="No weekly trend yet"
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Equipment Master Quality Records</h2>
        <DataTable
          rows={quality}
          columns={qualityCols}
          emptyMessage="No quality records"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Cleanup Actions</h2>
        <DataTable
          rows={actions}
          columns={actionsCols}
          emptyMessage="No cleanup actions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
