import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type VisitRollup = {
  audit_month: string;
  visits_total: number;
  completed_count: number;
  partial_count: number;
  no_access_count: number;
  rescheduled_count: number;
  cancelled_count: number;
  signoff_rate_pct: number | null;
};

type SeverityByEngineer = {
  engineer_name: string;
  visits: number;
  clean_count: number;
  minor_count: number;
  major_count: number;
  critical_count: number;
  avg_duration_min: number | null;
};

type OutOfSpec = {
  device_serial: string;
  device_model: string;
  hospital_name: string;
  pressure_psi_actual: number | null;
  pressure_psi_spec_min: number;
  pressure_psi_spec_max: number;
  deviation_pct: number | null;
  finding_severity: string;
};

type RemediationSla = {
  device_serial: string;
  hospital_name: string;
  finding_severity: string;
  remediation_action: string | null;
  remediation_due_by: string | null;
  remediation_completed_at: string | null;
  sla_state: string;
  days_remaining: number | null;
};

type ConsumableBurn = {
  hospital_name: string;
  device_serial: string;
  consumable_tip_stock: number | null;
  saline_bag_stock: number | null;
  reorder_flag: string;
};

type CalCost = {
  device_model: string;
  cal_visits: number;
  pass_count: number;
  fail_count: number;
  total_parts_rupees: number;
  total_labor_rupees: number;
  total_travel_rupees: number;
  total_invoiced_rupees: number;
  amc_absorbed_rupees: number;
};

type UpcomingCal = {
  due_date: string;
  kind: string;
  hospital_name: string;
  device_serial: string;
  device_model: string;
  detail: string;
};

