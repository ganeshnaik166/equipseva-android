import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, listRes, regionRes, causeRes, actionsRes, lowRes, statusRes] = await Promise.all([
    supabase.rpc('founder_bench_kpis_r2734'),
    supabase.rpc('founder_bench_list_r2734'),
    supabase.rpc('founder_bench_by_region_r2734'),
    supabase.rpc('founder_bench_by_cause_r2734'),
    supabase.rpc('founder_bench_redeploy_actions_r2734'),
    supabase.rpc('founder_bench_low_util_r2734'),
    supabase.rpc('founder_bench_action_status_r2734'),
  ]);

  const kpis = (kpisRes.data && kpisRes.data[0]) || { total_engineers: 0, total_bench_hours: 0, total_billable_hours: 0, avg_utilization_pct: 0, total_cost_loss_rupees: 0 };
  const list = listRes.data || [];
  const byRegion = regionRes.data || [];
  const byCause = causeRes.data || [];
  const actions = actionsRes.data || [];
  const low = lowRes.data || [];
  const status = statusRes.data || [];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Engineer Monthly Bench Utilization Report</h1>
        <p className="text-sm text-gray-600">Track engineer bench hours, billable utilization, and redeployment actions for the month.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Engineers</div>
          <div className="text-xl font-semibold">{kpis.total_engineers}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Bench Hours</div>
          <div className="text-xl font-semibold">{Number(kpis.total_bench_hours).toFixed(0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Billable Hours</div>
          <div className="text-xl font-semibold">{Number(kpis.total_billable_hours).toFixed(0)}</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Avg Util %</div>
          <div className="text-xl font-semibold">{Number(kpis.avg_utilization_pct).toFixed(1)}%</div>
        </div>
        <div className="border rounded p-4">
          <div className="text-xs text-gray-500">Cost Loss (Rs)</div>
          <div className="text-xl font-semibold">{Number(kpis.total_cost_loss_rupees).toFixed(0)}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Bench Utilization</h2>
        <DataTable
          rows={list}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => <span>{r.engineer_name}</span> },
            { key: 'engineer_code', header: 'Code', render: (r: any) => <span>{r.engineer_code}</span> },
            { key: 'region', header: 'Region', render: (r: any) => <span>{r.region}</span> },
            { key: 'month_label', header: 'Month', render: (r: any) => <span>{r.month_label}</span> },
            { key: 'available_hours', header: 'Avail Hrs', render: (r: any) => <span>{Number(r.available_hours).toFixed(0)}</span> },
            { key: 'billable_hours', header: 'Billable Hrs', render: (r: any) => <span>{Number(r.billable_hours).toFixed(0)}</span> },
            { key: 'bench_hours', header: 'Bench Hrs', render: (r: any) => <span>{Number(r.bench_hours).toFixed(0)}</span> },
            { key: 'utilization_pct', header: 'Util %', render: (r: any) => <span>{Number(r.utilization_pct).toFixed(1)}%</span> },
            { key: 'primary_cause', header: 'Cause', render: (r: any) => <span>{r.primary_cause}</span> },
            { key: 'redeploy_action', header: 'Redeploy', render: (r: any) => <span>{r.redeploy_action}</span> },
            { key: 'redeploy_status', header: 'Status', render: (r: any) => <span>{r.redeploy_status}</span> },
            { key: 'cost_loss_rupees', header: 'Loss (Rs)', render: (r: any) => <span>{Number(r.cost_loss_rupees).toFixed(0)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Region</h2>
        <DataTable
          rows={byRegion}
          columns={[
            { key: 'region', header: 'Region', render: (r: any) => <span>{r.region}</span> },
            { key: 'engineers', header: 'Engineers', render: (r: any) => <span>{r.engineers}</span> },
            { key: 'bench_hours', header: 'Bench Hrs', render: (r: any) => <span>{Number(r.bench_hours).toFixed(0)}</span> },
            { key: 'billable_hours', header: 'Billable Hrs', render: (r: any) => <span>{Number(r.billable_hours).toFixed(0)}</span> },
            { key: 'avg_util', header: 'Avg Util %', render: (r: any) => <span>{Number(r.avg_util).toFixed(1)}%</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.region ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Primary Cause</h2>
        <DataTable
          rows={byCause}
          columns={[
            { key: 'primary_cause', header: 'Cause', render: (r: any) => <span>{r.primary_cause}</span> },
            { key: 'engineers', header: 'Engineers', render: (r: any) => <span>{r.engineers}</span> },
            { key: 'total_bench_hours', header: 'Bench Hrs', render: (r: any) => <span>{Number(r.total_bench_hours).toFixed(0)}</span> },
            { key: 'total_loss', header: 'Loss (Rs)', render: (r: any) => <span>{Number(r.total_loss).toFixed(0)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.primary_cause ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Low Utilization (&lt; 60%)</h2>
        <DataTable
          rows={low}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: any) => <span>{r.engineer_name}</span> },
            { key: 'engineer_code', header: 'Code', render: (r: any) => <span>{r.engineer_code}</span> },
            { key: 'region', header: 'Region', render: (r: any) => <span>{r.region}</span> },
            { key: 'utilization_pct', header: 'Util %', render: (r: any) => <span>{Number(r.utilization_pct).toFixed(1)}%</span> },
            { key: 'bench_hours', header: 'Bench Hrs', render: (r: any) => <span>{Number(r.bench_hours).toFixed(0)}</span> },
            { key: 'redeploy_action', header: 'Redeploy', render: (r: any) => <span>{r.redeploy_action}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Redeploy Actions</h2>
        <DataTable
          rows={actions}
          columns={[
            { key: 'action_label', header: 'Action', render: (r: any) => <span>{r.action_label}</span> },
            { key: 'action_type', header: 'Type', render: (r: any) => <span>{r.action_type}</span> },
            { key: 'owner', header: 'Owner', render: (r: any) => <span>{r.owner}</span> },
            { key: 'target_billable_hours', header: 'Target Hrs', render: (r: any) => <span>{Number(r.target_billable_hours).toFixed(0)}</span> },
            { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
            { key: 'due_date', header: 'Due', render: (r: any) => <span>{r.due_date}</span> },
            { key: 'notes', header: 'Notes', render: (r: any) => <span>{r.notes}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action Status Summary</h2>
        <DataTable
          rows={status}
          columns={[
            { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
            { key: 'action_count', header: 'Count', render: (r: any) => <span>{r.action_count}</span> },
            { key: 'total_target_hours', header: 'Target Hrs', render: (r: any) => <span>{Number(r.total_target_hours).toFixed(0)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>
    </div>
  );
}
