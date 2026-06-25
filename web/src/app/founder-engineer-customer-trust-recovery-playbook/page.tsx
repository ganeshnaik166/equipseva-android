import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [recoveries, steps, breakKinds, outcomes, statuses, monthly, owners] = await Promise.all([
    supabase.rpc('list_recoveries_r2626'),
    supabase.rpc('list_recovery_steps_r2626'),
    supabase.rpc('top_break_kind_focus_r2626'),
    supabase.rpc('recovery_outcome_distribution_r2626'),
    supabase.rpc('status_funnel_r2626'),
    supabase.rpc('monthly_recovery_trend_r2626'),
    supabase.rpc('owner_load_r2626'),
  ]);

  const recoveryRows = recoveries.data ?? [];
  const stepRows = steps.data ?? [];
  const breakKindRows = breakKinds.data ?? [];
  const outcomeRows = outcomes.data ?? [];
  const statusRows = statuses.data ?? [];
  const monthlyRows = monthly.data ?? [];
  const ownerRows = owners.data ?? [];

  const recoveryCols: Column<any>[] = [
    { key: 'trust_break_at', header: 'Break At', render: (r: any) => new Date(r.trust_break_at).toLocaleString() },
    { key: 'break_kind', header: 'Break Kind', render: (r: any) => r.break_kind },
    { key: 'recovery_outcome', header: 'Outcome', render: (r: any) => r.recovery_outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const stepCols: Column<any>[] = [
    { key: 'step_at', header: 'Step At', render: (r: any) => new Date(r.step_at).toLocaleString() },
    { key: 'step_kind', header: 'Step Kind', render: (r: any) => r.step_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes },
  ];

  const breakKindCols: Column<any>[] = [
    { key: 'break_kind', header: 'Break Kind', render: (r: any) => r.break_kind },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
  ];

  const outcomeCols: Column<any>[] = [
    { key: 'recovery_outcome', header: 'Outcome', render: (r: any) => r.recovery_outcome },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
  ];

  const statusCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
  ];

  const monthlyCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => new Date(r.month_start).toLocaleDateString() },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'restored', header: 'Restored', render: (r: any) => r.restored },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'open_count', header: 'Open', render: (r: any) => r.open_count },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer & Customer Trust Recovery Playbook</h1>
        <p className="text-sm text-gray-600">Track trust breaks > recovery paths > outcomes per engineer-hospital pair.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recoveries</h2>
        <DataTable
          rows={recoveryRows}
          columns={recoveryCols}
          emptyMessage="No recoveries logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recovery Steps</h2>
        <DataTable
          rows={stepRows}
          columns={stepCols}
          emptyMessage="No recovery steps."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Break Kind Focus</h2>
        <DataTable
          rows={breakKindRows}
          columns={breakKindCols}
          emptyMessage="No break kinds."
          rowKey={(r: any, i: number) => String(r.break_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recovery Outcome Distribution</h2>
        <DataTable
          rows={outcomeRows}
          columns={outcomeCols}
          emptyMessage="No outcomes."
          rowKey={(r: any, i: number) => String(r.recovery_outcome ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Funnel</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No statuses."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Recovery Trend</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No monthly data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={ownerRows}
          columns={ownerCols}
          emptyMessage="No owners."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </div>
  );
}