type WarrantyMix = {
  warranty_status: string;
  device_count: number;
  total_invoiced_rupees: number;
  avg_drift_pct: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    rollupRes,
    sevRes,
    oosRes,
    slaRes,
    burnRes,
    calCostRes,
    calendarRes,
    warrantyRes,
  ] = await Promise.all([
    supabase.rpc('pulse_lavage_r3026_visit_rollup'),
    supabase.rpc('pulse_lavage_r3026_severity_by_engineer'),
    supabase.rpc('pulse_lavage_r3026_out_of_spec_devices'),
    supabase.rpc('pulse_lavage_r3026_remediation_sla'),
    supabase.rpc('pulse_lavage_r3026_consumable_burn'),
    supabase.rpc('pulse_lavage_r3026_calibration_cost'),
    supabase.rpc('pulse_lavage_r3026_upcoming_calendar'),
    supabase.rpc('pulse_lavage_r3026_warranty_mix'),
  ]);

  const rollup: VisitRollup[] = (rollupRes.data as VisitRollup[]) ?? [];
  const sev: SeverityByEngineer[] = (sevRes.data as SeverityByEngineer[]) ?? [];
  const oos: OutOfSpec[] = (oosRes.data as OutOfSpec[]) ?? [];
  const sla: RemediationSla[] = (slaRes.data as RemediationSla[]) ?? [];
  const burn: ConsumableBurn[] = (burnRes.data as ConsumableBurn[]) ?? [];
  const cal: CalCost[] = (calCostRes.data as CalCost[]) ?? [];
  const cal2: UpcomingCal[] = (calendarRes.data as UpcomingCal[]) ?? [];
  const warranty: WarrantyMix[] = (warrantyRes.data as WarrantyMix[]) ?? [];

  const rollupCols: Column<VisitRollup>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Visits', accessor: (r) => r.visits_total },
    { header: 'Completed', accessor: (r) => r.completed_count },
    { header: 'Partial', accessor: (r) => r.partial_count },
    { header: 'No-access', accessor: (r) => r.no_access_count },
    { header: 'Rescheduled', accessor: (r) => r.rescheduled_count },
    { header: 'Cancelled', accessor: (r) => r.cancelled_count },
    { header: 'Signoff %', accessor: (r) => (r.signoff_rate_pct ?? 0) + '%' },
  ];

  const sevCols: Column<SeverityByEngineer>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Visits', accessor: (r) => r.visits },
    { header: 'Clean', accessor: (r) => r.clean_count },
    { header: 'Minor', accessor: (r) => r.minor_count },
    { header: 'Major', accessor: (r) => r.major_count },
    { header: 'Critical', accessor: (r) => r.critical_count },
    { header: 'Avg min', accessor: (r) => r.avg_duration_min ?? '—' },
  ];

  const oosCols: Column<OutOfSpec>[] = [
    { header: 'Serial', accessor: (r) => r.device_serial },
    { header: 'Model', accessor: (r) => r.device_model },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Actual psi', accessor: (r) => r.pressure_psi_actual ?? '—' },
    { header: 'Spec', accessor: (r) => r.pressure_psi_spec_min + '–' + r.pressure_psi_spec_max },
    { header: 'Deviation %', accessor: (r) => (r.deviation_pct ?? 0) + '%' },
    { header: 'Severity', accessor: (r) => r.finding_severity },
  ];

  const slaCols: Column<RemediationSla>[] = [
    { header: 'Serial', accessor: (r) => r.device_serial },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Severity', accessor: (r) => r.finding_severity },
    { header: 'Action', accessor: (r) => r.remediation_action ?? '—' },
    { header: 'Due', accessor: (r) => r.remediation_due_by ?? '—' },
    { header: 'Closed', accessor: (r) => r.remediation_completed_at ?? '—' },
    { header: 'State', accessor: (r) => r.sla_state },
    { header: 'Days left', accessor: (r) => r.days_remaining ?? '—' },
  ];

  const burnCols: Column<ConsumableBurn>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Serial', accessor: (r) => r.device_serial },
    { header: 'Tips stock', accessor: (r) => r.consumable_tip_stock ?? '—' },
    { header: 'Saline bags', accessor: (r) => r.saline_bag_stock ?? '—' },
    { header: 'Flag', accessor: (r) => r.reorder_flag },
  ];

  const calCols: Column<CalCost>[] = [
    { header: 'Model', accessor: (r) => r.device_model },
    { header: 'Cal visits', accessor: (r) => r.cal_visits },
    { header: 'Pass', accessor: (r) => r.pass_count },
    { header: 'Fail', accessor: (r) => r.fail_count },
    { header: 'Parts ₹', accessor: (r) => r.total_parts_rupees },
    { header: 'Labor ₹', accessor: (r) => r.total_labor_rupees },
    { header: 'Travel ₹', accessor: (r) => r.total_travel_rupees },
    { header: 'Invoiced ₹', accessor: (r) => r.total_invoiced_rupees },
    { header: 'AMC absorbed ₹', accessor: (r) => r.amc_absorbed_rupees },
  ];

  const cal2Cols: Column<UpcomingCal>[] = [
    { header: 'Due', accessor: (r) => r.due_date },
    { header: 'Kind', accessor: (r) => r.kind },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Serial', accessor: (r) => r.device_serial },
    { header: 'Model', accessor: (r) => r.device_model },
    { header: 'Detail', accessor: (r) => r.detail },
  ];

  const warrantyCols: Column<WarrantyMix>[] = [
    { header: 'Warranty', accessor: (r) => r.warranty_status },
    { header: 'Devices', accessor: (r) => r.device_count },
    { header: 'Invoiced ₹', accessor: (r) => r.total_invoiced_rupees },
    { header: 'Avg drift %', accessor: (r) => (r.avg_drift_pct ?? 0) + '%' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Engineer Monthly Pulse-Lavage Site Audit</h1>
        <p className="text-sm text-gray-600">
          Round r3026 · monthly engineer visits to customer OT sites — pulse-lavage wound-irrigation tool
          maintenance, calibration drift, consumable burn & remediation SLA.
        </p>
      </header>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Visit roll-up by month</h2>
        <DataTable
          rows={rollup}
          columns={rollupCols}
          emptyMessage="No audit visits logged."
          rowKey={(r, i) => String((r as VisitRollup).audit_month ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Severity heatmap by engineer</h2>
        <DataTable
          rows={sev}
          columns={sevCols}
          emptyMessage="No engineer attribution yet."
          rowKey={(r, i) => String((r as SeverityByEngineer).engineer_name ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Out-of-spec pressure devices</h2>
        <DataTable
          rows={oos}
          columns={oosCols}
          emptyMessage="All devices within pressure spec."
          rowKey={(r, i) => String((r as OutOfSpec).device_serial ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Remediation SLA</h2>
        <DataTable
          rows={sla}
          columns={slaCols}
          emptyMessage="No open remediations."
          rowKey={(r, i) => String((r as RemediationSla).device_serial ?? i) + '-' + i}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Consumable burn & reorder flags</h2>
        <DataTable
          rows={burn}
          columns={burnCols}
          emptyMessage="No consumable readings."
          rowKey={(r, i) => String((r as ConsumableBurn).device_serial ?? i) + '-' + i}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Calibration cost-of-quality by model</h2>
        <DataTable
          rows={cal}
          columns={calCols}
          emptyMessage="No calibration cost data."
          rowKey={(r, i) => String((r as CalCost).device_model ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Upcoming audit & calibration calendar (next 60 days)</h2>
        <DataTable
          rows={cal2}
          columns={cal2Cols}
          emptyMessage="Nothing due in window."
          rowKey={(r, i) => String((r as UpcomingCal).due_date ?? i) + '-' + i}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Warranty & AMC coverage mix</h2>
        <DataTable
          rows={warranty}
          columns={warrantyCols}
          emptyMessage="No warranty mix."
          rowKey={(r, i) => String((r as WarrantyMix).warranty_status ?? i)}
        />
      </section>
    </div>
  );
}