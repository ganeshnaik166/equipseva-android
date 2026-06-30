import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/founder/DataTable';
import type { Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type HospitalPassRate = { hospital_name: string; total_inspections: number; passes: number; fails: number; pass_rate_pct: number | null };
type EngineerScore = { engineer_name: string; inspections: number; marginal: number; fails: number; avg_engagement_force: number | null };
type RailPos = { side_rail_position: string; fails: number; avg_deflection_mm: number | null };
type DropVerdict = { verdict: string; units: number; total_remediation_rupees: number };
type SurfaceFail = { surface_type: string; tests: number; fails_or_recalls: number; fail_rate_pct: number | null };
type Recall = { hospital_name: string; stretcher_asset_tag: string; verdict: string; frame_integrity: string; remediation_cost_rupees: number | null; test_date: string };
type Monthly = { inspection_month: string; total: number; passes: number; retest_required: number; compliance_pct: number | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [hospital, engineer, rail, verdict, surface, recall, monthly] = await Promise.all([
    supabase.rpc('fc_r3060_hospital_pass_rate'),
    supabase.rpc('fc_r3060_engineer_scorecard'),
    supabase.rpc('fc_r3060_failed_rail_positions'),
    supabase.rpc('fc_r3060_drop_verdict_breakdown'),
    supabase.rpc('fc_r3060_surface_fail_rate'),
    supabase.rpc('fc_r3060_recall_watchlist'),
    supabase.rpc('fc_r3060_monthly_compliance'),
  ]);

  const hospitalRows: HospitalPassRate[] = (hospital.data ?? []) as HospitalPassRate[];
  const engineerRows: EngineerScore[] = (engineer.data ?? []) as EngineerScore[];
  const railRows: RailPos[] = (rail.data ?? []) as RailPos[];
  const verdictRows: DropVerdict[] = (verdict.data ?? []) as DropVerdict[];
  const surfaceRows: SurfaceFail[] = (surface.data ?? []) as SurfaceFail[];
  const recallRows: Recall[] = (recall.data ?? []) as Recall[];
  const monthlyRows: Monthly[] = (monthly.data ?? []) as Monthly[];

  const hospitalCols: Column<HospitalPassRate>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Inspections', accessor: (r) => r.total_inspections },
    { header: 'Passes', accessor: (r) => r.passes },
    { header: 'Fails', accessor: (r) => r.fails },
    { header: 'Pass rate %', accessor: (r) => r.pass_rate_pct ?? '-' },
  ];

  const engineerCols: Column<EngineerScore>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Inspections', accessor: (r) => r.inspections },
    { header: 'Marginal', accessor: (r) => r.marginal },
    { header: 'Fails', accessor: (r) => r.fails },
    { header: 'Avg engagement N', accessor: (r) => r.avg_engagement_force ?? '-' },
  ];

  const railCols: Column<RailPos>[] = [
    { header: 'Rail position', accessor: (r) => r.side_rail_position },
    { header: 'Fails', accessor: (r) => r.fails },
    { header: 'Avg deflection mm', accessor: (r) => r.avg_deflection_mm ?? '-' },
  ];

  const verdictCols: Column<DropVerdict>[] = [
    { header: 'Verdict', accessor: (r) => r.verdict },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Total remediation Rs', accessor: (r) => r.total_remediation_rupees },
  ];

  const surfaceCols: Column<SurfaceFail>[] = [
    { header: 'Surface', accessor: (r) => r.surface_type },
    { header: 'Tests', accessor: (r) => r.tests },
    { header: 'Fails/recalls', accessor: (r) => r.fails_or_recalls },
    { header: 'Fail rate %', accessor: (r) => r.fail_rate_pct ?? '-' },
  ];

  const recallCols: Column<Recall>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Asset', accessor: (r) => r.stretcher_asset_tag },
    { header: 'Verdict', accessor: (r) => r.verdict },
    { header: 'Frame', accessor: (r) => r.frame_integrity },
    { header: 'Remediation Rs', accessor: (r) => r.remediation_cost_rupees ?? '-' },
    { header: 'Tested', accessor: (r) => r.test_date },
  ];

  const monthlyCols: Column<Monthly>[] = [
    { header: 'Month', accessor: (r) => r.inspection_month },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Passes', accessor: (r) => r.passes },
    { header: 'Retest required', accessor: (r) => r.retest_required },
    { header: 'Compliance %', accessor: (r) => r.compliance_pct ?? '-' },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>Stretcher Side-Rail Latch & Drop-Test Compliance</h1>
        <p style={{ color: '#6b7280', fontSize: 13 }}>Round r3060 — monthly engineer-led hospital stretcher inspections per IEC 60601-2-52.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Hospital pass-rate (latch)</h2>
        <DataTable rows={hospitalRows} columns={hospitalCols} emptyMessage="No hospitals" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer scorecard</h2>
        <DataTable rows={engineerRows} columns={engineerCols} emptyMessage="No engineers" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Rail position failures</h2>
        <DataTable rows={railRows} columns={railCols} emptyMessage="No rail data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Drop-test verdict breakdown</h2>
        <DataTable rows={verdictRows} columns={verdictCols} emptyMessage="No drop tests" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Surface-type fail rate</h2>
        <DataTable rows={surfaceRows} columns={surfaceCols} emptyMessage="No surface data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Recall watchlist</h2>
        <DataTable rows={recallRows} columns={recallCols} emptyMessage="No recalls open" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly compliance trend</h2>
        <DataTable rows={monthlyRows} columns={monthlyCols} emptyMessage="No monthly data" rowKey={(r, i) => String((r as { id?: string }).id ?? i)} />
      </section>
    </main>
  );
}
