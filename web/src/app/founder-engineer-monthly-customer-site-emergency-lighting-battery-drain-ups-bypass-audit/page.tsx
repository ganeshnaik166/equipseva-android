import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type Overview = { metric: string; value: string };
type Severity = { severity: string; audits: number; avg_battery_health: number; avg_drain_rate: number; failed_fixtures: number };
type TopDrain = { hospital_name: string; engineer_name: string; drain_rate: number; battery_health: number; severity: string; status: string };
type Runtime = { hospital_name: string; expected_min: number; measured_min: number; shortfall_min: number; shortfall_pct: number };
type Reason = { reason: string; events: number; total_minutes: number; avg_load_kva: number; critical_loads_hit: number };
type Recurring = { hospital_name: string; ups_model: string; total_events: number; total_minutes: number; critical_loads: number };
type Scorecard = { engineer_name: string; audits: number; p0_p1_count: number; avg_battery_health: number; closed_count: number };
type Status = { status: string; audits: number; total_failed_fixtures: number; avg_drain: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [ov, sev, top, rt, rsn, rec, sc, st] = await Promise.all([
    supabase.rpc('r2974_overview'),
    supabase.rpc('r2974_severity_breakdown'),
    supabase.rpc('r2974_top_drain_sites'),
    supabase.rpc('r2974_runtime_shortfall'),
    supabase.rpc('r2974_bypass_reasons'),
    supabase.rpc('r2974_recurring_bypass_sites'),
    supabase.rpc('r2974_engineer_scorecard'),
    supabase.rpc('r2974_status_summary'),
  ]);

  const overview = (ov.data ?? []) as Overview[];
  const severity = (sev.data ?? []) as Severity[];
  const topDrain = (top.data ?? []) as TopDrain[];
  const runtime = (rt.data ?? []) as Runtime[];
  const reasons = (rsn.data ?? []) as Reason[];
  const recurring = (rec.data ?? []) as Recurring[];
  const scorecard = (sc.data ?? []) as Scorecard[];
  const status = (st.data ?? []) as Status[];

  const ovCols: Column<Overview>[] = [
    { header: 'Metric', cell: (r) => r.metric },
    { header: 'Value', cell: (r) => r.value },
  ];
  const sevCols: Column<Severity>[] = [
    { header: 'Severity', cell: (r) => r.severity },
    { header: 'Audits', cell: (r) => r.audits },
    { header: 'Avg Battery %', cell: (r) => r.avg_battery_health },
    { header: 'Avg Drain %/hr', cell: (r) => r.avg_drain_rate },
    { header: 'Failed Fixtures', cell: (r) => r.failed_fixtures },
  ];
  const topCols: Column<TopDrain>[] = [
    { header: 'Hospital', cell: (r) => r.hospital_name },
    { header: 'Engineer', cell: (r) => r.engineer_name },
    { header: 'Drain %/hr', cell: (r) => r.drain_rate },
    { header: 'Battery %', cell: (r) => r.battery_health },
    { header: 'Severity', cell: (r) => r.severity },
    { header: 'Status', cell: (r) => r.status },
  ];
  const rtCols: Column<Runtime>[] = [
    { header: 'Hospital', cell: (r) => r.hospital_name },
    { header: 'Expected min', cell: (r) => r.expected_min },
    { header: 'Measured min', cell: (r) => r.measured_min },
    { header: 'Shortfall min', cell: (r) => r.shortfall_min },
    { header: 'Shortfall %', cell: (r) => r.shortfall_pct },
  ];
  const rsnCols: Column<Reason>[] = [
    { header: 'Reason', cell: (r) => r.reason },
    { header: 'Events', cell: (r) => r.events },
    { header: 'Total min', cell: (r) => r.total_minutes },
    { header: 'Avg load kVA', cell: (r) => r.avg_load_kva },
    { header: 'Critical loads hit', cell: (r) => r.critical_loads_hit },
  ];
  const recCols: Column<Recurring>[] = [
    { header: 'Hospital', cell: (r) => r.hospital_name },
    { header: 'UPS Model', cell: (r) => r.ups_model },
    { header: 'Events', cell: (r) => r.total_events },
    { header: 'Total min', cell: (r) => r.total_minutes },
    { header: 'Critical loads', cell: (r) => r.critical_loads },
  ];
  const scCols: Column<Scorecard>[] = [
    { header: 'Engineer', cell: (r) => r.engineer_name },
    { header: 'Audits', cell: (r) => r.audits },
    { header: 'P0/P1', cell: (r) => r.p0_p1_count },
    { header: 'Avg battery %', cell: (r) => r.avg_battery_health },
    { header: 'Closed', cell: (r) => r.closed_count },
  ];
  const stCols: Column<Status>[] = [
    { header: 'Status', cell: (r) => r.status },
    { header: 'Audits', cell: (r) => r.audits },
    { header: 'Failed fixtures', cell: (r) => r.total_failed_fixtures },
    { header: 'Avg drain %/hr', cell: (r) => r.avg_drain },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Engineer Monthly Emergency-Lighting Battery Drain & UPS Bypass Audit</h1>
        <p className="text-sm text-gray-500">Round r2974 — monthly site safety posture across battery runtime & UPS bypass behaviour.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Overview</h2>
        <DataTable rows={overview} columns={ovCols} emptyMessage="No overview metrics" rowKey={(r, i) => String(r.metric ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Severity Breakdown</h2>
        <DataTable rows={severity} columns={sevCols} emptyMessage="No severity rows" rowKey={(r, i) => String(r.severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top Drain Sites</h2>
        <DataTable rows={topDrain} columns={topCols} emptyMessage="No drain sites" rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Runtime Shortfall (measured &lt; expected)</h2>
        <DataTable rows={runtime} columns={rtCols} emptyMessage="No shortfalls" rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">UPS Bypass Reasons</h2>
        <DataTable rows={reasons} columns={rsnCols} emptyMessage="No bypass events" rowKey={(r, i) => String(r.reason ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recurring / Escalated Bypass Sites</h2>
        <DataTable rows={recurring} columns={recCols} emptyMessage="No recurring sites" rowKey={(r, i) => String(r.hospital_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Engineer Scorecard</h2>
        <DataTable rows={scorecard} columns={scCols} emptyMessage="No engineer data" rowKey={(r, i) => String(r.engineer_name ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Status Summary</h2>
        <DataTable rows={status} columns={stCols} emptyMessage="No status rows" rowKey={(r, i) => String(r.status ?? i)} />
      </section>
    </div>
  );
}
