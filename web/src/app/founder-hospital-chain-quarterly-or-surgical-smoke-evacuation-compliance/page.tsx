import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { chain_name: string; audits: number; pass_rate: number; total_fine_exposure: number; avg_compliance: number };
type FailRow = { id: string; chain_name: string; hospital_code: string; or_room_label: string; capture_velocity_fpm: number; decibel_level: number; fine_exposure_rupees: number };
type OverdueRow = { id: string; chain_name: string; hospital_code: string; or_room_label: string; evacuator_model: string; hours_over: number };
type RemediationRow = { id: string; chain_name: string; hospital_code: string; or_room_label: string; action_type: string; severity: string; cost_rupees: number; owner_engineer_email: string };
type ModelRow = { evacuator_model: string; units: number; avg_velocity: number; avg_compliance: number; fail_count: number };
type CityRow = { city: string; audits: number; fails: number; marginal: number; total_exposure: number };
type EngineerRow = { owner_engineer_email: string; open_jobs: number; closed_jobs: number; total_cost: number };
type KpiRow = { total_audits: number; fail_count: number; marginal_count: number; pass_count: number; total_fine_exposure: number; open_actions: number; total_remediation_cost: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [kpiRes, chainRes, failRes, overdueRes, remRes, modelRes, cityRes, engRes] = await Promise.all([
    sb.rpc('r2919_kpi_summary'),
    sb.rpc('r2919_chain_summary'),
    sb.rpc('r2919_failing_rooms'),
    sb.rpc('r2919_filter_overdue'),
    sb.rpc('r2919_open_remediation'),
    sb.rpc('r2919_model_breakdown'),
    sb.rpc('r2919_city_heatmap'),
    sb.rpc('r2919_engineer_workload'),
  ]);

  const kpi: KpiRow | null = (kpiRes.data?.[0] as KpiRow) ?? null;
  const chains: ChainRow[] = (chainRes.data as ChainRow[]) ?? [];
  const fails: FailRow[] = (failRes.data as FailRow[]) ?? [];
  const overdue: OverdueRow[] = (overdueRes.data as OverdueRow[]) ?? [];
  const remediation: RemediationRow[] = (remRes.data as RemediationRow[]) ?? [];
  const models: ModelRow[] = (modelRes.data as ModelRow[]) ?? [];
  const cities: CityRow[] = (cityRes.data as CityRow[]) ?? [];
  const engineers: EngineerRow[] = (engRes.data as EngineerRow[]) ?? [];

  const chainCols: Column<ChainRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'audits', header: 'Audits', render: (r) => r.audits },
    { key: 'pass_rate', header: 'Pass %', render: (r) => `${r.pass_rate}%` },
    { key: 'avg_compliance', header: 'Avg Compliance', render: (r) => `${r.avg_compliance}%` },
    { key: 'total_fine_exposure', header: 'Fine Exposure', render: (r) => `Rs ${Number(r.total_fine_exposure).toLocaleString('en-IN')}` },
  ];

  const failCols: Column<FailRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_code', header: 'Hospital', render: (r) => r.hospital_code },
    { key: 'or_room_label', header: 'OR Room', render: (r) => r.or_room_label },
    { key: 'capture_velocity_fpm', header: 'Velocity (fpm)', render: (r) => r.capture_velocity_fpm },
    { key: 'decibel_level', header: 'dB', render: (r) => r.decibel_level },
    { key: 'fine_exposure_rupees', header: 'Fine Rs', render: (r) => Number(r.fine_exposure_rupees).toLocaleString('en-IN') },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_code', header: 'Hospital', render: (r) => r.hospital_code },
    { key: 'or_room_label', header: 'OR Room', render: (r) => r.or_room_label },
    { key: 'evacuator_model', header: 'Model', render: (r) => r.evacuator_model },
    { key: 'hours_over', header: 'Hours Over Life', render: (r) => r.hours_over },
  ];

  const remCols: Column<RemediationRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'hospital_code', header: 'Hospital', render: (r) => r.hospital_code },
    { key: 'or_room_label', header: 'OR Room', render: (r) => r.or_room_label },
    { key: 'action_type', header: 'Action', render: (r) => r.action_type },
    { key: 'severity', header: 'Sev', render: (r) => r.severity },
    { key: 'cost_rupees', header: 'Cost Rs', render: (r) => Number(r.cost_rupees).toLocaleString('en-IN') },
    { key: 'owner_engineer_email', header: 'Owner', render: (r) => r.owner_engineer_email },
  ];

  const modelCols: Column<ModelRow>[] = [
    { key: 'evacuator_model', header: 'Model', render: (r) => r.evacuator_model },
    { key: 'units', header: 'Units', render: (r) => r.units },
    { key: 'avg_velocity', header: 'Avg Velocity', render: (r) => r.avg_velocity },
    { key: 'avg_compliance', header: 'Avg Compliance %', render: (r) => `${r.avg_compliance}%` },
    { key: 'fail_count', header: 'Fails', render: (r) => r.fail_count },
  ];

  const cityCols: Column<CityRow>[] = [
    { key: 'city', header: 'City', render: (r) => r.city },
    { key: 'audits', header: 'Audits', render: (r) => r.audits },
    { key: 'fails', header: 'Fails', render: (r) => r.fails },
    { key: 'marginal', header: 'Marginal', render: (r) => r.marginal },
    { key: 'total_exposure', header: 'Fine Exposure Rs', render: (r) => Number(r.total_exposure).toLocaleString('en-IN') },
  ];

  const engCols: Column<EngineerRow>[] = [
    { key: 'owner_engineer_email', header: 'Engineer', render: (r) => r.owner_engineer_email },
    { key: 'open_jobs', header: 'Open', render: (r) => r.open_jobs },
    { key: 'closed_jobs', header: 'Closed', render: (r) => r.closed_jobs },
    { key: 'total_cost', header: 'Total Cost Rs', render: (r) => Number(r.total_cost).toLocaleString('en-IN') },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly OR Surgical Smoke Evacuation Compliance</h1>
        <p className="text-sm text-gray-600">Q2-2026 audits across multi-hospital chains — capture velocity, filter life, surgeon compliance & remediation pipeline.</p>
      </header>

      {kpi && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="rounded-lg border p-4"><div className="text-xs text-gray-500">Total Audits</div><div className="text-2xl font-bold">{kpi.total_audits}</div></div>
          <div className="rounded-lg border p-4"><div className="text-xs text-gray-500">Failing Rooms</div><div className="text-2xl font-bold text-red-600">{kpi.fail_count}</div></div>
          <div className="rounded-lg border p-4"><div className="text-xs text-gray-500">Marginal</div><div className="text-2xl font-bold text-amber-600">{kpi.marginal_count}</div></div>
          <div className="rounded-lg border p-4"><div className="text-xs text-gray-500">Passing</div><div className="text-2xl font-bold text-green-600">{kpi.pass_count}</div></div>
          <div className="rounded-lg border p-4"><div className="text-xs text-gray-500">Fine Exposure</div><div className="text-2xl font-bold">Rs {Number(kpi.total_fine_exposure).toLocaleString('en-IN')}</div></div>
          <div className="rounded-lg border p-4"><div className="text-xs text-gray-500">Open Actions</div><div className="text-2xl font-bold">{kpi.open_actions}</div></div>
          <div className="rounded-lg border p-4"><div className="text-xs text-gray-500">Remediation Cost</div><div className="text-2xl font-bold">Rs {Number(kpi.total_remediation_cost).toLocaleString('en-IN')}</div></div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain Summary</h2>
        <DataTable rows={chains} columns={chainCols} emptyMessage="No chain data" rowKey={(r, i) => String((r as ChainRow).chain_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failing OR Rooms (velocity &lt; 80 fpm or dB &gt; 70)</h2>
        <DataTable rows={fails} columns={failCols} emptyMessage="No failing rooms" rowKey={(r, i) => String((r as FailRow).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Filter Overdue (hours_used &gt;= filter_life)</h2>
        <DataTable rows={overdue} columns={overdueCols} emptyMessage="No overdue filters" rowKey={(r, i) => String((r as OverdueRow).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open Remediation Actions</h2>
        <DataTable rows={remediation} columns={remCols} emptyMessage="No open actions" rowKey={(r, i) => String((r as RemediationRow).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Evacuator Model Breakdown</h2>
        <DataTable rows={models} columns={modelCols} emptyMessage="No model data" rowKey={(r, i) => String((r as ModelRow).evacuator_model ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Heatmap</h2>
        <DataTable rows={cities} columns={cityCols} emptyMessage="No city data" rowKey={(r, i) => String((r as CityRow).city ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Workload</h2>
        <DataTable rows={engineers} columns={engCols} emptyMessage="No engineer data" rowKey={(r, i) => String((r as EngineerRow).owner_engineer_email ?? i)} />
      </section>
    </div>
  );
}
