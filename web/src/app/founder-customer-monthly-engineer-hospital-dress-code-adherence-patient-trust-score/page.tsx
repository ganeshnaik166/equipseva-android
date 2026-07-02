import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type MonthlyOverview = { audit_month: string; total_audits: number; exemplary_count: number; pass_count: number; warn_count: number; fail_count: number; avg_adherence: number };
type TopEngineer = { engineer_name: string; hospital_name: string; city: string; adherence_pct: number; audit_outcome: string };
type FailingEngineer = { engineer_name: string; hospital_name: string; city: string; adherence_pct: number; notes: string | null };
type TrustBand = { score_month: string; low_band: number; medium_band: number; high_band: number; elite_band: number; avg_trust: number };
type FollowUp = { hospital_name: string; city: string; avg_trust_score: number; negative_comments: number; nps_score: number; trust_band: string };
type CityRow = { city: string; hospital_count: number; avg_adherence: number; avg_trust: number; total_patients: number };
type Correlation = { hospital_name: string; city: string; adherence_pct: number; trust_score: number; nps_score: number; dress_mentions: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [overview, top, failing, bands, followUp, cities, correlation] = await Promise.all([
    supabase.rpc('r2960_monthly_adherence_overview'),
    supabase.rpc('r2960_top_engineers_current'),
    supabase.rpc('r2960_failing_engineers'),
    supabase.rpc('r2960_trust_band_distribution'),
    supabase.rpc('r2960_hospitals_needing_follow_up'),
    supabase.rpc('r2960_city_breakdown'),
    supabase.rpc('r2960_dress_code_correlation'),
  ]);

  const overviewRows: MonthlyOverview[] = (overview.data as MonthlyOverview[]) ?? [];
  const topRows: TopEngineer[] = (top.data as TopEngineer[]) ?? [];
  const failingRows: FailingEngineer[] = (failing.data as FailingEngineer[]) ?? [];
  const bandRows: TrustBand[] = (bands.data as TrustBand[]) ?? [];
  const followUpRows: FollowUp[] = (followUp.data as FollowUp[]) ?? [];
  const cityRows: CityRow[] = (cities.data as CityRow[]) ?? [];
  const correlationRows: Correlation[] = (correlation.data as Correlation[]) ?? [];

  const overviewCols: Column<MonthlyOverview>[] = [
    { header: 'Month', accessor: (r) => r.audit_month },
    { header: 'Audits', accessor: (r) => r.total_audits },
    { header: 'Exemplary', accessor: (r) => r.exemplary_count },
    { header: 'Pass', accessor: (r) => r.pass_count },
    { header: 'Warn', accessor: (r) => r.warn_count },
    { header: 'Fail', accessor: (r) => r.fail_count },
    { header: 'Avg Adherence %', accessor: (r) => r.avg_adherence },
  ];
  const topCols: Column<TopEngineer>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Adherence %', accessor: (r) => r.adherence_pct },
    { header: 'Outcome', accessor: (r) => r.audit_outcome },
  ];
  const failingCols: Column<FailingEngineer>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Adherence %', accessor: (r) => r.adherence_pct },
    { header: 'Notes', accessor: (r) => r.notes ?? '-' },
  ];
  const bandCols: Column<TrustBand>[] = [
    { header: 'Month', accessor: (r) => r.score_month },
    { header: 'Low', accessor: (r) => r.low_band },
    { header: 'Medium', accessor: (r) => r.medium_band },
    { header: 'High', accessor: (r) => r.high_band },
    { header: 'Elite', accessor: (r) => r.elite_band },
    { header: 'Avg Trust', accessor: (r) => r.avg_trust },
  ];
  const followUpCols: Column<FollowUp>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Trust Score', accessor: (r) => r.avg_trust_score },
    { header: 'Negatives', accessor: (r) => r.negative_comments },
    { header: 'NPS', accessor: (r) => r.nps_score },
    { header: 'Band', accessor: (r) => r.trust_band },
  ];
  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (r) => r.city },
    { header: 'Hospitals', accessor: (r) => r.hospital_count },
    { header: 'Avg Adherence', accessor: (r) => r.avg_adherence },
    { header: 'Avg Trust', accessor: (r) => r.avg_trust },
    { header: 'Patients', accessor: (r) => r.total_patients },
  ];
  const correlationCols: Column<Correlation>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Adherence %', accessor: (r) => r.adherence_pct },
    { header: 'Trust Score', accessor: (r) => r.trust_score },
    { header: 'NPS', accessor: (r) => r.nps_score },
    { header: 'Dress Mentions', accessor: (r) => r.dress_mentions },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Dress Code Adherence & Patient Trust</h1>
        <p className="text-sm text-gray-600">Round r2960 — Monthly hospital uniform audits paired with patient trust signals.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Adherence Overview</h2>
        <DataTable rows={overviewRows} columns={overviewCols} emptyMessage="No audits yet" rowKey={(r, i) => String(r.audit_month ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Engineers (Current Month)</h2>
        <DataTable rows={topRows} columns={topCols} emptyMessage="No top engineers" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Failing Engineers (Warn & Fail)</h2>
        <DataTable rows={failingRows} columns={failingCols} emptyMessage="No failing engineers" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Patient Trust Band Distribution</h2>
        <DataTable rows={bandRows} columns={bandCols} emptyMessage="No trust data" rowKey={(r, i) => String(r.score_month ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Hospitals Needing Follow-up</h2>
        <DataTable rows={followUpRows} columns={followUpCols} emptyMessage="No follow-ups required" rowKey={(r, i) => String(i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City Breakdown</h2>
        <DataTable rows={cityRows} columns={cityCols} emptyMessage="No city data" rowKey={(r, i) => String(r.city ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Dress Code & Trust Correlation</h2>
        <DataTable rows={correlationRows} columns={correlationCols} emptyMessage="No correlation data" rowKey={(r, i) => String(i)} />
      </section>
    </div>
  );
}
