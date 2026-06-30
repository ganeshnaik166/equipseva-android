import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type OverviewRow = {
  total_audits: number;
  hospitals_audited: number;
  ot_rooms_audited: number;
  passed_audits: number;
  conditional_passes: number;
  failed_audits: number;
  condemned_units: number;
  avg_capture_velocity: number;
  avg_exposure_ppm: number;
  total_remediation_rupees: number;
};

type VelocityRow = {
  velocity_compliance_status: string;
  audit_count: number;
  avg_velocity_fpm: number;
  min_velocity_fpm: number;
  hospitals_affected: number;
};

type FilterRow = {
  hospital_name: string;
  ot_room_code: string;
  ulpa_loading_pct: number;
  carbon_loading_pct: number;
  prefilter_loading_pct: number;
  replacement_urgency: string;
  niosh_grade: string;
};

type ExposureRow = {
  hospital_name: string;
  ot_room_code: string;
  surgical_team_exposure_ppm: number;
  niosh_exposure_limit_ppm: number;
  exceedance_ratio: number;
  exposure_compliance_status: string;
  surgeries_per_month: number;
};

type GradeRow = {
  niosh_overall_grade: string;
  audit_count: number;
  hospitals_at_grade: number;
  avg_velocity: number;
  avg_exposure: number;
  total_remediation_rupees: number;
};

type QueueRow = {
  hospital_name: string;
  ot_room_code: string;
  component_type: string;
  queue_priority: string;
  quantity_required: number;
  total_cost_rupees: number;
  supplier_name: string;
  queue_status: string;
  niosh_risk_if_delayed: string;
};

type SupplierRow = {
  supplier_name: string;
  line_items: number;
  total_quantity: number;
  total_spend_rupees: number;
  avg_lead_time_days: number;
  emergency_lines: number;
};

