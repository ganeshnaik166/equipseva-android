import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type ComplianceRow = { compliance_status: string; rooms: number; avg_observed: number; avg_setpoint: number; breach_rate_pct: number };
type WardRow = { ward_type: string; total_readings: number; breaches: number; critical_breaches: number; avg_ach: number; avg_filter_dp: number };
type DriftRow = { room_code: string; reading_month: string; setpoint_pascals: number; observed_pascals: number; drift_pascals: number; compliance_status: string };
type CriticalRow = { room_code: string; ward_type: string; reading_month: string; observed_pascals: number; setpoint_pascals: number; remediation_action: string | null; remediation_at: string | null };
type MonthlyRow = { reading_month: string; rooms_audited: number; breaches: number; avg_observed: number; avg_ach: number };
type FunnelRow = { visit_kind: string; scheduled_or_done: number; completed: number; missed: number; avg_duration_min: number | null };
type FindingsRow = { room_code: string; visit_month: string; visit_kind: string; findings_count: number; critical_findings_count: number; notes: string | null };
type OccRow = { occupancy_bucket: string; readings: number; breaches: number; avg_door_open_seconds: number | null };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [comp, ward, drift, crit, monthly, funnel, findings, occ] = await Promise.all([
    supabase.rpc('founder_isol_compliance_summary_r3092'),
    supabase.rpc('founder_isol_ward_breakdown_r3092'),
    supabase.rpc('founder_isol_room_drift_r3092'),
    supabase.rpc('founder_isol_critical_breaches_r3092'),
    supabase.rpc('founder_isol_monthly_trend_r3092'),
    supabase.rpc('founder_isol_visit_funnel_r3092'),
    supabase.rpc('founder_isol_findings_hotlist_r3092'),
    supabase.rpc('founder_isol_occupancy_vs_breach_r3092'),
  ]);

  const compRows = (comp.data ?? []) as ComplianceRow[];
  const wardRows = (ward.data ?? []) as WardRow[];
  const driftRows = (drift.data ?? []) as DriftRow[];
  const critRows = (crit.data ?? []) as CriticalRow[];
  const monthlyRows = (monthly.data ?? []) as MonthlyRow[];
  const funnelRows = (funnel.data ?? []) as FunnelRow[];
  const findingsRows = (findings.data ?? []) as FindingsRow[];
  const occRows = (occ.data ?? []) as OccRow[];

  const compCols: Column<ComplianceRow>[] = [
    { header: 'Status', accessor: (r) => r.compliance_status },
    { header: 'Rooms', accessor: (r) => r.rooms },
    { header: 'Avg Observed (Pa)', accessor: (r) => r.avg_observed },
    { header: 'Avg Setpoint (Pa)', accessor: (r) => r.avg_setpoint },
    { header: 'Breach Rate %', accessor: (r) => r.breach_rate_pct },
  ];

  const wardCols: Column<WardRow>[] = [
    { header: 'Ward Type', accessor: (r) => r.ward_type },
    { header: 'Readings', accessor: (r) => r.total_readings },
    { header: 'Breaches', accessor: (r) => r.breaches },
    { header: 'Critical', accessor: (r) => r.critical_breaches },
    { header: 'Avg ACH', accessor: (r) => r.avg_ach },
    { header: 'Avg Filter ΔP', accessor: (r) => r.avg_filter_dp },
  ];

  const driftCols: Column<DriftRow>[] = [
    { header: 'Room', accessor: (r) => r.room_code },
    { header: 'Month', accessor: (r) => r.reading_month },
    { header: 'Setpoint', accessor: (r) => r.setpoint_pascals },
    { header: 'Observed', accessor: (r) => r.observed_pascals },
    { header: 'Drift', accessor: (r) => r.drift_pascals },
    { header: 'Status', accessor: (r) => r.compliance_status },
  ];

  const critCols: Column<CriticalRow>[] = [
    { header: 'Room', accessor: (r) => r.room_code },
    { header: 'Ward', accessor: (r) => r.ward_type },
    { header: 'Month', accessor: (r) => r.reading_month },
    { header: 'Observed', accessor: (r) => r.observed_pascals },
    { header: 'Setpoint', accessor: (r) => r.setpoint_pascals },
    { header: 'Remediation', accessor: (r) => r.remediation_action ?? '—' },
    { header: 'Remediation At', accessor: (r) => r.remediation_at ?? '—' },
  ];

  const monthlyCols: Column<MonthlyRow>[] = [
    { header: 'Month', accessor: (r) => r.reading_month },
    { header: 'Rooms Audited', accessor: (r) => r.rooms_audited },
    { header: 'Breaches', accessor: (r) => r.breaches },
    { header: 'Avg Observed', accessor: (r) => r.avg_observed },
    { header: 'Avg ACH', accessor: (r) => r.avg_ach },
  ];

  const funnelCols: Column<FunnelRow>[] = [
    { header: 'Visit Kind', accessor: (r) => r.visit_kind },
    { header: 'Total', accessor: (r) => r.scheduled_or_done },
    { header: 'Completed', accessor: (r) => r.completed },
    { header: 'Missed', accessor: (r) => r.missed },
    { header: 'Avg Duration (min)', accessor: (r) => r.avg_duration_min ?? '—' },
  ];

  const findingsCols: Column<FindingsRow>[] = [
    { header: 'Room', accessor: (r) => r.room_code },
    { header: 'Month', accessor: (r) => r.visit_month },
    { header: 'Kind', accessor: (r) => r.visit_kind },
    { header: 'Findings', accessor: (r) => r.findings_count },
    { header: 'Critical', accessor: (r) => r.critical_findings_count },
    { header: 'Notes', accessor: (r) => r.notes ?? '—' },
  ];

  const occCols: Column<OccRow>[] = [
    { header: 'Occupancy Bucket', accessor: (r) => r.occupancy_bucket },
    { header: 'Readings', accessor: (r) => r.readings },
    { header: 'Breaches', accessor: (r) => r.breaches },
    { header: 'Avg Door-Open (s)', accessor: (r) => r.avg_door_open_seconds ?? '—' },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Negative-Pressure Isolation Room Tracker</h1>
        <p className="text-sm text-gray-600">Monthly engineer visits at hospital customer sites. Pressure-differential setpoint vs observed; breach detection & remediation.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Compliance Status Summary</h2>
        <DataTable
          rows={compRows}
          columns={compCols}
          emptyMessage="No compliance data."
          rowKey={(r, i) => String((r as { compliance_status?: string }).compliance_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Ward Type Breakdown</h2>
        <DataTable
          rows={wardRows}
          columns={wardCols}
          emptyMessage="No ward data."
          rowKey={(r, i) => String((r as { ward_type?: string }).ward_type ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top 20 Pressure-Drift Rooms</h2>
        <DataTable
          rows={driftRows}
          columns={driftCols}
          emptyMessage="No drift data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Critical Breaches & Remediation Log</h2>
        <DataTable
          rows={critRows}
          columns={critCols}
          emptyMessage="No critical breaches."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Monthly Trend</h2>
        <DataTable
          rows={monthlyRows}
          columns={monthlyCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String((r as { reading_month?: string }).reading_month ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Engineer Visit Funnel</h2>
        <DataTable
          rows={funnelRows}
          columns={funnelCols}
          emptyMessage="No visit data."
          rowKey={(r, i) => String((r as { visit_kind?: string }).visit_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Findings Hotlist (findings &gt; 0)</h2>
        <DataTable
          rows={findingsRows}
          columns={findingsCols}
          emptyMessage="No findings."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Occupancy vs Breach Rate</h2>
        <DataTable
          rows={occRows}
          columns={occCols}
          emptyMessage="No occupancy data."
          rowKey={(r, i) => String((r as { occupancy_bucket?: string }).occupancy_bucket ?? i)}
        />
      </section>
    </main>
  );
}
