import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type GradeRow = { discipline_grade: string; engineers_count: number; avg_capture_rate: number; avg_quality: number };
type MissingRow = { visit_date: string; visit_purpose: string; region: string; tier: string; signature_method: string; notes: string | null };
type RegionRow = { region: string; rollups: number; avg_capture_rate: number; avg_geo_verified_pct: number; coaching_count: number };
type MethodRow = { signature_method: string; visits: number; avg_quality: number | null; avg_lag_minutes: number | null };
type BonusRow = { cycle_month: string; total_rollups: number; bonus_eligible: number; coaching_required: number; bonus_rate_pct: number };
type LagRow = { p50_lag: number; p75_lag: number; p90_lag: number; p95_lag: number; worst_lag: number };
type TierRow = { tier: string; rollups: number; avg_capture_rate: number; avg_quality: number; bonus_pct: number };
type VisitRow = { visit_date: string; visit_purpose: string; region: string; tier: string; signature_captured: boolean; signature_quality_score: number | null; capture_lag_minutes: number | null; signatory_designation: string | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [grades, missing, regions, methods, bonus, lag, tiers, recent] = await Promise.all([
    supabase.rpc('founder_r2930_grade_distribution'),
    supabase.rpc('founder_r2930_missing_signatures'),
    supabase.rpc('founder_r2930_regional_scorecard'),
    supabase.rpc('founder_r2930_method_breakdown'),
    supabase.rpc('founder_r2930_bonus_funnel'),
    supabase.rpc('founder_r2930_lag_percentiles'),
    supabase.rpc('founder_r2930_tier_capture_curve'),
    supabase.rpc('founder_r2930_recent_visits'),
  ]);

  const gradeRows: GradeRow[] = (grades.data ?? []) as GradeRow[];
  const missingRows: MissingRow[] = (missing.data ?? []) as MissingRow[];
  const regionRows: RegionRow[] = (regions.data ?? []) as RegionRow[];
  const methodRows: MethodRow[] = (methods.data ?? []) as MethodRow[];
  const bonusRows: BonusRow[] = (bonus.data ?? []) as BonusRow[];
  const lagRows: LagRow[] = (lag.data ?? []) as LagRow[];
  const tierRows: TierRow[] = (tiers.data ?? []) as TierRow[];
  const recentRows: VisitRow[] = (recent.data ?? []) as VisitRow[];

  const gradeCols: Column<GradeRow>[] = [
    { key: 'discipline_grade', header: 'Grade', render: (r) => r.discipline_grade },
    { key: 'engineers_count', header: 'Engineers', render: (r) => r.engineers_count },
    { key: 'avg_capture_rate', header: 'Avg capture %', render: (r) => r.avg_capture_rate },
    { key: 'avg_quality', header: 'Avg quality', render: (r) => r.avg_quality },
  ];

  const missingCols: Column<MissingRow>[] = [
    { key: 'visit_date', header: 'Visit date', render: (r) => r.visit_date },
    { key: 'visit_purpose', header: 'Purpose', render: (r) => r.visit_purpose },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
    { key: 'signature_method', header: 'Method', render: (r) => r.signature_method },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '-' },
  ];

  const regionCols: Column<RegionRow>[] = [
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'rollups', header: 'Rollups', render: (r) => r.rollups },
    { key: 'avg_capture_rate', header: 'Avg capture %', render: (r) => r.avg_capture_rate },
    { key: 'avg_geo_verified_pct', header: 'Geo verified %', render: (r) => r.avg_geo_verified_pct },
    { key: 'coaching_count', header: 'Coaching needed', render: (r) => r.coaching_count },
  ];

  const methodCols: Column<MethodRow>[] = [
    { key: 'signature_method', header: 'Method', render: (r) => r.signature_method },
    { key: 'visits', header: 'Visits', render: (r) => r.visits },
    { key: 'avg_quality', header: 'Avg quality', render: (r) => r.avg_quality ?? '-' },
    { key: 'avg_lag_minutes', header: 'Avg lag (min)', render: (r) => r.avg_lag_minutes ?? '-' },
  ];

  const bonusCols: Column<BonusRow>[] = [
    { key: 'cycle_month', header: 'Cycle month', render: (r) => r.cycle_month },
    { key: 'total_rollups', header: 'Rollups', render: (r) => r.total_rollups },
    { key: 'bonus_eligible', header: 'Bonus eligible', render: (r) => r.bonus_eligible },
    { key: 'coaching_required', header: 'Coaching req', render: (r) => r.coaching_required },
    { key: 'bonus_rate_pct', header: 'Bonus rate %', render: (r) => r.bonus_rate_pct },
  ];

  const lagCols: Column<LagRow>[] = [
    { key: 'p50_lag', header: 'p50', render: (r) => r.p50_lag },
    { key: 'p75_lag', header: 'p75', render: (r) => r.p75_lag },
    { key: 'p90_lag', header: 'p90', render: (r) => r.p90_lag },
    { key: 'p95_lag', header: 'p95', render: (r) => r.p95_lag },
    { key: 'worst_lag', header: 'Worst (min)', render: (r) => r.worst_lag },
  ];

  const tierCols: Column<TierRow>[] = [
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
    { key: 'rollups', header: 'Rollups', render: (r) => r.rollups },
    { key: 'avg_capture_rate', header: 'Avg capture %', render: (r) => r.avg_capture_rate },
    { key: 'avg_quality', header: 'Avg quality', render: (r) => r.avg_quality },
    { key: 'bonus_pct', header: 'Bonus %', render: (r) => r.bonus_pct },
  ];

  const recentCols: Column<VisitRow>[] = [
    { key: 'visit_date', header: 'Visit date', render: (r) => r.visit_date },
    { key: 'visit_purpose', header: 'Purpose', render: (r) => r.visit_purpose },
    { key: 'region', header: 'Region', render: (r) => r.region },
    { key: 'tier', header: 'Tier', render: (r) => r.tier },
    { key: 'signature_captured', header: 'Captured', render: (r) => (r.signature_captured ? 'yes' : 'no') },
    { key: 'signature_quality_score', header: 'Quality', render: (r) => r.signature_quality_score ?? '-' },
    { key: 'capture_lag_minutes', header: 'Lag (min)', render: (r) => r.capture_lag_minutes ?? '-' },
    { key: 'signatory_designation', header: 'Signatory role', render: (r) => r.signatory_designation ?? '-' },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Engineer Monthly Customer Site Visitor-Log Signature Capture Discipline
      </h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Round 2930 — signature capture rates, missing-sig audit, regional scorecards &amp; lag percentiles.
        Captures &gt;= 95% earn bonus; &lt;= 75% trigger coaching.
      </p>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Discipline grade distribution</h2>
        <DataTable rows={gradeRows} columns={gradeCols} emptyMessage="No rollups yet" rowKey={(r, i) => String((r as GradeRow).discipline_grade ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Visits missing signatures</h2>
        <DataTable rows={missingRows} columns={missingCols} emptyMessage="No gaps" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Regional scorecard</h2>
        <DataTable rows={regionRows} columns={regionCols} emptyMessage="No regions" rowKey={(r, i) => String((r as RegionRow).region ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Signature method breakdown</h2>
        <DataTable rows={methodRows} columns={methodCols} emptyMessage="No methods" rowKey={(r, i) => String((r as MethodRow).signature_method ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Bonus eligibility funnel</h2>
        <DataTable rows={bonusRows} columns={bonusCols} emptyMessage="No cycles" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Capture lag percentiles</h2>
        <DataTable rows={lagRows} columns={lagCols} emptyMessage="No data" rowKey={(r, i) => String(i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Tier vs capture curve</h2>
        <DataTable rows={tierRows} columns={tierCols} emptyMessage="No tiers" rowKey={(r, i) => String((r as TierRow).tier ?? i)} />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Recent visits (30)</h2>
        <DataTable rows={recentRows} columns={recentCols} emptyMessage="No visits" rowKey={(r, i) => String(i)} />
      </section>
    </main>
  );
}