type ComplaintRow = {
  hospital_name: string;
  ot_room_code: string;
  component_type: string;
  surgeon_complaint_count: number;
  queue_priority: string;
  queue_status: string;
  scheduled_replacement_date: string | null;
  niosh_risk_if_delayed: string;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '-';
  return 'Rs ' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    overviewRes,
    velocityRes,
    filterRes,
    exposureRes,
    gradeRes,
    queueRes,
    supplierRes,
    complaintRes,
  ] = await Promise.all([
    supabase.rpc('founder_ot_smoke_audit_overview_r3120'),
    supabase.rpc('founder_ot_smoke_velocity_compliance_r3120'),
    supabase.rpc('founder_ot_smoke_filter_loading_r3120'),
    supabase.rpc('founder_ot_smoke_exposure_risk_r3120'),
    supabase.rpc('founder_ot_smoke_niosh_grade_r3120'),
    supabase.rpc('founder_ot_smoke_replacement_queue_r3120'),
    supabase.rpc('founder_ot_smoke_supplier_spend_r3120'),
    supabase.rpc('founder_ot_smoke_surgeon_complaints_r3120'),
  ]);

  const overview: OverviewRow[] = (overviewRes.data as OverviewRow[]) ?? [];
  const velocity: VelocityRow[] = (velocityRes.data as VelocityRow[]) ?? [];
  const filterLoading: FilterRow[] = (filterRes.data as FilterRow[]) ?? [];
  const exposure: ExposureRow[] = (exposureRes.data as ExposureRow[]) ?? [];
  const grade: GradeRow[] = (gradeRes.data as GradeRow[]) ?? [];
  const queue: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];
  const supplier: SupplierRow[] = (supplierRes.data as SupplierRow[]) ?? [];
  const complaints: ComplaintRow[] = (complaintRes.data as ComplaintRow[]) ?? [];

  const overviewCols: Column<OverviewRow>[] = [
    { key: 'total_audits', header: 'Total Audits' },
    { key: 'hospitals_audited', header: 'Hospitals' },
    { key: 'ot_rooms_audited', header: 'OT Rooms' },
    { key: 'passed_audits', header: 'Passed' },
    { key: 'conditional_passes', header: 'Conditional' },
    { key: 'failed_audits', header: 'Failed' },
    { key: 'condemned_units', header: 'Condemned' },
    { key: 'avg_capture_velocity', header: 'Avg Velocity (fpm)' },
    { key: 'avg_exposure_ppm', header: 'Avg Exposure (ppm)' },
    { key: 'total_remediation_rupees', header: 'Total Remediation', render: (r) => fmtRupees(r.total_remediation_rupees) },
  ];

  const velocityCols: Column<VelocityRow>[] = [
    { key: 'velocity_compliance_status', header: 'Compliance' },
    { key: 'audit_count', header: 'Audits' },
    { key: 'avg_velocity_fpm', header: 'Avg fpm' },
    { key: 'min_velocity_fpm', header: 'Min fpm' },
    { key: 'hospitals_affected', header: 'Hospitals' },
  ];

  const filterCols: Column<FilterRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ot_room_code', header: 'OT Room' },
    { key: 'ulpa_loading_pct', header: 'ULPA %' },
    { key: 'carbon_loading_pct', header: 'Carbon %' },
    { key: 'prefilter_loading_pct', header: 'Prefilter %' },
    { key: 'replacement_urgency', header: 'Urgency' },
    { key: 'niosh_grade', header: 'NIOSH Grade' },
  ];

  const exposureCols: Column<ExposureRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ot_room_code', header: 'OT Room' },
    { key: 'surgical_team_exposure_ppm', header: 'Exposure (ppm)' },
    { key: 'niosh_exposure_limit_ppm', header: 'NIOSH REL (ppm)' },
    { key: 'exceedance_ratio', header: 'Exceedance Ratio' },
    { key: 'exposure_compliance_status', header: 'Status' },
    { key: 'surgeries_per_month', header: 'Surgeries / Month' },
  ];

  const gradeCols: Column<GradeRow>[] = [
    { key: 'niosh_overall_grade', header: 'Grade' },
    { key: 'audit_count', header: 'Audits' },
    { key: 'hospitals_at_grade', header: 'Hospitals' },
    { key: 'avg_velocity', header: 'Avg Velocity (fpm)' },
    { key: 'avg_exposure', header: 'Avg Exposure (ppm)' },
    { key: 'total_remediation_rupees', header: 'Remediation', render: (r) => fmtRupees(r.total_remediation_rupees) },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ot_room_code', header: 'OT Room' },
    { key: 'component_type', header: 'Component' },
    { key: 'queue_priority', header: 'Priority' },
    { key: 'quantity_required', header: 'Qty' },
    { key: 'total_cost_rupees', header: 'Cost', render: (r) => fmtRupees(r.total_cost_rupees) },
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'queue_status', header: 'Status' },
    { key: 'niosh_risk_if_delayed', header: 'Risk If Delayed' },
  ];

  const supplierCols: Column<SupplierRow>[] = [
    { key: 'supplier_name', header: 'Supplier' },
    { key: 'line_items', header: 'Line Items' },
    { key: 'total_quantity', header: 'Total Qty' },
    { key: 'total_spend_rupees', header: 'Spend', render: (r) => fmtRupees(r.total_spend_rupees) },
    { key: 'avg_lead_time_days', header: 'Avg Lead Time (d)' },
    { key: 'emergency_lines', header: 'Emergency Lines' },
  ];

  const complaintCols: Column<ComplaintRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ot_room_code', header: 'OT Room' },
    { key: 'component_type', header: 'Component' },
    { key: 'surgeon_complaint_count', header: 'Complaints' },
    { key: 'queue_priority', header: 'Priority' },
    { key: 'queue_status', header: 'Status' },
    { key: 'scheduled_replacement_date', header: 'Scheduled' },
    { key: 'niosh_risk_if_delayed', header: 'Risk If Delayed' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">OT Surgical Smoke Evacuator Capture Efficiency Audit</h1>
        <p className="text-sm text-gray-600">
          Monthly NIOSH-aligned audit across hospital OTs: capture velocity, filter loading, surgical-team exposure
          (REL &lt;= 0.5 ppm) and replacement queue.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Audit Overview</h2>
        <DataTable
          rows={overview}
          columns={overviewCols}
          emptyMessage="No audit overview available."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Capture Velocity Compliance (NIOSH target &gt;= 100 fpm)</h2>
        <DataTable
          rows={velocity}
          columns={velocityCols}
          emptyMessage="No velocity compliance data."
          rowKey={(r, i) => String(r.velocity_compliance_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Filter Loading by OT Room</h2>
        <DataTable
          rows={filterLoading}
          columns={filterCols}
          emptyMessage="No filter loading data."
          rowKey={(r, i) => String(r.hospital_name + r.ot_room_code + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Surgical Team Exposure vs NIOSH REL</h2>
        <DataTable
          rows={exposure}
          columns={exposureCols}
          emptyMessage="No exposure data."
          rowKey={(r, i) => String(r.hospital_name + r.ot_room_code + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">NIOSH Overall Grade Distribution</h2>
        <DataTable
          rows={grade}
          columns={gradeCols}
          emptyMessage="No grade distribution."
          rowKey={(r, i) => String(r.niosh_overall_grade ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Replacement Queue (priority sorted)</h2>
        <DataTable
          rows={queue}
          columns={queueCols}
          emptyMessage="Replacement queue empty."
          rowKey={(r, i) => String(r.hospital_name + r.component_type + i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Supplier Spend & Lead Time</h2>
        <DataTable
          rows={supplier}
          columns={supplierCols}
          emptyMessage="No supplier data."
          rowKey={(r, i) => String(r.supplier_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Surgeon Complaint Escalations</h2>
        <DataTable
          rows={complaints}
          columns={complaintCols}
          emptyMessage="No surgeon complaints flagged."
          rowKey={(r, i) => String(r.hospital_name + r.ot_room_code + i)}
        />
      </section>
    </div>
  );
}
