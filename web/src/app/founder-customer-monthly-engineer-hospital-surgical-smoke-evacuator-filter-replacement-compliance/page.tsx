import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type Summary = {
  total_replacements: number;
  on_time_count: number;
  late_count: number;
  missed_count: number;
  upcoming_count: number;
  compliance_pct: number | null;
  total_cost_rupees: number;
};

type CityRow = {
  hospital_city: string;
  filters_due: number;
  on_time: number;
  late: number;
  missed: number;
  compliance_pct: number | null;
};

type OverdueRow = {
  hospital_name: string;
  ot_room_label: string;
  evacuator_unit_serial: string;
  filter_type: string;
  scheduled_for: string;
  delay_days: number;
  compliance_status: string;
};

type EngineerRow = {
  engineer_name: string;
  completed: number;
  on_time: number;
  late: number;
  on_time_pct: number | null;
  avg_saturation: number | null;
};

type FilterMixRow = {
  filter_type: string;
  swaps: number;
  avg_hours_used: number | null;
  avg_saturation: number | null;
  total_cost_rupees: number;
};

type ScorecardRow = {
  hospital_name: string;
  hospital_city: string;
  scorecard_month: string;
  total_filters_due: number;
  on_time_count: number;
  late_count: number;
  missed_count: number;
  compliance_pct: number;
  tier_label: string;
  amc_status: string;
};

