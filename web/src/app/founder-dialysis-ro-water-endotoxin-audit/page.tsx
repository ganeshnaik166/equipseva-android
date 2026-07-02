import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ComplianceRow = {
  compliance_status: string;
  sample_count: number;
  avg_endotoxin_eu_per_ml: number;
  avg_cfu_per_ml: number;
  worst_endotoxin: number;
};

type FailingUnitRow = {
  hospital_unit_name: string;
  latest_status: string;
  latest_endotoxin: number;
  latest_cfu: number;
  latest_sample_at: string;
};

type SamplePointRow = {
  sample_point: string;
  total_samples: number;
  failures: number;
  avg_chlorine_ppm: number;
  avg_conductivity: number;
};

type ActionQueueRow = {
  priority: string;
  status: string;
  action_count: number;
  total_cost_estimate_rupees: number;
  total_actual_cost_rupees: number;
};

type LabRow = {
  lab_partner: string;
  samples_processed: number;
  pass_rate_pct: number | null;
  avg_endotoxin: number;
};

type ActionCostRow = {
  action_type: string;
  action_count: number;
  total_actual_cost_rupees: number;
  avg_actual_cost_rupees: number;
};

type P0Row = {
  hospital_unit_name: string;
  action_type: string;
  status: string;
  target_completion_at: string;
  cost_estimate_rupees: number;
  resolution_notes: string | null;
};

type TestMethodRow = {
  test_method: string;
  sample_count: number;
  failures: number;
  avg_endotoxin: number;
};

type VendorRow = {
  vendor_required: string;
  action_count: number;
  total_cost_estimate_rupees: number;
};

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 }).format(v);
}

