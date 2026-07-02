import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type AuditSummary = { audit_result: string; bed_count: number; safety_flags: number; avg_swivel: number };
type HospitalRollup = { hospital_code: string; hospital_name: string; beds_audited: number; brakes_failed_total: number; safety_flagged: number; avg_pedal_force: number };
type CriticalBed = { hospital_code: string; bed_asset_tag: string; ward_name: string; bed_model: string; brakes_failed: number; caster_wear_mm: number; audit_result: string; severity: string };
type EngWorkload = { engineer_code: string; engineer_name: string; beds_audited: number; passes: number; defects: number; avg_swivel: number };
type RailFinding = { finding: string; rail_count: number; fall_risks: number; avg_cost: number };
type LatchStatus = { latch_status: string; rail_count: number; avg_travel: number; avg_drop_seconds: number; total_cost: number };
type CombinedRisk = { hospital_code: string; bed_asset_tag: string; audit_result: string; brakes_failed: number; broken_rails: number; fall_risk_rails: number; total_parts_cost: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [a, b, c, d, e, f, g] = await Promise.all([
    supabase.rpc('r2978_audit_result_summary'),
    supabase.rpc('r2978_hospital_rollup'),
    supabase.rpc('r2978_critical_beds'),
    supabase.rpc('r2978_engineer_workload'),
    supabase.rpc('r2978_side_rail_findings'),
    supabase.rpc('r2978_latch_status_breakdown'),
    supabase.rpc('r2978_bed_combined_risk'),
  ]);

  const summary: AuditSummary[] = (a.data as AuditSummary[]) ?? [];
  const hospitals: HospitalRollup[] = (b.data as HospitalRollup[]) ?? [];
  const critical: CriticalBed[] = (c.data as CriticalBed[]) ?? [];
  const engineers: EngWorkload[] = (d.data as EngWorkload[]) ?? [];
  const findings: RailFinding[] = (e.data as RailFinding[]) ?? [];
  const latch: LatchStatus[] = (f.data as LatchStatus[]) ?? [];
  const combined: CombinedRisk[] = (g.data as CombinedRisk[]) ?? [];

  const summaryCols: Column<AuditSummary>[] = [
    { key: 'audit_result', header: 'Result' },
    { key: 'bed_count', header: 'Beds' },
    { key: 'safety_flags', header: 'Safety Flags' },
    { key: 'avg_swivel', header: 'Avg Swivel' },
  ];

  const hospitalCols: Column<HospitalRollup>[] = [
    { key: 'hospital_code', header: 'Code' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'beds_audited', header: 'Beds' },
    { key: 'brakes_failed_total', header: 'Brakes Failed' },
    { key: 'safety_flagged', header: 'Safety Flagged' },
    { key: 'avg_pedal_force', header: 'Avg Pedal Force (N)' },
  ];

  const criticalCols: Column<CriticalBed>[] = [
    { key: 'hospital_code', header: 'Hospital' },
    { key: 'bed_asset_tag', header: 'Bed Tag' },
    { key: 'ward_name', header: 'Ward' },
    { key: 'bed_model', header: 'Model' },
    { key: 'brakes_failed', header: 'Brakes Failed' },
    { key: 'caster_wear_mm', header: 'Caster Wear (mm)' },
    { key: 'audit_result', header: 'Result' },
    { key: 'severity', header: 'Severity' },
  ];

  const engCols: Column<EngWorkload>[] = [
    { key: 'engineer_code', header: 'Code' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'beds_audited', header: 'Beds' },
    { key: 'passes', header: 'Passes' },
    { key: 'defects', header: 'Defects' },
    { key: 'avg_swivel', header: 'Avg Swivel' },
  ];

  const findingCols: Column<RailFinding>[] = [
    { key: 'finding', header: 'Finding' },
    { key: 'rail_count', header: 'Rails' },
    { key: 'fall_risks', header: 'Fall Risks' },
    { key: 'avg_cost', header: 'Avg Cost (Rs)' },
  ];

  const latchCols: Column<LatchStatus>[] = [
    { key: 'latch_status', header: 'Latch' },
    { key: 'rail_count', header: 'Rails' },
    { key: 'avg_travel', header: 'Avg Travel (cm)' },
    { key: 'avg_drop_seconds', header: 'Avg Drop (s)' },
    { key: 'total_cost', header: 'Total Cost (Rs)' },
  ];

  const combinedCols: Column<CombinedRisk>[] = [
    { key: 'hospital_code', header: 'Hospital' },
    { key: 'bed_asset_tag', header: 'Bed Tag' },
    { key: 'audit_result', header: 'Audit Result' },
    { key: 'brakes_failed', header: 'Brakes Failed' },
    { key: 'broken_rails', header: 'Broken Rails' },
    { key: 'fall_risk_rails', header: 'Fall-Risk Rails' },
    { key: 'total_parts_cost', header: 'Parts Cost (Rs)' },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Monthly Customer Site Patient-Bed Brake-Caster &amp; Side-Rail Function Audit</h1>
        <p className="text-sm text-gray-600">Round r2978 — beds with severity &gt;= high escalated to patient-safety queue.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit result summary</h2>
        <DataTable rows={summary} columns={summaryCols} emptyMessage="No audits" rowKey={(r, i) => String((r as AuditSummary).audit_result ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospital rollup</h2>
        <DataTable rows={hospitals} columns={hospitalCols} emptyMessage="No hospitals" rowKey={(r, i) => String((r as HospitalRollup).hospital_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical beds (severity &gt;= high)</h2>
        <DataTable rows={critical} columns={criticalCols} emptyMessage="No critical beds" rowKey={(r, i) => String((r as CriticalBed).bed_asset_tag ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer workload</h2>
        <DataTable rows={engineers} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as EngWorkload).engineer_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Side-rail findings</h2>
        <DataTable rows={findings} columns={findingCols} emptyMessage="No findings" rowKey={(r, i) => String((r as RailFinding).finding ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Latch status breakdown</h2>
        <DataTable rows={latch} columns={latchCols} emptyMessage="No rails" rowKey={(r, i) => String((r as LatchStatus).latch_status ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Combined bed risk (brakes & rails)</h2>
        <DataTable rows={combined} columns={combinedCols} emptyMessage="No beds" rowKey={(r, i) => String((r as CombinedRisk).bed_asset_tag ?? i)} />
      </section>
    </div>
  );
}
