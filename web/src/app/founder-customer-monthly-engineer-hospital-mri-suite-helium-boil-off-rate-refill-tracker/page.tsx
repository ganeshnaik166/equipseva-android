import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type FleetRow = {
  suite_code: string;
  scanner_model: string;
  field_strength_tesla: number;
  latest_helium_pct: number;
  latest_boiloff_pct: number;
  latest_risk_band: string;
  latest_reading_month: string;
};

type RiskRow = {
  quench_risk_band: string;
  reading_count: number;
  avg_helium_pct: number;
  avg_boiloff_pct: number;
};

type TrendRow = {
  reading_month: string;
  total_readings: number;
  red_count: number;
  critical_count: number;
  avg_boiloff_pct: number;
};

type VendorRow = {
  vendor_name: string;
  refill_count: number;
  total_litres: number;
  total_spend_inr: number;
  avg_price_per_litre: number;
};

type EngineerRow = {
  engineer_display_name: string;
  completed_refills: number;
  failed_refills: number;
  avg_sat_rating: number | null;
  avg_downtime_hours: number | null;
};

type CriticalRow = {
  suite_code: string;
  scanner_model: string;
  helium_level_pct: number;
  boiloff_rate_pct_per_month: number;
  reading_status: string;
  reading_month: string;
  notes: string | null;
};

type UpcomingRow = {
  suite_code: string;
  engineer_display_name: string;
  refill_status: string;
  litres_delivered: number;
  total_cost_inr: number;
  scheduled_at: string;
  vendor_name: string;
};

