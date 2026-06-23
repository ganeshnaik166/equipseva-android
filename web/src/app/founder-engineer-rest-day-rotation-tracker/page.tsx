import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function EngineerRestDayRotationTrackerPage() {
  const supabase = await getSupabaseServerClient();

  const [
    rotationRes,
    actionsRes,
    topDebtRes,
    wellbeingRes,
    recoveryTrendRes,
    skippedReasonRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_rotation_r2566'),
    supabase.rpc('list_recovery_actions_r2566'),
    supabase.rpc('top_debt_engineers_r2566'),
    supabase.rpc('wellbeing_distribution_r2566'),
    supabase.rpc('recovery_rate_trend_r2566'),
    supabase.rpc('skipped_reason_breakdown_r2566'),
    supabase.rpc('owner_load_r2566'),
  ]);

  const rotation: any[] = rotationRes.data ?? [];
  const actions: any[] = actionsRes.data ?? [];
  const topDebt: any[] = topDebtRes.data ?? [];
  const wellbeing: any[] = wellbeingRes.data ?? [];
  const recoveryTrend: any[] = recoveryTrendRes.data ?? [];
  const skippedReason: any[] = skippedReasonRes.data ?? [];
  const ownerLoad: any[] = ownerLoadRes.data ?? [];

  const rotationCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '-'}</span> },
    { key: 'rest_planned_date', header: 'Planned Date', render: (r: any) => r.rest_planned_date ?? '-' },
    { key: 'rest_actual_taken', header: 'Taken?', render: (r: any) => r.rest_actual_taken ? 'yes' : 'no' },
    { key: 'rest_debt_days', header: 'Debt (days)', render: (r: any) => r.rest_debt_days ?? 0 },
    { key: 'wellbeing_score', header: 'Wellbeing 0-10', render: (r: any) => r.wellbeing_score ?? '-' },
    { key: 'recovery_rate_pct', header: 'Recovery %', render: (r: any) => r.recovery_rate_pct ?? '-' },
    { key: 'top_reason_skipped', header: 'Top Reason Skipped', render: (r: any) => r.top_reason_skipped ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionsCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => r.action_at ? new Date(r.action_at).toLocaleString() : '-' },
    { key: 'rotation_id', header: 'Rotation', render: (r: any) => <span className="font-mono text-xs">{r.rotation_id ? String(r.rotation_id).slice(0, 8) : '-'}</span> },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind ?? '-' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '-' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topDebtCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{r.engineer_user_id ? String(r.engineer_user_id).slice(0, 8) : '-'}</span> },
    { key: 'total_debt_days', header: 'Total Debt Days', render: (r: any) => r.total_debt_days ?? 0 },
    { key: 'skipped_count', header: 'Skipped/Carry Count', render: (r: any) => r.skipped_count ?? 0 },
    { key: 'avg_wellbeing', header: 'Avg Wellbeing', render: (r: any) => r.avg_wellbeing ?? '-' },
  ];

  const wellbeingCols: Column<any>[] = [
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket ?? '-' },
    { key: 'n', header: 'Count', render: (r: any) => r.n ?? 0 },
  ];

  const recoveryTrendCols: Column<any>[] = [
    { key: 'week_start', header: 'Week Start', render: (r: any) => r.week_start ?? '-' },
    { key: 'avg_recovery_pct', header: 'Avg Recovery %', render: (r: any) => r.avg_recovery_pct ?? '-' },
    { key: 'taken_count', header: 'Taken', render: (r: any) => r.taken_count ?? 0 },
    { key: 'skipped_count', header: 'Skipped', render: (r: any) => r.skipped_count ?? 0 },
  ];

  const skippedReasonCols: Column<any>[] = [
    { key: 'top_reason_skipped', header: 'Reason', render: (r: any) => r.top_reason_skipped ?? '-' },
    { key: 'n', header: 'Count', render: (r: any) => r.n ?? 0 },
    { key: 'total_debt', header: 'Total Debt Days', render: (r: any) => r.total_debt ?? 0 },
  ];

  const ownerLoadCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'rotations_owned', header: 'Rotations Owned', render: (r: any) => r.rotations_owned ?? 0 },
    { key: 'actions_open', header: 'Open Actions', render: (r: any) => r.actions_open ?? 0 },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Rest-Day Rotation Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Engineer × planned rest day × actual taken × debt × recovery rate × wellbeing impact.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Debt Engineers</h2>
        <DataTable
          rows={topDebt}
          columns={topDebtCols}
          emptyMessage="No debt data."
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Wellbeing Distribution</h2>
        <DataTable
          rows={wellbeing}
          columns={wellbeingCols}
          emptyMessage="No wellbeing data."
          rowKey={(r: any, i: number) => String(r.bucket ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recovery Rate Trend (weekly)</h2>
        <DataTable
          rows={recoveryTrend}
          columns={recoveryTrendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.week_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Skipped Reason Breakdown</h2>
        <DataTable
          rows={skippedReason}
          columns={skippedReasonCols}
          emptyMessage="No skipped reasons."
          rowKey={(r: any, i: number) => String(r.top_reason_skipped ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerLoadCols}
          emptyMessage="No owner load."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Rotation Log</h2>
        <DataTable
          rows={rotation}
          columns={rotationCols}
          emptyMessage="No rotation entries."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recovery Actions</h2>
        <DataTable
          rows={actions}
          columns={actionsCols}
          emptyMessage="No recovery actions."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
