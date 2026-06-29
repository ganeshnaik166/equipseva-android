import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = { metric: string; value: number };
type EngineerRow = { engineer_name: string; briefings: number; on_time: number; avg_quality: number; total_risks: number };
type TierRow = { risk_tier: string; briefings: number; completed_on_time: number; avg_duration: number; avg_quality: number };
type CategoryRow = { equipment_category: string; briefings: number; risks_flagged: number; parts_prepped: number; avg_quality: number };
type GradeRow = { discipline_grade: string; engineers: number; avg_csat: number; total_incidents_avoided: number; coaching_needed: number };
type SkippedRow = { engineer_name: string; hospital_name: string; equipment_category: string; risk_tier: string; briefing_status: string };
type CoachingRow = { engineer_name: string; briefings_on_time: number; briefings_total: number; discipline_grade: string; customer_csat_avg: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [summary, engineers, tiers, categories, grades, skipped, coaching] = await Promise.all([
    supabase.rpc('rpc_r2950_discipline_summary'),
    supabase.rpc('rpc_r2950_by_engineer'),
    supabase.rpc('rpc_r2950_by_risk_tier'),
    supabase.rpc('rpc_r2950_by_equipment_category'),
    supabase.rpc('rpc_r2950_outcomes_grade'),
    supabase.rpc('rpc_r2950_skipped_briefings'),
    supabase.rpc('rpc_r2950_coaching_roster'),
  ]);

  const sumRows: SummaryRow[] = (summary.data as SummaryRow[]) ?? [];
  const engRows: EngineerRow[] = (engineers.data as EngineerRow[]) ?? [];
  const tierRows: TierRow[] = (tiers.data as TierRow[]) ?? [];
  const catRows: CategoryRow[] = (categories.data as CategoryRow[]) ?? [];
  const gradeRows: GradeRow[] = (grades.data as GradeRow[]) ?? [];
  const skippedRows: SkippedRow[] = (skipped.data as SkippedRow[]) ?? [];
  const coachingRows: CoachingRow[] = (coaching.data as CoachingRow[]) ?? [];

  const sumCols: Column<SummaryRow>[] = [
    { header: 'Metric', accessor: (r) => r.metric },
    { header: 'Value', accessor: (r) => r.value },
  ];
  const engCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Briefings', accessor: (r) => r.briefings },
    { header: 'On Time', accessor: (r) => r.on_time },
    { header: 'Avg Quality', accessor: (r) => r.avg_quality },
    { header: 'Risks Flagged', accessor: (r) => r.total_risks },
  ];
  const tierCols: Column<TierRow>[] = [
    { header: 'Risk Tier', accessor: (r) => r.risk_tier },
    { header: 'Briefings', accessor: (r) => r.briefings },
    { header: 'On Time', accessor: (r) => r.completed_on_time },
    { header: 'Avg Duration (min)', accessor: (r) => r.avg_duration },
    { header: 'Avg Quality', accessor: (r) => r.avg_quality },
  ];
  const catCols: Column<CategoryRow>[] = [
    { header: 'Equipment', accessor: (r) => r.equipment_category },
    { header: 'Briefings', accessor: (r) => r.briefings },
    { header: 'Risks', accessor: (r) => r.risks_flagged },
    { header: 'Parts Prepped', accessor: (r) => r.parts_prepped },
    { header: 'Avg Quality', accessor: (r) => r.avg_quality },
  ];
  const gradeCols: Column<GradeRow>[] = [
    { header: 'Grade', accessor: (r) => r.discipline_grade },
    { header: 'Engineers', accessor: (r) => r.engineers },
    { header: 'Avg CSAT', accessor: (r) => r.avg_csat },
    { header: 'Incidents Avoided', accessor: (r) => r.total_incidents_avoided },
    { header: 'Coaching Needed', accessor: (r) => r.coaching_needed },
  ];
  const skippedCols: Column<SkippedRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Equipment', accessor: (r) => r.equipment_category },
    { header: 'Risk', accessor: (r) => r.risk_tier },
    { header: 'Status', accessor: (r) => r.briefing_status },
  ];
  const coachingCols: Column<CoachingRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'On Time', accessor: (r) => r.briefings_on_time },
    { header: 'Total', accessor: (r) => r.briefings_total },
    { header: 'Grade', accessor: (r) => r.discipline_grade },
    { header: 'CSAT', accessor: (r) => r.customer_csat_avg },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1>Engineer Monthly Pre-Visit Risk Briefing Discipline</h1>
        <p>Round r2950 — track whether engineers run pre-visit equipment risk briefings before every customer site visit.</p>
      </header>

      <section>
        <h2>Discipline Summary</h2>
        <DataTable<SummaryRow> rows={sumRows} columns={sumCols} emptyMessage="No summary" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2>By Engineer</h2>
        <DataTable<EngineerRow> rows={engRows} columns={engCols} emptyMessage="No engineers" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2>By Risk Tier</h2>
        <DataTable<TierRow> rows={tierRows} columns={tierCols} emptyMessage="No tiers" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2>By Equipment Category</h2>
        <DataTable<CategoryRow> rows={catRows} columns={catCols} emptyMessage="No categories" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2>Outcomes by Grade</h2>
        <DataTable<GradeRow> rows={gradeRows} columns={gradeCols} emptyMessage="No grades" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2>Skipped & Pending Briefings</h2>
        <DataTable<SkippedRow> rows={skippedRows} columns={skippedCols} emptyMessage="None skipped" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2>Coaching Roster</h2>
        <DataTable<CoachingRow> rows={coachingRows} columns={coachingCols} emptyMessage="No coaching needed" rowKey={(r, i) => String(i)} />
      </section>
    </main>
  );
}
