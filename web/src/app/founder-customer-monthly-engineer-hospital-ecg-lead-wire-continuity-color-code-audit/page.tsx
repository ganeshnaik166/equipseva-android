import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/data-table';
import type { Column } from '@/components/data-table';

export const dynamic = 'force-dynamic';

type MonthlyRow = { audit_month: string; total: number; passes: number; partials: number; fails: number; replaced: number };
type CityRow = { city: string; audits: number; fail_or_replace: number; avg_resistance: number };
type EngineerRow = { engineer_name: string; audits: number; pass_rate: number; total_wires: number; failed_wires: number };
type MismatchRow = { audit_code: string; hospital_name: string; lead_label: string; expected_color: string; observed_color: string; severity: string; action_taken: string; resolved: boolean };
type WardRow = { ward: string; audits: number; critical_findings: number; unresolved: number };
type DegradationRow = { shielding_status: string; insulation_status: string; count: number; fail_count: number };
type LeadCfgRow = { lead_configuration: string; color_standard: string; audits: number; mismatch_total: number; pass_rate: number };
type CriticalRow = { audit_code: string; hospital_name: string; hospital_city: string; ward: string; lead_label: string; action_taken: string; audit_month: string };

type WithId<T> = T & { id?: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [monthly, byCity, engineers, mismatch, ward, degradation, leadCfg, critical] = await Promise.all([
    supabase.rpc('rpc_r3080_monthly_outcomes'),
    supabase.rpc('rpc_r3080_by_city'),
    supabase.rpc('rpc_r3080_engineer_leaderboard'),
    supabase.rpc('rpc_r3080_color_mismatch_findings'),
    supabase.rpc('rpc_r3080_ward_risk'),
    supabase.rpc('rpc_r3080_degradation_matrix'),
    supabase.rpc('rpc_r3080_lead_config_summary'),
    supabase.rpc('rpc_r3080_critical_unresolved'),
  ]);

  const monthlyRows: WithId<MonthlyRow>[] = (monthly.data ?? []) as WithId<MonthlyRow>[];
  const cityRows: WithId<CityRow>[] = (byCity.data ?? []) as WithId<CityRow>[];
  const engineerRows: WithId<EngineerRow>[] = (engineers.data ?? []) as WithId<EngineerRow>[];
  const mismatchRows: WithId<MismatchRow>[] = (mismatch.data ?? []) as WithId<MismatchRow>[];
  const wardRows: WithId<WardRow>[] = (ward.data ?? []) as WithId<WardRow>[];
  const degradationRows: WithId<DegradationRow>[] = (degradation.data ?? []) as WithId<DegradationRow>[];
  const leadCfgRows: WithId<LeadCfgRow>[] = (leadCfg.data ?? []) as WithId<LeadCfgRow>[];
  const criticalRows: WithId<CriticalRow>[] = (critical.data ?? []) as WithId<CriticalRow>[];

  const monthlyCols: Column<MonthlyRow>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Pass', accessor: (r) => r.passes },
    { header: 'Partial', accessor: (r) => r.partials },
    { header: 'Fail', accessor: (r) => r.fails },
    { header: 'Replaced', accessor: (r) => r.replaced },
  ];

  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Fail/Replace', accessor: (r) => r.fail_or_replace },
    { header: 'Avg Ohms', accessor: (r) => r.avg_resistance },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Pass %', accessor: (r) => r.pass_rate },
    { header: 'Wires', accessor: (r) => r.total_wires },
    { header: 'Failed', accessor: (r) => r.failed_wires },
  ];

  const mismatchCols: Column<MismatchRow>[] = [
    { header: 'Audit', accessor: (r) => r.audit_code },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Lead', accessor: (r) => r.lead_label },
    { header: 'Expected', accessor: (r) => r.expected_color },
    { header: 'Observed', accessor: (r) => r.observed_color },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Action', accessor: (r) => r.action_taken },
    { header: 'Resolved', accessor: (r) => (r.resolved ? 'yes' : 'no') },
  ];

  const wardCols: Column<WardRow>[] = [
    { header: 'Ward', accessor: (r) => r.ward },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Critical', accessor: (r) => r.critical_findings },
    { header: 'Unresolved', accessor: (r) => r.unresolved },
  ];

  const degradationCols: Column<DegradationRow>[] = [
    { header: 'Shielding', accessor: (r) => r.shielding_status },
    { header: 'Insulation', accessor: (r) => r.insulation_status },
    { header: 'Count', accessor: (r) => r.count },
    { header: 'Fail/Replace', accessor: (r) => r.fail_count },
  ];

  const leadCfgCols: Column<LeadCfgRow>[] = [
    { header: 'Lead Config', accessor: (r) => r.lead_configuration },
    { header: 'Standard', accessor: (r) => r.color_standard },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Color Mismatches', accessor: (r) => r.mismatch_total },
    { header: 'Pass %', accessor: (r) => r.pass_rate },
  ];

  const criticalCols: Column<CriticalRow>[] = [
    { header: 'Audit', accessor: (r) => r.audit_code },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.hospital_city },
    { header: 'Ward', accessor: (r) => r.ward },
    { header: 'Lead', accessor: (r) => r.lead_label },
    { header: 'Action', accessor: (r) => r.action_taken },
    { header: 'Month', accessor: (r) => r.audit_month },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 600 }}>ECG Lead-Wire Continuity & Color-Code Audit — r3080</h1>
        <p style={{ color: '#666' }}>Customer monthly engineer-led hospital ECG audit: continuity ohms, AHA/IEC color compliance, shielding & insulation status.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Outcomes</h2>
        <DataTable rows={monthlyRows} columns={monthlyCols} emptyMessage="No months yet" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>By City</h2>
        <DataTable rows={cityRows} columns={cityCols} emptyMessage="No city data" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer Leaderboard</h2>
        <DataTable rows={engineerRows} columns={engineerCols} emptyMessage="No engineers" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Color Mismatch Findings</h2>
        <DataTable rows={mismatchRows} columns={mismatchCols} emptyMessage="No mismatches" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Ward Risk</h2>
        <DataTable rows={wardRows} columns={wardCols} emptyMessage="No ward data" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Shielding & Insulation Degradation</h2>
        <DataTable rows={degradationRows} columns={degradationCols} emptyMessage="No degradation rows" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Lead Configuration Summary</h2>
        <DataTable rows={leadCfgRows} columns={leadCfgCols} emptyMessage="No configs" rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Critical Unresolved</h2>
        <DataTable rows={criticalRows} columns={criticalCols} emptyMessage="No critical unresolved findings" rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
