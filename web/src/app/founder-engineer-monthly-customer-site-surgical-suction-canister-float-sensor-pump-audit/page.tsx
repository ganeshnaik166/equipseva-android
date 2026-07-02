import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Roster = { hospital_name: string; city: string; ward_or_or: string; unit_serial: string; canister_model: string; pump_model: string; float_sensor_status: string; pump_vacuum_status: string; overflow_protection_status: string; risk_band: string; assigned_engineer: string; measured_vacuum_kpa: number; float_response_ms: number; next_audit_due_date: string; amc_active: boolean };
type Risk = { risk_band: string; units: number; critical_findings: number; patient_safety_incidents: number; avg_vacuum_kpa: number };
type Overdue = { hospital_name: string; unit_serial: string; ward_or_or: string; assigned_engineer: string; next_audit_due_date: string; days_overdue: number; risk_band: string };
type Eng = { engineer_name: string; units_assigned: number; audits_completed: number; critical_findings: number; avg_rating: number; avg_labor_minutes: number };
type Pareto = { finding_type: string; occurrences: number; criticals: number; parts_spend_rupees: number; labor_minutes_total: number };
type Safety = { hospital_name: string; unit_serial: string; ward_or_or: string; audit_date: string; engineer_name: string; finding_type: string; severity: string; resolution: string; notes: string | null };
type City = { city: string; units: number; criticals: number; avg_float_response_ms: number; total_parts_spend: number };
type Trend = { month: string; findings: number; criticals: number; patient_safety: number; parts_spend: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();
  const [roster, risk, overdue, eng, pareto, safety, city, trend] = await Promise.all([
    sb.rpc('founder_r3058_unit_roster'),
    sb.rpc('founder_r3058_risk_rollup'),
    sb.rpc('founder_r3058_overdue_audits'),
    sb.rpc('founder_r3058_engineer_scorecard'),
    sb.rpc('founder_r3058_failure_mode_pareto'),
    sb.rpc('founder_r3058_patient_safety_incidents'),
    sb.rpc('founder_r3058_city_heat'),
    sb.rpc('founder_r3058_monthly_trend'),
  ]);

  const rosterRows: Roster[] = (roster.data as Roster[]) ?? [];
  const riskRows: Risk[] = (risk.data as Risk[]) ?? [];
  const overdueRows: Overdue[] = (overdue.data as Overdue[]) ?? [];
  const engRows: Eng[] = (eng.data as Eng[]) ?? [];
  const paretoRows: Pareto[] = (pareto.data as Pareto[]) ?? [];
  const safetyRows: Safety[] = (safety.data as Safety[]) ?? [];
  const cityRows: City[] = (city.data as City[]) ?? [];
  const trendRows: Trend[] = (trend.data as Trend[]) ?? [];

  const rosterCols: Column<Roster>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Area', accessor: (r) => r.ward_or_or },
    { header: 'Serial', accessor: (r) => r.unit_serial },
    { header: 'Canister', accessor: (r) => r.canister_model },
    { header: 'Pump', accessor: (r) => r.pump_model },
    { header: 'Float', accessor: (r) => r.float_sensor_status },
    { header: 'Vacuum', accessor: (r) => r.pump_vacuum_status },
    { header: 'Overflow', accessor: (r) => r.overflow_protection_status },
    { header: 'Risk', accessor: (r) => r.risk_band },
    { header: 'Engineer', accessor: (r) => r.assigned_engineer },
    { header: 'kPa', accessor: (r) => r.measured_vacuum_kpa },
    { header: 'Float ms', accessor: (r) => r.float_response_ms },
    { header: 'Next Audit', accessor: (r) => r.next_audit_due_date },
    { header: 'AMC', accessor: (r) => (r.amc_active ? 'yes' : 'no') },
  ];

  const riskCols: Column<Risk>[] = [
    { header: 'Risk Band', accessor: (r) => r.risk_band },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Critical Findings', accessor: (r) => r.critical_findings },
    { header: 'Patient Safety Incidents', accessor: (r) => r.patient_safety_incidents },
    { header: 'Avg Vacuum kPa', accessor: (r) => r.avg_vacuum_kpa },
  ];

  const overdueCols: Column<Overdue>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Serial', accessor: (r) => r.unit_serial },
    { header: 'Area', accessor: (r) => r.ward_or_or },
    { header: 'Engineer', accessor: (r) => r.assigned_engineer },
    { header: 'Due', accessor: (r) => r.next_audit_due_date },
    { header: 'Days Overdue', accessor: (r) => r.days_overdue },
    { header: 'Risk', accessor: (r) => r.risk_band },
  ];

  const engCols: Column<Eng>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Units', accessor: (r) => r.units_assigned },
    { header: 'Audits', accessor: (r) => r.audits_completed },
    { header: 'Criticals', accessor: (r) => r.critical_findings },
    { header: 'Avg Rating', accessor: (r) => r.avg_rating },
    { header: 'Avg Labor min', accessor: (r) => r.avg_labor_minutes },
  ];

  const paretoCols: Column<Pareto>[] = [
    { header: 'Finding Type', accessor: (r) => r.finding_type },
    { header: 'Occurrences', accessor: (r) => r.occurrences },
    { header: 'Criticals', accessor: (r) => r.criticals },
    { header: 'Parts Spend', accessor: (r) => r.parts_spend_rupees },
    { header: 'Labor Minutes', accessor: (r) => r.labor_minutes_total },
  ];

  const safetyCols: Column<Safety>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Serial', accessor: (r) => r.unit_serial },
    { header: 'Area', accessor: (r) => r.ward_or_or },
    { header: 'Audit Date', accessor: (r) => r.audit_date },
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Finding', accessor: (r) => r.finding_type },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Resolution', accessor: (r) => r.resolution },
    { header: 'Notes', accessor: (r) => r.notes ?? '' },
  ];

  const cityCols: Column<City>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Criticals', accessor: (r) => r.criticals },
    { header: 'Avg Float ms', accessor: (r) => r.avg_float_response_ms },
    { header: 'Parts Spend', accessor: (r) => r.total_parts_spend },
  ];

  const trendCols: Column<Trend>[] = [
    { header: 'Month', accessor: (r) => r.month },
    { header: 'Findings', accessor: (r) => r.findings },
    { header: 'Criticals', accessor: (r) => r.criticals },
    { header: 'Patient Safety', accessor: (r) => r.patient_safety },
    { header: 'Parts Spend', accessor: (r) => r.parts_spend },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Engineer Monthly Customer Site Surgical Suction Canister Float-Sensor & Pump Audit</h1>
        <p style={{ color: '#666' }}>Round r3058 — float sensor & vacuum pump audit roster, risk bands, overdue queue, engineer scorecards, failure pareto, patient-safety log, city heat & monthly trend.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Unit Roster</h2>
        <DataTable rows={rosterRows} columns={rosterCols} emptyMessage="No units" rowKey={(r, i) => String((r as Roster).unit_serial ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Risk-Band Rollup</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No data" rowKey={(r, i) => String((r as Risk).risk_band ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Overdue Audits</h2>
        <DataTable rows={overdueRows} columns={overdueCols} emptyMessage="No overdue audits" rowKey={(r, i) => String((r as Overdue).unit_serial ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer Scorecard</h2>
        <DataTable rows={engRows} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as Eng).engineer_name ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Failure-Mode Pareto</h2>
        <DataTable rows={paretoRows} columns={paretoCols} emptyMessage="No findings" rowKey={(r, i) => String((r as Pareto).finding_type ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Patient-Safety Incidents</h2>
        <DataTable rows={safetyRows} columns={safetyCols} emptyMessage="No patient-safety incidents" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>City Heat</h2>
        <DataTable rows={cityRows} columns={cityCols} emptyMessage="No city data" rowKey={(r, i) => String((r as City).city ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No trend data" rowKey={(r, i) => String((r as Trend).month ?? i)} />
      </section>
    </main>
  );
}