type WatchlistRow = {
  hospital_name: string;
  hospital_city: string;
  tier_label: string;
  amc_status: string;
  compliance_pct: number;
  avg_delay_days: number;
  missed_count: number;
  monthly_fee_rupees: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summaryRes, cityRes, overdueRes, engineerRes, mixRes, scoreRes, watchRes] = await Promise.all([
    supabase.rpc('r3028_portfolio_summary'),
    supabase.rpc('r3028_city_breakdown'),
    supabase.rpc('r3028_overdue_queue'),
    supabase.rpc('r3028_engineer_leaderboard'),
    supabase.rpc('r3028_filter_type_mix'),
    supabase.rpc('r3028_hospital_scorecard_latest'),
    supabase.rpc('r3028_watchlist_hospitals'),
  ]);

  const summary: Summary | null = (summaryRes.data?.[0] ?? null) as Summary | null;
  const cityRows: CityRow[] = (cityRes.data ?? []) as CityRow[];
  const overdueRows: OverdueRow[] = (overdueRes.data ?? []) as OverdueRow[];
  const engineerRows: EngineerRow[] = (engineerRes.data ?? []) as EngineerRow[];
  const mixRows: FilterMixRow[] = (mixRes.data ?? []) as FilterMixRow[];
  const scoreRows: ScorecardRow[] = (scoreRes.data ?? []) as ScorecardRow[];
  const watchRows: WatchlistRow[] = (watchRes.data ?? []) as WatchlistRow[];

  const cityCols: Column<CityRow>[] = [
    { header: 'City', accessor: (r) => r.hospital_city },
    { header: 'Filters Due', accessor: (r) => r.filters_due },
    { header: 'On Time', accessor: (r) => r.on_time },
    { header: 'Late', accessor: (r) => r.late },
    { header: 'Missed', accessor: (r) => r.missed },
    { header: 'Compliance %', accessor: (r) => (r.compliance_pct ?? 0) + '%' },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'OT', accessor: (r) => r.ot_room_label },
    { header: 'Unit', accessor: (r) => r.evacuator_unit_serial },
    { header: 'Filter', accessor: (r) => r.filter_type },
    { header: 'Due', accessor: (r) => r.scheduled_for },
    { header: 'Delay (d)', accessor: (r) => r.delay_days },
    { header: 'Status', accessor: (r) => r.compliance_status },
  ];

  const engineerCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Completed', accessor: (r) => r.completed },
    { header: 'On Time', accessor: (r) => r.on_time },
    { header: 'Late', accessor: (r) => r.late },
    { header: 'On-time %', accessor: (r) => (r.on_time_pct ?? 0) + '%' },
    { header: 'Avg Saturation %', accessor: (r) => r.avg_saturation ?? '-' },
  ];

  const mixCols: Column<FilterMixRow>[] = [
    { header: 'Filter Type', accessor: (r) => r.filter_type },
    { header: 'Swaps', accessor: (r) => r.swaps },
    { header: 'Avg Hours', accessor: (r) => r.avg_hours_used ?? '-' },
    { header: 'Avg Saturation %', accessor: (r) => r.avg_saturation ?? '-' },
    { header: 'Cost (Rs)', accessor: (r) => r.total_cost_rupees.toLocaleString() },
  ];

  const scoreCols: Column<ScorecardRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.hospital_city },
    { header: 'Month', accessor: (r) => r.scorecard_month },
    { header: 'Due', accessor: (r) => r.total_filters_due },
    { header: 'On Time', accessor: (r) => r.on_time_count },
    { header: 'Late', accessor: (r) => r.late_count },
    { header: 'Missed', accessor: (r) => r.missed_count },
    { header: 'Compliance %', accessor: (r) => r.compliance_pct + '%' },
    { header: 'Tier', accessor: (r) => r.tier_label },
    { header: 'AMC', accessor: (r) => r.amc_status },
  ];

  const watchCols: Column<WatchlistRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'City', accessor: (r) => r.hospital_city },
    { header: 'Tier', accessor: (r) => r.tier_label },
    { header: 'AMC', accessor: (r) => r.amc_status },
    { header: 'Compliance %', accessor: (r) => r.compliance_pct + '%' },
    { header: 'Avg Delay (d)', accessor: (r) => r.avg_delay_days },
    { header: 'Missed', accessor: (r) => r.missed_count },
    { header: 'Fee (Rs)', accessor: (r) => r.monthly_fee_rupees.toLocaleString() },
    { header: 'Notes', accessor: (r) => r.notes ?? '-' },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 22, fontWeight: 700 }}>
        Surgical Smoke-Evacuator Filter Replacement Compliance — r3028
      </h1>
      <p style={{ color: '#555', marginTop: 4 }}>
        Monthly engineer-driven hospital OT filter swap tracking — on-time vs late vs missed.
      </p>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>Portfolio summary</h2>
        {summary ? (
          <ul style={{ marginTop: 8, lineHeight: 1.7 }}>
            <li>Total replacements tracked: {summary.total_replacements}</li>
            <li>On time: {summary.on_time_count}</li>
            <li>Late: {summary.late_count}</li>
            <li>Missed: {summary.missed_count}</li>
            <li>Upcoming: {summary.upcoming_count}</li>
            <li>Compliance: {summary.compliance_pct ?? 0}%</li>
            <li>Total filter cost: Rs {Number(summary.total_cost_rupees).toLocaleString()}</li>
          </ul>
        ) : (
          <p>No summary data.</p>
        )}
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>City breakdown</h2>
        <DataTable
          rows={cityRows}
          columns={cityCols}
          emptyMessage="No city data"
          rowKey={(r, i) => String((r as { hospital_city?: string }).hospital_city ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>Overdue / late queue</h2>
        <DataTable
          rows={overdueRows}
          columns={overdueCols}
          emptyMessage="No overdue swaps"
          rowKey={(r, i) => String((r as { evacuator_unit_serial?: string }).evacuator_unit_serial ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>Engineer leaderboard</h2>
        <DataTable
          rows={engineerRows}
          columns={engineerCols}
          emptyMessage="No engineer data"
          rowKey={(r, i) => String((r as { engineer_name?: string }).engineer_name ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>Filter type mix</h2>
        <DataTable
          rows={mixRows}
          columns={mixCols}
          emptyMessage="No filter mix data"
          rowKey={(r, i) => String((r as { filter_type?: string }).filter_type ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>Hospital scorecard (latest month)</h2>
        <DataTable
          rows={scoreRows}
          columns={scoreCols}
          emptyMessage="No scorecard data"
          rowKey={(r, i) => String((r as { hospital_name?: string }).hospital_name ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>Watchlist hospitals</h2>
        <DataTable
          rows={watchRows}
          columns={watchCols}
          emptyMessage="No watchlist hospitals"
          rowKey={(r, i) => String((r as { hospital_name?: string }).hospital_name ?? i)}
        />
      </section>
    </main>
  );
}