function dateFmt(s: string | null | undefined): string {
  if (!s) return '-';
  try {
    return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return String(s);
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    compliance,
    failingUnits,
    samplePoint,
    actionQueue,
    labMix,
    actionCost,
    p0Queue,
    testMethod,
    vendorMix,
  ] = await Promise.all([
    supabase.rpc('founder_r3104_compliance_rollup'),
    supabase.rpc('founder_r3104_failing_units'),
    supabase.rpc('founder_r3104_sample_point_breakdown'),
    supabase.rpc('founder_r3104_action_queue'),
    supabase.rpc('founder_r3104_lab_partner_mix'),
    supabase.rpc('founder_r3104_action_type_cost'),
    supabase.rpc('founder_r3104_p0_patient_safety'),
    supabase.rpc('founder_r3104_test_method_usage'),
    supabase.rpc('founder_r3104_vendor_mix'),
  ]);

  const complianceCols: Column<ComplianceRow>[] = [
    { key: 'compliance_status', header: 'AAMI / ISO Status' },
    { key: 'sample_count', header: 'Samples' },
    { key: 'avg_endotoxin_eu_per_ml', header: 'Avg Endotoxin EU/mL' },
    { key: 'avg_cfu_per_ml', header: 'Avg CFU/mL' },
    { key: 'worst_endotoxin', header: 'Worst Endotoxin' },
  ];

  const failingCols: Column<FailingUnitRow>[] = [
    { key: 'hospital_unit_name', header: 'Hospital Unit' },
    { key: 'latest_status', header: 'Latest Status' },
    { key: 'latest_endotoxin', header: 'Endotoxin EU/mL' },
    { key: 'latest_cfu', header: 'CFU/mL' },
    { key: 'latest_sample_at', header: 'Sampled At', render: (r: FailingUnitRow) => dateFmt(r.latest_sample_at) },
  ];

  const samplePointCols: Column<SamplePointRow>[] = [
    { key: 'sample_point', header: 'Sample Point' },
    { key: 'total_samples', header: 'Total Samples' },
    { key: 'failures', header: 'Failures' },
    { key: 'avg_chlorine_ppm', header: 'Avg Chlorine ppm' },
    { key: 'avg_conductivity', header: 'Avg Conductivity uS/cm' },
  ];

  const actionQueueCols: Column<ActionQueueRow>[] = [
    { key: 'priority', header: 'Priority' },
    { key: 'status', header: 'Status' },
    { key: 'action_count', header: 'Count' },
    { key: 'total_cost_estimate_rupees', header: 'Estimate', render: (r: ActionQueueRow) => rupees(r.total_cost_estimate_rupees) },
    { key: 'total_actual_cost_rupees', header: 'Actual', render: (r: ActionQueueRow) => rupees(r.total_actual_cost_rupees) },
  ];

  const labCols: Column<LabRow>[] = [
    { key: 'lab_partner', header: 'Lab Partner' },
    { key: 'samples_processed', header: 'Samples' },
    { key: 'pass_rate_pct', header: 'Pass Rate %' },
    { key: 'avg_endotoxin', header: 'Avg Endotoxin EU/mL' },
  ];

  const actionCostCols: Column<ActionCostRow>[] = [
    { key: 'action_type', header: 'Action Type' },
    { key: 'action_count', header: 'Count' },
    { key: 'total_actual_cost_rupees', header: 'Total Actual', render: (r: ActionCostRow) => rupees(r.total_actual_cost_rupees) },
    { key: 'avg_actual_cost_rupees', header: 'Avg Actual', render: (r: ActionCostRow) => rupees(r.avg_actual_cost_rupees) },
  ];

  const p0Cols: Column<P0Row>[] = [
    { key: 'hospital_unit_name', header: 'Hospital Unit' },
    { key: 'action_type', header: 'Action' },
    { key: 'status', header: 'Status' },
    { key: 'target_completion_at', header: 'Target', render: (r: P0Row) => dateFmt(r.target_completion_at) },
    { key: 'cost_estimate_rupees', header: 'Estimate', render: (r: P0Row) => rupees(r.cost_estimate_rupees) },
    { key: 'resolution_notes', header: 'Notes' },
  ];

  const testMethodCols: Column<TestMethodRow>[] = [
    { key: 'test_method', header: 'Test Method' },
    { key: 'sample_count', header: 'Samples' },
    { key: 'failures', header: 'Failures' },
    { key: 'avg_endotoxin', header: 'Avg Endotoxin EU/mL' },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { key: 'vendor_required', header: 'Vendor' },
    { key: 'action_count', header: 'Actions' },
    { key: 'total_cost_estimate_rupees', header: 'Total Estimate', render: (r: VendorRow) => rupees(r.total_cost_estimate_rupees) },
  ];

  return (
    <div className="space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Dialysis RO Water Quality & Endotoxin Audit</h1>
        <p className="text-sm text-neutral-600 mt-1">
          Monthly RO water testing across dialysis loops — endotoxin EU/mL, chlorine ppm, hardness,
          bacterial CFU, AAMI / ISO 23500 compliance, and the purification action queue.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">AAMI / ISO Compliance Rollup</h2>
        <DataTable
          rows={(compliance.data ?? []) as ComplianceRow[]}
          columns={complianceCols}
          emptyMessage="No compliance data yet"
          rowKey={(r, i) => String(r.compliance_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Failing & Action-Level Units (latest sample)</h2>
        <DataTable
          rows={(failingUnits.data ?? []) as FailingUnitRow[]}
          columns={failingCols}
          emptyMessage="No failing units"
          rowKey={(r, i) => String(r.hospital_unit_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Sample-Point Failure Breakdown</h2>
        <DataTable
          rows={(samplePoint.data ?? []) as SamplePointRow[]}
          columns={samplePointCols}
          emptyMessage="No sample-point data"
          rowKey={(r, i) => String(r.sample_point ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Purification Action Queue</h2>
        <DataTable
          rows={(actionQueue.data ?? []) as ActionQueueRow[]}
          columns={actionQueueCols}
          emptyMessage="Queue empty"
          rowKey={(r, i) => String(`${r.priority}-${r.status}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Lab Partner Mix & Pass Rate</h2>
        <DataTable
          rows={(labMix.data ?? []) as LabRow[]}
          columns={labCols}
          emptyMessage="No lab data"
          rowKey={(r, i) => String(r.lab_partner ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Action-Type Cost Rollup</h2>
        <DataTable
          rows={(actionCost.data ?? []) as ActionCostRow[]}
          columns={actionCostCols}
          emptyMessage="No action cost data"
          rowKey={(r, i) => String(r.action_type ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">P0 Patient-Safety Queue</h2>
        <DataTable
          rows={(p0Queue.data ?? []) as P0Row[]}
          columns={p0Cols}
          emptyMessage="No P0 actions"
          rowKey={(r, i) => String(`${r.hospital_unit_name}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Test Method Usage</h2>
        <DataTable
          rows={(testMethod.data ?? []) as TestMethodRow[]}
          columns={testMethodCols}
          emptyMessage="No test method data"
          rowKey={(r, i) => String(r.test_method ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Vendor Mix for Purification Actions</h2>
        <DataTable
          rows={(vendorMix.data ?? []) as VendorRow[]}
          columns={vendorCols}
          emptyMessage="No vendor data"
          rowKey={(r, i) => String(r.vendor_required ?? i)}
        />
      </section>
    </div>
  );
}
