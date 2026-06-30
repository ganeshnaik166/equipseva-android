import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { status: string; contract_count: number; total_acv_rupees: number; avg_margin_pct: number; avg_yoy_delta_pct: number };
type OemRow = { robot_oem: string; contract_count: number; total_royalty_rupees: number; total_parts_cost_rupees: number; avg_margin_pct: number; critical_count: number };
type TrendRow = { event_month: string; total_pressure_rupees: number; total_recovered_rupees: number; net_pressure_rupees: number; event_count: number };
type HotRow = { contract_code: string; hospital_name: string; robot_model: string; acv_rupees: number; gross_margin_pct: number; yoy_margin_delta_pct: number; renewal_due_on: string; renewal_risk: string; status: string };
type LeverRow = { pricing_lever: string; event_count: number; total_pressure_rupees: number; total_recovered_rupees: number; recovery_pct: number };
type ScoreRow = { robot_model: string; contract_count: number; total_acv_rupees: number; avg_labor_hours: number; avg_margin_pct: number; worst_yoy_delta_pct: number };
type QueueRow = { contract_code: string; hospital_name: string; hospital_city: string; robot_model: string; renewal_due_on: string; days_to_renewal: number; renewal_risk: string; acv_rupees: number };
type SevRow = { event_type: string; pressure_severity: string; event_count: number; total_pressure_rupees: number };
type CityRow = { hospital_city: string; contract_count: number; total_acv_rupees: number; avg_margin_pct: number; net_pressure_rupees: number };