type KpiRow = {
  total_suites: number;
  red_or_critical_suites: number;
  ytd_refill_spend_inr: number;
  total_litres_delivered: number;
  avg_boiloff_pct: number;
  scheduled_refills: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [fleet, risk, trend, vendor, eng, crit, upcoming, kpi] = await Promise.all([
    sb.rpc('fn_r3020_fleet_summary'),
    sb.rpc('fn_r3020_risk_distribution'),
    sb.rpc('fn_r3020_monthly_trend'),
    sb.rpc('fn_r3020_vendor_spend'),
    sb.rpc('fn_r3020_engineer_leaderboard'),
    sb.rpc('fn_r3020_critical_suites'),
    sb.rpc('fn_r3020_upcoming_refills'),
    sb.rpc('fn_r3020_kpi_headline'),
  ]);

  const fleetRows: FleetRow[] = (fleet.data as FleetRow[]) ?? [];
  const riskRows: RiskRow[] = (risk.data as RiskRow[]) ?? [];
  const trendRows: TrendRow[] = (trend.data as TrendRow[]) ?? [];
  const vendorRows: VendorRow[] = (vendor.data as VendorRow[]) ?? [];
  const engRows: EngineerRow[] = (eng.data as EngineerRow[]) ?? [];
  const critRows: CriticalRow[] = (crit.data as CriticalRow[]) ?? [];
  const upcomingRows: UpcomingRow[] = (upcoming.data as UpcomingRow[]) ?? [];
  const kpiRows: KpiRow[] = (kpi.data as KpiRow[]) ?? [];
  const k = kpiRows[0];

  const fleetCols: Column<FleetRow>[] = [
    { key: 'suite_code', header: 'Suite' },
    { key: 'scanner_model', header: 'Scanner' },
    { key: 'field_strength_tesla', header: 'Tesla', render: (r) => `${r.field_strength_tesla}T` },
    { key: 'latest_helium_pct', header: 'He %' },
    { key: 'latest_boiloff_pct', header: 'Boil-off %/mo' },
    { key: 'latest_risk_band', header: 'Risk' },
    { key: 'latest_reading_month', header: 'Month' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'quench_risk_band', header: 'Band' },
    { key: 'reading_count', header: 'Readings' },
    { key: 'avg_helium_pct', header: 'Avg He %' },
    { key: 'avg_boiloff_pct', header: 'Avg Boil-off %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'reading_month', header: 'Month' },
    { key: 'total_readings', header: 'Total' },
    { key: 'red_count', header: 'Red' },
    { key: 'critical_count', header: 'Critical' },
    { key: 'avg_boiloff_pct', header: 'Avg Boil-off %' },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { key: 'vendor_name', header: 'Vendor' },
    { key: 'refill_count', header: 'Refills' },
    { key: 'total_litres', header: 'Litres' },
    { key: 'total_spend_inr', header: 'Spend ₹' },
    { key: 'avg_price_per_litre', header: 'Avg ₹/L' },
  ];

  const engCols: Column<EngineerRow>[] = [
    { key: 'engineer_display_name', header: 'Engineer' },
    { key: 'completed_refills', header: 'Completed' },
    { key: 'failed_refills', header: 'Failed' },
    { key: 'avg_sat_rating', header: 'CSAT' },
    { key: 'avg_downtime_hours', header: 'Avg Downtime h' },
  ];

  const critCols: Column<CriticalRow>[] = [
    { key: 'suite_code', header: 'Suite' },
    { key: 'scanner_model', header: 'Scanner' },
    { key: 'helium_level_pct', header: 'He %' },
    { key: 'boiloff_rate_pct_per_month', header: 'Boil-off %' },
    { key: 'reading_status', header: 'Status' },
    { key: 'reading_month', header: 'Month' },
    { key: 'notes', header: 'Notes' },
  ];

  const upcomingCols: Column<UpcomingRow>[] = [
    { key: 'suite_code', header: 'Suite' },
    { key: 'engineer_display_name', header: 'Engineer' },
    { key: 'refill_status', header: 'Status' },
    { key: 'litres_delivered', header: 'Litres' },
    { key: 'total_cost_inr', header: 'Cost ₹' },
    { key: 'scheduled_at', header: 'Scheduled' },
    { key: 'vendor_name', header: 'Vendor' },
  ];

  return (
    <div className="p-6 space-y-6">
      <h1 className="text-2xl font-bold">MRI Suite Helium Boil-Off Rate &amp; Refill Tracker</h1>
      <p className="text-sm text-gray-600">
        Monthly cryogen telemetry across hospital MRI fleet. Quench risk &gt;= red triggers vendor review.
      </p>

      {k && (
        <div className="grid grid-cols-2 md:grid-cols-6 gap-3">
          <div className="p-3 border rounded">
            <div className="text-xs text-gray-500">Suites</div>
            <div className="text-xl font-semibold">{k.total_suites}</div>
          </div>
          <div className="p-3 border rounded">
            <div className="text-xs text-gray-500">Red/Critical</div>
            <div className="text-xl font-semibold">{k.red_or_critical_suites}</div>
          </div>
          <div className="p-3 border rounded">
            <div className="text-xs text-gray-500">YTD Spend ₹</div>
            <div className="text-xl font-semibold">{k.ytd_refill_spend_inr}</div>
          </div>
          <div className="p-3 border rounded">
            <div className="text-xs text-gray-500">Litres Delivered</div>
            <div className="text-xl font-semibold">{k.total_litres_delivered}</div>
          </div>
          <div className="p-3 border rounded">
            <div className="text-xs text-gray-500">Avg Boil-off %</div>
            <div className="text-xl font-semibold">{k.avg_boiloff_pct}</div>
          </div>
          <div className="p-3 border rounded">
            <div className="text-xs text-gray-500">Scheduled Refills</div>
            <div className="text-xl font-semibold">{k.scheduled_refills}</div>
          </div>
        </div>
      )}

      <section>
        <h2 className="text-lg font-semibold mb-2">Fleet Summary (latest reading per suite)</h2>
        <DataTable
          rows={fleetRows}
          columns={fleetCols}
          emptyMessage="No fleet data"
          rowKey={(r, i) => String(r.suite_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quench Risk Distribution</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No risk data"
          rowKey={(r, i) => String(r.quench_risk_band ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Boil-Off Trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r, i) => String(r.reading_month ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Helium Vendor Spend (completed refills)</h2>
        <DataTable
          rows={vendorRows}
          columns={vendorCols}
          emptyMessage="No vendor data"
          rowKey={(r, i) => String(r.vendor_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Leaderboard</h2>
        <DataTable
          rows={engRows}
          columns={engCols}
          emptyMessage="No engineer data"
          rowKey={(r, i) => String(r.engineer_display_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical Suites (helium &lt;= threshold)</h2>
        <DataTable
          rows={critRows}
          columns={critCols}
          emptyMessage="No critical suites"
          rowKey={(r, i) => String(`${r.suite_code}-${r.reading_month}` ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming & In-Progress Refills</h2>
        <DataTable
          rows={upcomingRows}
          columns={upcomingCols}
          emptyMessage="No upcoming refills"
          rowKey={(r, i) => String(`${r.suite_code}-${r.scheduled_at}` ?? i)}
        />
      </section>
    </div>
  );
}
