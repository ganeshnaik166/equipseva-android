import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function pct(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return v.toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, uptimeRes, chainRes, modalityRes, criticalRes, intsRes, roiRes] = await Promise.all([
    supabase.rpc('founder_r2819_kpis'),
    supabase.rpc('founder_r2819_uptime_rows'),
    supabase.rpc('founder_r2819_chain_rollup'),
    supabase.rpc('founder_r2819_modality_rollup'),
    supabase.rpc('founder_r2819_critical_centers'),
    supabase.rpc('founder_r2819_interventions'),
    supabase.rpc('founder_r2819_intervention_roi'),
  ]);

  const kpis = (kpisRes.data && kpisRes.data[0]) || {};
  const uptime = uptimeRes.data || [];
  const chains = chainRes.data || [];
  const modalities = modalityRes.data || [];
  const criticals = criticalRes.data || [];
  const interventions = intsRes.data || [];
  const roi = roiRes.data || [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Imaging-Center Equipment Uptime</h1>
        <p className="text-sm text-gray-600">Chain × Center × Modality × Uptime × Revenue impact × Intervention. Track where downtime burns revenue and which fixes pay back.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <Kpi label="Total centers" value={String(kpis.total_centers ?? 0)} />
        <Kpi label="Avg uptime" value={pct(kpis.avg_uptime_pct)} />
        <Kpi label="Critical centers" value={String(kpis.critical_centers ?? 0)} />
        <Kpi label="Revenue loss (Q)" value={rupees(kpis.total_revenue_loss_rupees)} />
        <Kpi label="Downtime hours" value={Number(kpis.total_downtime_hours ?? 0).toFixed(1) + ' h'} />
        <Kpi label="Open interventions" value={String(kpis.open_interventions ?? 0)} />
        <Kpi label="Projected recovery" value={rupees(kpis.projected_recovery_rupees)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Center uptime (sorted: weakest first)</h2>
        <DataTable
          rows={uptime}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'center_name', header: 'Center', render: (r: any) => r.center_name },
            { key: 'city', header: 'City', render: (r: any) => r.city },
            { key: 'modality', header: 'Modality', render: (r: any) => r.modality },
            { key: 'uptime_pct', header: 'Uptime', render: (r: any) => pct(r.uptime_pct) },
            { key: 'downtime_hours', header: 'Downtime h', render: (r: any) => Number(r.downtime_hours).toFixed(1) },
            { key: 'mttr_hours', header: 'MTTR h', render: (r: any) => Number(r.mttr_hours).toFixed(1) },
            { key: 'unplanned_outages', header: 'Outages', render: (r: any) => r.unplanned_outages },
            { key: 'revenue_loss_rupees', header: 'Revenue loss', render: (r: any) => rupees(r.revenue_loss_rupees) },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain rollup</h2>
        <DataTable
          rows={chains}
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'centers', header: 'Centers', render: (r: any) => r.centers },
            { key: 'avg_uptime_pct', header: 'Avg uptime', render: (r: any) => pct(r.avg_uptime_pct) },
            { key: 'total_downtime_hours', header: 'Downtime h', render: (r: any) => Number(r.total_downtime_hours).toFixed(1) },
            { key: 'critical_centers', header: 'Critical', render: (r: any) => r.critical_centers },
            { key: 'total_revenue_loss_rupees', header: 'Revenue loss', render: (r: any) => rupees(r.total_revenue_loss_rupees) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Modality rollup</h2>
        <DataTable
          rows={modalities}
          rowKey={(r: any, i: number) => String(r.modality ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'modality', header: 'Modality', render: (r: any) => r.modality },
            { key: 'centers', header: 'Centers', render: (r: any) => r.centers },
            { key: 'avg_uptime_pct', header: 'Avg uptime', render: (r: any) => pct(r.avg_uptime_pct) },
            { key: 'avg_mttr_hours', header: 'Avg MTTR h', render: (r: any) => Number(r.avg_mttr_hours).toFixed(1) },
            { key: 'total_revenue_loss_rupees', header: 'Revenue loss', render: (r: any) => rupees(r.total_revenue_loss_rupees) },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical & degraded centers</h2>
        <DataTable
          rows={criticals}
          rowKey={(r: any, i: number) => String(r.center_name ?? i)}
          emptyMessage="No critical centers"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'center_name', header: 'Center', render: (r: any) => r.center_name },
            { key: 'modality', header: 'Modality', render: (r: any) => r.modality },
            { key: 'uptime_pct', header: 'Uptime', render: (r: any) => pct(r.uptime_pct) },
            { key: 'mttr_hours', header: 'MTTR h', render: (r: any) => Number(r.mttr_hours).toFixed(1) },
            { key: 'revenue_loss_rupees', header: 'Revenue loss', render: (r: any) => rupees(r.revenue_loss_rupees) },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Interventions</h2>
        <DataTable
          rows={interventions}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No interventions"
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
            { key: 'center_name', header: 'Center', render: (r: any) => r.center_name },
            { key: 'modality', header: 'Modality', render: (r: any) => r.modality },
            { key: 'intervention_type', header: 'Type', render: (r: any) => r.intervention_type },
            { key: 'recommendation', header: 'Recommendation', render: (r: any) => r.recommendation },
            { key: 'owner', header: 'Owner', render: (r: any) => r.owner },
            { key: 'due_date', header: 'Due', render: (r: any) => r.due_date },
            { key: 'projected_uptime_gain_pct', header: 'Uptime gain', render: (r: any) => pct(r.projected_uptime_gain_pct) },
            { key: 'projected_revenue_recovery_rupees', header: 'Recovery', render: (r: any) => rupees(r.projected_revenue_recovery_rupees) },
            { key: 'cost_rupees', header: 'Cost', render: (r: any) => rupees(r.cost_rupees) },
            { key: 'status', header: 'Status', render: (r: any) => r.status },
          ]}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Intervention ROI by type</h2>
        <DataTable
          rows={roi}
          rowKey={(r: any, i: number) => String(r.intervention_type ?? i)}
          emptyMessage="No data"
          columns={[
            { key: 'intervention_type', header: 'Type', render: (r: any) => r.intervention_type },
            { key: 'count', header: 'Count', render: (r: any) => r.count },
            { key: 'total_cost_rupees', header: 'Cost', render: (r: any) => rupees(r.total_cost_rupees) },
            { key: 'total_projected_recovery_rupees', header: 'Recovery', render: (r: any) => rupees(r.total_projected_recovery_rupees) },
            { key: 'roi_multiple', header: 'ROI x', render: (r: any) => r.roi_multiple == null ? '—' : Number(r.roi_multiple).toFixed(2) + 'x' },
          ]}
        />
      </section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border bg-white p-4">
      <div className="text-xs text-gray-500">{label}</div>
      <div className="text-xl font-semibold mt-1">{value}</div>
    </div>
  );
}