const fmtINR = (n: number | null | undefined) => {
  const v = Number(n ?? 0);
  if (v >= 10000000) return '₹' + (v / 10000000).toFixed(2) + ' Cr';
  if (v >= 100000) return '₹' + (v / 100000).toFixed(2) + ' L';
  return '₹' + v.toLocaleString('en-IN');
};
const fmtPct = (n: number | null | undefined) => (Number(n ?? 0)).toFixed(2) + '%';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [statusRes, oemRes, trendRes, hotRes, leverRes, scoreRes, queueRes, sevRes, cityRes] = await Promise.all([
    supabase.rpc('rpc_r3095_status_summary'),
    supabase.rpc('rpc_r3095_oem_breakdown'),
    supabase.rpc('rpc_r3095_monthly_pressure_trend'),
    supabase.rpc('rpc_r3095_at_risk_hotlist'),
    supabase.rpc('rpc_r3095_lever_effectiveness'),
    supabase.rpc('rpc_r3095_robot_model_scorecard'),
    supabase.rpc('rpc_r3095_renewal_queue'),
    supabase.rpc('rpc_r3095_event_severity_breakdown'),
    supabase.rpc('rpc_r3095_city_pressure'),
  ]);

  const status: StatusRow[] = (statusRes.data ?? []) as StatusRow[];
  const oem: OemRow[] = (oemRes.data ?? []) as OemRow[];
  const trend: TrendRow[] = (trendRes.data ?? []) as TrendRow[];
  const hot: HotRow[] = (hotRes.data ?? []) as HotRow[];
  const lever: LeverRow[] = (leverRes.data ?? []) as LeverRow[];
  const score: ScoreRow[] = (scoreRes.data ?? []) as ScoreRow[];
  const queue: QueueRow[] = (queueRes.data ?? []) as QueueRow[];
  const sev: SevRow[] = (sevRes.data ?? []) as SevRow[];
  const city: CityRow[] = (cityRes.data ?? []) as CityRow[];

  const statusCols: Column<StatusRow>[] = [
    { key: 'status', header: 'Status', render: r => r.status },
    { key: 'contract_count', header: 'Contracts', render: r => String(r.contract_count) },
    { key: 'total_acv_rupees', header: 'Total ACV', render: r => fmtINR(r.total_acv_rupees) },
    { key: 'avg_margin_pct', header: 'Avg Margin', render: r => fmtPct(r.avg_margin_pct) },
    { key: 'avg_yoy_delta_pct', header: 'YoY Delta', render: r => fmtPct(r.avg_yoy_delta_pct) },
  ];

  const oemCols: Column<OemRow>[] = [
    { key: 'robot_oem', header: 'OEM', render: r => r.robot_oem },
    { key: 'contract_count', header: 'Contracts', render: r => String(r.contract_count) },
    { key: 'total_royalty_rupees', header: 'Royalty Paid', render: r => fmtINR(r.total_royalty_rupees) },
    { key: 'total_parts_cost_rupees', header: 'Parts Cost', render: r => fmtINR(r.total_parts_cost_rupees) },
    { key: 'avg_margin_pct', header: 'Avg Margin', render: r => fmtPct(r.avg_margin_pct) },
    { key: 'critical_count', header: 'Critical', render: r => String(r.critical_count) },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'event_month', header: 'Month', render: r => r.event_month },
    { key: 'total_pressure_rupees', header: 'Pressure', render: r => fmtINR(r.total_pressure_rupees) },
    { key: 'total_recovered_rupees', header: 'Recovered', render: r => fmtINR(r.total_recovered_rupees) },
    { key: 'net_pressure_rupees', header: 'Net', render: r => fmtINR(r.net_pressure_rupees) },
    { key: 'event_count', header: 'Events', render: r => String(r.event_count) },
  ];

  const hotCols: Column<HotRow>[] = [
    { key: 'contract_code', header: 'Code', render: r => r.contract_code },
    { key: 'hospital_name', header: 'Hospital', render: r => r.hospital_name },
    { key: 'robot_model', header: 'Robot', render: r => r.robot_model },
    { key: 'acv_rupees', header: 'ACV', render: r => fmtINR(r.acv_rupees) },
    { key: 'gross_margin_pct', header: 'Margin', render: r => fmtPct(r.gross_margin_pct) },
    { key: 'yoy_margin_delta_pct', header: 'YoY', render: r => fmtPct(r.yoy_margin_delta_pct) },
    { key: 'renewal_due_on', header: 'Renewal', render: r => r.renewal_due_on },
    { key: 'renewal_risk', header: 'Risk', render: r => r.renewal_risk },
    { key: 'status', header: 'Status', render: r => r.status },
  ];

  const leverCols: Column<LeverRow>[] = [
    { key: 'pricing_lever', header: 'Lever', render: r => r.pricing_lever },
    { key: 'event_count', header: 'Uses', render: r => String(r.event_count) },
    { key: 'total_pressure_rupees', header: 'Pressure', render: r => fmtINR(r.total_pressure_rupees) },
    { key: 'total_recovered_rupees', header: 'Recovered', render: r => fmtINR(r.total_recovered_rupees) },
    { key: 'recovery_pct', header: 'Recovery %', render: r => fmtPct(r.recovery_pct) },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'robot_model', header: 'Model', render: r => r.robot_model },
    { key: 'contract_count', header: 'Contracts', render: r => String(r.contract_count) },
    { key: 'total_acv_rupees', header: 'Total ACV', render: r => fmtINR(r.total_acv_rupees) },
    { key: 'avg_labor_hours', header: 'Avg Labor (hrs)', render: r => String(r.avg_labor_hours) },
    { key: 'avg_margin_pct', header: 'Avg Margin', render: r => fmtPct(r.avg_margin_pct) },
    { key: 'worst_yoy_delta_pct', header: 'Worst YoY', render: r => fmtPct(r.worst_yoy_delta_pct) },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'contract_code', header: 'Code', render: r => r.contract_code },
    { key: 'hospital_name', header: 'Hospital', render: r => r.hospital_name },
    { key: 'hospital_city', header: 'City', render: r => r.hospital_city },
    { key: 'robot_model', header: 'Robot', render: r => r.robot_model },
    { key: 'renewal_due_on', header: 'Due', render: r => r.renewal_due_on },
    { key: 'days_to_renewal', header: 'Days', render: r => String(r.days_to_renewal) },
    { key: 'renewal_risk', header: 'Risk', render: r => r.renewal_risk },
    { key: 'acv_rupees', header: 'ACV', render: r => fmtINR(r.acv_rupees) },
  ];

  const sevCols: Column<SevRow>[] = [
    { key: 'event_type', header: 'Event', render: r => r.event_type },
    { key: 'pressure_severity', header: 'Severity', render: r => r.pressure_severity },
    { key: 'event_count', header: 'Count', render: r => String(r.event_count) },
    { key: 'total_pressure_rupees', header: 'Pressure', render: r => fmtINR(r.total_pressure_rupees) },
  ];

  const cityCols: Column<CityRow>[] = [
    { key: 'hospital_city', header: 'City', render: r => r.hospital_city },
    { key: 'contract_count', header: 'Contracts', render: r => String(r.contract_count) },
    { key: 'total_acv_rupees', header: 'Total ACV', render: r => fmtINR(r.total_acv_rupees) },
    { key: 'avg_margin_pct', header: 'Avg Margin', render: r => fmtPct(r.avg_margin_pct) },
    { key: 'net_pressure_rupees', header: 'Net Pressure', render: r => fmtINR(r.net_pressure_rupees) },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">Surgical Robot Service Contract Margin Pressure</h1>
        <p className="text-sm text-gray-600">
          Quarterly strategic view of margin compression on multi-year surgical-robot service contracts.
          YoY parts cost, labor hours, OEM royalty, renewal risk & pricing-lever effectiveness.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Status Summary</h2>
        <DataTable
          rows={status}
          columns={statusCols}
          emptyMessage="No contracts."
          rowKey={(r, i) => String((r as StatusRow).status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">OEM Vendor Breakdown</h2>
        <DataTable
          rows={oem}
          columns={oemCols}
          emptyMessage="No OEM data."
          rowKey={(r, i) => String((r as OemRow).robot_oem ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Monthly Pressure Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No events logged."
          rowKey={(r, i) => String((r as TrendRow).event_month ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">At-Risk Hotlist</h2>
        <DataTable
          rows={hot}
          columns={hotCols}
          emptyMessage="No at-risk contracts."
          rowKey={(r, i) => String((r as HotRow).contract_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pricing-Lever Effectiveness</h2>
        <DataTable
          rows={lever}
          columns={leverCols}
          emptyMessage="No lever data."
          rowKey={(r, i) => String((r as LeverRow).pricing_lever ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Robot Model Scorecard</h2>
        <DataTable
          rows={score}
          columns={scoreCols}
          emptyMessage="No robot data."
          rowKey={(r, i) => String((r as ScoreRow).robot_model ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming Renewal Queue</h2>
        <DataTable
          rows={queue}
          columns={queueCols}
          emptyMessage="No renewals in window."
          rowKey={(r, i) => String((r as QueueRow).contract_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Event Severity Breakdown</h2>
        <DataTable
          rows={sev}
          columns={sevCols}
          emptyMessage="No events."
          rowKey={(r, i) => String((r as SevRow).event_type + '_' + (r as SevRow).pressure_severity) || String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">City-Level Pressure</h2>
        <DataTable
          rows={city}
          columns={cityCols}
          emptyMessage="No city data."
          rowKey={(r, i) => String((r as CityRow).hospital_city ?? i)}
        />
      </section>
    </main>
  );
}
