import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { total_checks: number; total_pass: number; pass_rate_pct: number; critical_count: number; hospitals_audited: number; beds_audited: number };
type WardRow = { ward_code: string; checks: number; failures: number; critical: number };
type ResetRow = { reset_button_status: string; occurrences: number; avg_response_ms: number | null };
type InsulationRow = { insulation_status: string; occurrences: number; fail_count: number };
type MonthlyRow = { hospital_name: string; beds_audited: number; compliance_pct: number; nabh_grade: string; critical_findings: number };
type CriticalRow = { ward_code: string; bed_number: string; cable_serial: string; insulation_status: string; connector_status: string; reset_button_status: string; checked_at: string; notes: string | null };
type ReplacementRow = { total_cables_replaced: number; total_buttons_replaced: number; hospitals: number; avg_compliance_pct: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [ov, wards, resets, insul, monthly, crits, repl] = await Promise.all([
    supabase.rpc('cbc_r3024_overview'),
    supabase.rpc('cbc_r3024_failures_by_ward'),
    supabase.rpc('cbc_r3024_reset_button_issues'),
    supabase.rpc('cbc_r3024_insulation_breakdown'),
    supabase.rpc('cbc_r3024_monthly_ranking'),
    supabase.rpc('cbc_r3024_critical_findings'),
    supabase.rpc('cbc_r3024_replacements_totals'),
  ]);

  const overview: Overview | null = (ov.data?.[0] as Overview) ?? null;
  const wardRows: WardRow[] = (wards.data as WardRow[]) ?? [];
  const resetRows: ResetRow[] = (resets.data as ResetRow[]) ?? [];
  const insulRows: InsulationRow[] = (insul.data as InsulationRow[]) ?? [];
  const monthlyRows: MonthlyRow[] = (monthly.data as MonthlyRow[]) ?? [];
  const critRows: CriticalRow[] = (crits.data as CriticalRow[]) ?? [];
  const replTotals: ReplacementRow | null = (repl.data?.[0] as ReplacementRow) ?? null;

  const wardCols: Column<WardRow>[] = [
    { header: 'Ward', accessor: (r) => r.ward_code },
    { header: 'Checks', accessor: (r) => r.checks },
    { header: 'Failures', accessor: (r) => r.failures },
    { header: 'Critical', accessor: (r) => r.critical },
  ];
  const resetCols: Column<ResetRow>[] = [
    { header: 'Reset Button Status', accessor: (r) => r.reset_button_status },
    { header: 'Occurrences', accessor: (r) => r.occurrences },
    { header: 'Avg Response (ms)', accessor: (r) => r.avg_response_ms ?? '—' },
  ];
  const insulCols: Column<InsulationRow>[] = [
    { header: 'Insulation', accessor: (r) => r.insulation_status },
    { header: 'Occurrences', accessor: (r) => r.occurrences },
    { header: 'Fail Count', accessor: (r) => r.fail_count },
  ];
  const monthlyCols: Column<MonthlyRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Beds Audited', accessor: (r) => r.beds_audited },
    { header: 'Compliance %', accessor: (r) => r.compliance_pct },
    { header: 'NABH', accessor: (r) => r.nabh_grade },
    { header: 'Critical', accessor: (r) => r.critical_findings },
  ];
  const critCols: Column<CriticalRow>[] = [
    { header: 'Ward', accessor: (r) => r.ward_code },
    { header: 'Bed', accessor: (r) => r.bed_number },
    { header: 'Cable', accessor: (r) => r.cable_serial },
    { header: 'Insulation', accessor: (r) => r.insulation_status },
    { header: 'Connector', accessor: (r) => r.connector_status },
    { header: 'Reset Btn', accessor: (r) => r.reset_button_status },
    { header: 'Checked', accessor: (r) => new Date(r.checked_at).toLocaleDateString() },
    { header: 'Notes', accessor: (r) => r.notes ?? '' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Patient Call-Bell Cable & Reset-Button Compliance</h1>
        <p className="text-sm text-gray-600">Round r3024 · Monthly engineer-hospital patient-safety compliance dashboard.</p>
      </header>

      {overview && (
        <section className="grid grid-cols-2 md:grid-cols-6 gap-4">
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Total Checks</div><div className="text-xl font-semibold">{overview.total_checks}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Pass</div><div className="text-xl font-semibold">{overview.total_pass}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Pass Rate %</div><div className="text-xl font-semibold">{overview.pass_rate_pct}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Critical</div><div className="text-xl font-semibold text-red-600">{overview.critical_count}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Hospitals</div><div className="text-xl font-semibold">{overview.hospitals_audited}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Beds Audited</div><div className="text-xl font-semibold">{overview.beds_audited}</div></div>
        </section>
      )}

      {replTotals && (
        <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Cables Replaced</div><div className="text-xl font-semibold">{replTotals.total_cables_replaced}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Buttons Replaced</div><div className="text-xl font-semibold">{replTotals.total_buttons_replaced}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Hospitals Reporting</div><div className="text-xl font-semibold">{replTotals.hospitals}</div></div>
          <div className="border rounded p-3"><div className="text-xs text-gray-500">Avg Compliance %</div><div className="text-xl font-semibold">{replTotals.avg_compliance_pct}</div></div>
        </section>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Failures by Ward</h2>
        <DataTable rows={wardRows} columns={wardCols} emptyMessage="No ward data." rowKey={(r, i) => String((r as WardRow).ward_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reset Button Status</h2>
        <DataTable rows={resetRows} columns={resetCols} emptyMessage="No reset data." rowKey={(r, i) => String((r as ResetRow).reset_button_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Cable Insulation Breakdown</h2>
        <DataTable rows={insulRows} columns={insulCols} emptyMessage="No insulation data." rowKey={(r, i) => String((r as InsulationRow).insulation_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Hospital Ranking</h2>
        <DataTable rows={monthlyRows} columns={monthlyCols} emptyMessage="No monthly data." rowKey={(r, i) => String((r as MonthlyRow).hospital_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical & High-Risk Findings</h2>
        <DataTable rows={critRows} columns={critCols} emptyMessage="No critical findings." rowKey={(r, i) => String((r as CriticalRow).cable_serial ?? i)} />
      </section>
    </main>
  );
}
