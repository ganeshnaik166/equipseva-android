import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type SummaryRow = { total_audits: number; follow_ups: number; critical_units: number; replace_now_units: number; avg_vibration: number };
type SeverityRow = { imbalance_severity: string; units: number; avg_vibration: number; avg_drift: number };
type BearingRow = { bearing_status: string; units: number; avg_temp: number; avg_noise: number };
type SiteRow = { hospital_name: string; audits: number; critical_count: number; max_vibration: number; max_drift_pct: number };
type EngineerRow = { engineer_name: string; audits: number; follow_ups: number; replace_now_calls: number };
type RootCauseRow = { root_cause: string; replacements: number; total_cost: number; avg_downtime: number; warranty_claims: number };
type OpenActionRow = { hospital_name: string; centrifuge_serial: string; bearing_part_no: string; resolution_status: string; cost_rupees: number; downtime_hours: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [summary, severity, bearing, sites, engineers, rootCause, open] = await Promise.all([
    supabase.rpc('r3034_summary'),
    supabase.rpc('r3034_by_severity'),
    supabase.rpc('r3034_bearing_health_dist'),
    supabase.rpc('r3034_top_problem_sites'),
    supabase.rpc('r3034_engineer_load'),
    supabase.rpc('r3034_root_cause_breakdown'),
    supabase.rpc('r3034_open_replacement_actions'),
  ]);

  const summaryCols: Column<SummaryRow>[] = [
    { header: 'Total Audits', accessor: (r) => r.total_audits },
    { header: 'Follow-Ups', accessor: (r) => r.follow_ups },
    { header: 'Critical Units', accessor: (r) => r.critical_units },
    { header: 'Replace Now', accessor: (r) => r.replace_now_units },
    { header: 'Avg Vibration (mm/s)', accessor: (r) => r.avg_vibration },
  ];
  const severityCols: Column<SeverityRow>[] = [
    { header: 'Severity', accessor: (r) => r.imbalance_severity },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Avg Vibration', accessor: (r) => r.avg_vibration },
    { header: 'Avg Drift %', accessor: (r) => r.avg_drift },
  ];
  const bearingCols: Column<BearingRow>[] = [
    { header: 'Bearing Status', accessor: (r) => r.bearing_status },
    { header: 'Units', accessor: (r) => r.units },
    { header: 'Avg Temp (C)', accessor: (r) => r.avg_temp },
    { header: 'Avg Noise (dB)', accessor: (r) => r.avg_noise },
  ];
  const siteCols: Column<SiteRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Critical', accessor: (r) => r.critical_count },
    { header: 'Max Vibration', accessor: (r) => r.max_vibration },
    { header: 'Max Drift %', accessor: (r) => r.max_drift_pct },
  ];
  const engineerCols: Column<EngineerRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer_name },
    { header: 'Audits', accessor: (r) => r.audits },
    { header: 'Follow-Ups', accessor: (r) => r.follow_ups },
    { header: 'Replace-Now Calls', accessor: (r) => r.replace_now_calls },
  ];
  const rootCauseCols: Column<RootCauseRow>[] = [
    { header: 'Root Cause', accessor: (r) => r.root_cause },
    { header: 'Replacements', accessor: (r) => r.replacements },
    { header: 'Total Cost (Rs)', accessor: (r) => r.total_cost },
    { header: 'Avg Downtime (hrs)', accessor: (r) => r.avg_downtime },
    { header: 'Warranty Claims', accessor: (r) => r.warranty_claims },
  ];
  const openCols: Column<OpenActionRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Serial', accessor: (r) => r.centrifuge_serial },
    { header: 'Bearing P/N', accessor: (r) => r.bearing_part_no },
    { header: 'Status', accessor: (r) => r.resolution_status },
    { header: 'Cost (Rs)', accessor: (r) => r.cost_rupees },
    { header: 'Downtime (hrs)', accessor: (r) => r.downtime_hours },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>R3034 — Centrifuge Imbalance &amp; Bearing Health Audit</h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Engineer monthly audit of customer-site centrifuges &gt;= G2.5 balance grade. Tracks vibration RMS, RPM drift &amp; bearing temp/noise =&gt; flags replace-now units.
        </p>
      </header>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: 8 }}>Summary</h2>
        <DataTable<SummaryRow>
          rows={(summary.data ?? []) as SummaryRow[]}
          columns={summaryCols}
          emptyMessage="No summary"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: 8 }}>By Imbalance Severity</h2>
        <DataTable<SeverityRow>
          rows={(severity.data ?? []) as SeverityRow[]}
          columns={severityCols}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: 8 }}>Bearing Health Distribution</h2>
        <DataTable<BearingRow>
          rows={(bearing.data ?? []) as BearingRow[]}
          columns={bearingCols}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: 8 }}>Top Problem Sites</h2>
        <DataTable<SiteRow>
          rows={(sites.data ?? []) as SiteRow[]}
          columns={siteCols}
          emptyMessage="No sites"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: 8 }}>Engineer Load</h2>
        <DataTable<EngineerRow>
          rows={(engineers.data ?? []) as EngineerRow[]}
          columns={engineerCols}
          emptyMessage="No engineers"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: 8 }}>Root Cause Breakdown</h2>
        <DataTable<RootCauseRow>
          rows={(rootCause.data ?? []) as RootCauseRow[]}
          columns={rootCauseCols}
          emptyMessage="No replacements"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontWeight: 600, marginBottom: 8 }}>Open Replacement Actions</h2>
        <DataTable<OpenActionRow>
          rows={(open.data ?? []) as OpenActionRow[]}
          columns={openCols}
          emptyMessage="No open actions"
          rowKey={(r, i) => String((r as { id?: string }).id ?? i)}
        />
      </section>
    </div>
  );
}
