import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = { total_verifications: number; pass_count: number; fail_count: number; marginal_count: number; retest_count: number; remediation_open: number };
type FailureRow = { hospital_name: string; ot_room_code: string; zone_class: string; required_delta_pa: number; measured_delta_pa: number; deficit: number; visited_on: string };
type ZoneRow = { zone_class: string; n: number; pass_n: number; fail_n: number; avg_delta: number };
type HepaRow = { hospital_name: string; ot_room_code: string; hepa_age_months: number; status: string };
type RemRow = { action_kind: string; priority: string; status: string; n: number; total_cost: number };
type ScoreRow = { hospital_name: string; rooms: number; pass_n: number; fail_n: number; pass_pct: number | null };
type TrendRow = { visited_on: string; n: number; pass_n: number; fail_n: number };

export default async function Page() {
  const supabase = getSupabaseServerClient();

  const [summary, failures, byZone, hepa, queue, score, trend] = await Promise.all([
    supabase.rpc('founder_r2958_summary'),
    supabase.rpc('founder_r2958_failures'),
    supabase.rpc('founder_r2958_by_zone'),
    supabase.rpc('founder_r2958_hepa_risk'),
    supabase.rpc('founder_r2958_remediation_queue'),
    supabase.rpc('founder_r2958_hospital_scorecard'),
    supabase.rpc('founder_r2958_daily_trend'),
  ]);

  const summaryRows: SummaryRow[] = (summary.data as SummaryRow[]) ?? [];
  const failureRows: FailureRow[] = (failures.data as FailureRow[]) ?? [];
  const zoneRows: ZoneRow[] = (byZone.data as ZoneRow[]) ?? [];
  const hepaRows: HepaRow[] = (hepa.data as HepaRow[]) ?? [];
  const queueRows: RemRow[] = (queue.data as RemRow[]) ?? [];
  const scoreRows: ScoreRow[] = (score.data as ScoreRow[]) ?? [];
  const trendRows: TrendRow[] = (trend.data as TrendRow[]) ?? [];

  const summaryCols: Column<SummaryRow>[] = [
    { header: 'Total', accessor: (r) => r.total_verifications },
    { header: 'Pass', accessor: (r) => r.pass_count },
    { header: 'Fail', accessor: (r) => r.fail_count },
    { header: 'Marginal', accessor: (r) => r.marginal_count },
    { header: 'Retest', accessor: (r) => r.retest_count },
    { header: 'Open remediations', accessor: (r) => r.remediation_open },
  ];

  const failureCols: Column<FailureRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Room', accessor: (r) => r.ot_room_code },
    { header: 'Zone', accessor: (r) => r.zone_class },
    { header: 'Req Pa', accessor: (r) => r.required_delta_pa },
    { header: 'Meas Pa', accessor: (r) => r.measured_delta_pa },
    { header: 'Deficit', accessor: (r) => r.deficit },
    { header: 'Visited', accessor: (r) => r.visited_on },
  ];

  const zoneCols: Column<ZoneRow>[] = [
    { header: 'Zone', accessor: (r) => r.zone_class },
    { header: 'N', accessor: (r) => r.n },
    { header: 'Pass', accessor: (r) => r.pass_n },
    { header: 'Fail', accessor: (r) => r.fail_n },
    { header: 'Avg Pa', accessor: (r) => r.avg_delta },
  ];

  const hepaCols: Column<HepaRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Room', accessor: (r) => r.ot_room_code },
    { header: 'HEPA age (mo)', accessor: (r) => r.hepa_age_months },
    { header: 'Status', accessor: (r) => r.status },
  ];

  const queueCols: Column<RemRow>[] = [
    { header: 'Action', accessor: (r) => r.action_kind },
    { header: 'Priority', accessor: (r) => r.priority },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'N', accessor: (r) => r.n },
    { header: 'Total cost (₹)', accessor: (r) => r.total_cost },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Rooms', accessor: (r) => r.rooms },
    { header: 'Pass', accessor: (r) => r.pass_n },
    { header: 'Fail', accessor: (r) => r.fail_n },
    { header: 'Pass %', accessor: (r) => r.pass_pct ?? '—' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { header: 'Visited', accessor: (r) => r.visited_on },
    { header: 'N', accessor: (r) => r.n },
    { header: 'Pass', accessor: (r) => r.pass_n },
    { header: 'Fail', accessor: (r) => r.fail_n },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 28 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>OT Sterile-Zone Air-Pressure Differential Verification</h1>
        <p style={{ color: '#555' }}>Monthly engineer site visits — NABH HCSO clause compliance for ISO 5/6/7/8 rooms.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Summary</h2>
        <DataTable rows={summaryRows} columns={summaryCols} emptyMessage="No verifications yet" rowKey={(_r, i) => String(i)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Failures & marginals (deficit ranked)</h2>
        <DataTable rows={failureRows} columns={failureCols} emptyMessage="All rooms passing" rowKey={(r, i) => String(`${r.hospital_name}-${r.ot_room_code}-${i}`)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>By zone class</h2>
        <DataTable rows={zoneRows} columns={zoneCols} emptyMessage="No data" rowKey={(r) => r.zone_class} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>HEPA replacement risk (age &gt;= 18 months)</h2>
        <DataTable rows={hepaRows} columns={hepaCols} emptyMessage="All HEPA fresh" rowKey={(r, i) => String(`${r.hospital_name}-${r.ot_room_code}-${i}`)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Remediation queue</h2>
        <DataTable rows={queueRows} columns={queueCols} emptyMessage="No remediations" rowKey={(r, i) => String(`${r.action_kind}-${r.priority}-${r.status}-${i}`)} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Hospital scorecard</h2>
        <DataTable rows={scoreRows} columns={scoreCols} emptyMessage="No data" rowKey={(r) => r.hospital_name} />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Daily trend</h2>
        <DataTable rows={trendRows} columns={trendCols} emptyMessage="No data" rowKey={(r) => r.visited_on} />
      </section>
    </main>
  );
}
