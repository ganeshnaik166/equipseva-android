import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type MonthlySummary = { session_month: string; total_sessions: number; hospitals_covered: number; avg_segregation_compliance: number; cpcb_compliant_count: number; escalated_count: number };
type EngineerRow = { engineer_name: string; sessions_initiated: number; staff_trained_total: number; avg_score_delta: number; avg_post_score: number };
type ColorRow = { color_code: string; session_count: number; staff_trained: number; avg_compliance: number; compliant_pct: number };
type RiskRow = { hospital_name: string; total_waste_kg: number; mis_segregation_total: number; highest_risk: string; avg_rating: number; follow_up_required: boolean };
type WasteRow = { waste_category: string; sessions: number; avg_duration_minutes: number; avg_post_score: number };
type PenaltyRow = { penalty_risk: string; hospital_count: number; total_waste_kg: number; follow_ups_open: number };
type ImpactRow = { hospital_name: string; pre_avg: number; post_avg: number; delta: number; staff_trained: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [monthly, engineers, colors, risk, waste, penalty, impact] = await Promise.all([
    supabase.rpc('rpc_r2980_monthly_compliance_summary'),
    supabase.rpc('rpc_r2980_engineer_leaderboard'),
    supabase.rpc('rpc_r2980_color_code_breakdown'),
    supabase.rpc('rpc_r2980_hospital_risk_roster'),
    supabase.rpc('rpc_r2980_waste_category_mix'),
    supabase.rpc('rpc_r2980_cpcb_penalty_exposure'),
    supabase.rpc('rpc_r2980_training_impact'),
  ]);

  const monthlyRows: MonthlySummary[] = (monthly.data ?? []) as MonthlySummary[];
  const engineerRows: EngineerRow[] = (engineers.data ?? []) as EngineerRow[];
  const colorRows: ColorRow[] = (colors.data ?? []) as ColorRow[];
  const riskRows: RiskRow[] = (risk.data ?? []) as RiskRow[];
  const wasteRows: WasteRow[] = (waste.data ?? []) as WasteRow[];
  const penaltyRows: PenaltyRow[] = (penalty.data ?? []) as PenaltyRow[];
  const impactRows: ImpactRow[] = (impact.data ?? []) as ImpactRow[];

  const monthlyCols: Column<MonthlySummary>[] = [
    { header: 'Month', accessor: (r) => r.session_month },
    { header: 'Sessions', accessor: (r) => r.total_sessions },
    { header: 'Hospitals', accessor: (r) => r.hospitals_covered },
    { header: 'Avg Compliance %', accessor: (r) => r.avg_segregation_compliance },
    { header: 'CPCB Compliant', accessor: (r) => r.cpcb_compliant_count },
    { header: 'Escalated', accessor: (r) => r.escalated_count },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Sessions', accessor: (r) => r.sessions_initiated },
    { header: 'Staff Trained', accessor: (r) => r.staff_trained_total },
    { header: 'Avg Score Delta', accessor: (r) => r.avg_score_delta },
    { header: 'Avg Post Score', accessor: (r) => r.avg_post_score },
  ];

  const colorCols: Column<ColorRow>[] = [
    { header: 'Color Code', accessor: (r) => r.color_code },
    { header: 'Sessions', accessor: (r) => r.session_count },
    { header: 'Staff Trained', accessor: (r) => r.staff_trained },
    { header: 'Avg Compliance %', accessor: (r) => r.avg_compliance },
    { header: 'Compliant %', accessor: (r) => r.compliant_pct },
  ];

  const riskCols: Column<RiskRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Total Waste (kg)', accessor: (r) => r.total_waste_kg },
    { header: 'Mis-Segregation', accessor: (r) => r.mis_segregation_total },
    { header: 'Highest Risk', accessor: (r) => r.highest_risk },
    { header: 'Avg Rating', accessor: (r) => r.avg_rating },
    { header: 'Follow-up', accessor: (r) => r.follow_up_required ? 'Yes' : 'No' },
  ];

  const wasteCols: Column<WasteRow>[] = [
    { header: 'Waste Category', accessor: (r) => r.waste_category },
    { header: 'Sessions', accessor: (r) => r.sessions },
    { header: 'Avg Duration (min)', accessor: (r) => r.avg_duration_minutes },
    { header: 'Avg Post Score', accessor: (r) => r.avg_post_score },
  ];

  const penaltyCols: Column<PenaltyRow>[] = [
    { header: 'Penalty Risk', accessor: (r) => r.penalty_risk },
    { header: 'Hospitals', accessor: (r) => r.hospital_count },
    { header: 'Total Waste (kg)', accessor: (r) => r.total_waste_kg },
    { header: 'Follow-ups Open', accessor: (r) => r.follow_ups_open },
  ];

  const impactCols: Column<ImpactRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Pre Avg', accessor: (r) => r.pre_avg },
    { header: 'Post Avg', accessor: (r) => r.post_avg },
    { header: 'Delta', accessor: (r) => r.delta },
    { header: 'Staff Trained', accessor: (r) => r.staff_trained },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-10 space-y-10">
      <header>
        <h1 className="text-2xl font-semibold">Customer Monthly Engineer-Initiated Hospital BMW Color-Code Disposal Coaching</h1>
        <p className="text-sm text-neutral-600 mt-1">Round r2980 · engineer-led monthly coaching on CPCB BMW color-code segregation across hospital customers. Tracks pre/post training scores, segregation compliance &gt;= 85% target, and CPCB penalty exposure.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-3">Monthly Compliance Summary</h2>
        <DataTable rows={monthlyRows} columns={monthlyCols} emptyMessage="No monthly data yet" rowKey={(r,i)=>String(r.session_month ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Engineer Coaching Leaderboard</h2>
        <DataTable rows={engineerRows} columns={engineerCols} emptyMessage="No engineer coaching activity" rowKey={(r,i)=>String(r.engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Color-Code Breakdown (Yellow / Red / Blue / White / Black)</h2>
        <DataTable rows={colorRows} columns={colorCols} emptyMessage="No color-code data" rowKey={(r,i)=>String(r.color_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Hospital Risk Roster</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No risk data" rowKey={(r,i)=>String(r.hospital_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Waste Category Mix</h2>
        <DataTable rows={wasteRows} columns={wasteCols} emptyMessage="No waste category data" rowKey={(r,i)=>String(r.waste_category ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">CPCB Penalty Exposure</h2>
        <DataTable rows={penaltyRows} columns={penaltyCols} emptyMessage="No penalty exposure data" rowKey={(r,i)=>String(r.penalty_risk ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-3">Training Impact (Pre =&gt; Post)</h2>
        <DataTable rows={impactRows} columns={impactCols} emptyMessage="No impact data" rowKey={(r,i)=>String(r.hospital_name ?? i)} />
      </section>
    </main>
  );
}
