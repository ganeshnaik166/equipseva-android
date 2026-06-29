import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';
import type { Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Summary = { total_inspections: number; total_meters: number; avg_adhesion_pct: number; urgent_count: number; healthy_count: number };
type StatusRow = { status: string; n: number; total_meters: number; avg_edge_lift_mm: number };
type ZoneRow = { zone_type: string; inspections: number; avg_adhesion_pct: number; urgent_count: number };
type UrgentRow = { hospital_name: string; zone_label: string; zone_type: string; adhesion_score_pct: number; edge_lift_mm: number; next_check_on: string; engineer_code: string };
type EngRow = { engineer_code: string; inspections: number; replacements: number; avg_adhesion_post_pct: number; rework_count: number };
type OutcomeRow = { outcome: string; n: number; total_meters: number; avg_cost_rupees: number; avg_cure_hours: number };
type PrepRow = { surface_prep: string; replacements: number; excellent_count: number; rework_or_failed: number; avg_cost_rupees: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [summary, statusBreak, zoneHealth, urgent, eng, outcomes, prep] = await Promise.all([
    supabase.rpc('founder_fmt_inspection_summary_r2996'),
    supabase.rpc('founder_fmt_status_breakdown_r2996'),
    supabase.rpc('founder_fmt_zone_type_health_r2996'),
    supabase.rpc('founder_fmt_urgent_replacements_r2996'),
    supabase.rpc('founder_fmt_engineer_performance_r2996'),
    supabase.rpc('founder_fmt_replacement_outcomes_r2996'),
    supabase.rpc('founder_fmt_surface_prep_efficacy_r2996'),
  ]);

  const s: Summary | null = (summary.data as Summary[] | null)?.[0] ?? null;

  const statusCols: Column<StatusRow>[] = [
    { key: 'status', header: 'Status' },
    { key: 'n', header: 'Count' },
    { key: 'total_meters', header: 'Total Meters' },
    { key: 'avg_edge_lift_mm', header: 'Avg Edge Lift (mm)' },
  ];

  const zoneCols: Column<ZoneRow>[] = [
    { key: 'zone_type', header: 'Zone Type' },
    { key: 'inspections', header: 'Inspections' },
    { key: 'avg_adhesion_pct', header: 'Avg Adhesion %' },
    { key: 'urgent_count', header: 'Urgent' },
  ];

  const urgentCols: Column<UrgentRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'zone_label', header: 'Zone' },
    { key: 'zone_type', header: 'Type' },
    { key: 'adhesion_score_pct', header: 'Adhesion %' },
    { key: 'edge_lift_mm', header: 'Edge Lift (mm)' },
    { key: 'next_check_on', header: 'Next Check' },
    { key: 'engineer_code', header: 'Engineer' },
  ];

  const engCols: Column<EngRow>[] = [
    { key: 'engineer_code', header: 'Engineer' },
    { key: 'inspections', header: 'Inspections' },
    { key: 'replacements', header: 'Replacements' },
    { key: 'avg_adhesion_post_pct', header: 'Avg Adhesion Post %' },
    { key: 'rework_count', header: 'Rework' },
  ];

  const outcomeCols: Column<OutcomeRow>[] = [
    { key: 'outcome', header: 'Outcome' },
    { key: 'n', header: 'Count' },
    { key: 'total_meters', header: 'Total Meters' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (Rs)' },
    { key: 'avg_cure_hours', header: 'Avg Cure (hrs)' },
  ];

  const prepCols: Column<PrepRow>[] = [
    { key: 'surface_prep', header: 'Surface Prep' },
    { key: 'replacements', header: 'Replacements' },
    { key: 'excellent_count', header: 'Excellent' },
    { key: 'rework_or_failed', header: 'Rework / Failed' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (Rs)' },
  ];

  return (
    <main style={{ padding: 24 }}>
      <h1>Floor-Marking Tape Adhesion &amp; Replacement Tracker</h1>
      <p>Monthly hospital floor visit log. Urgent =&gt; replace within 7 days. Edge lift &gt;= 5mm =&gt; tape compromised.</p>

      <section style={{ marginTop: 16 }}>
        <h2>Fleet Summary</h2>
        {s ? (
          <ul>
            <li>Inspections: {s.total_inspections}</li>
            <li>Total Meters Installed: {s.total_meters}</li>
            <li>Avg Adhesion: {s.avg_adhesion_pct}%</li>
            <li>Urgent Replace: {s.urgent_count}</li>
            <li>Healthy: {s.healthy_count}</li>
          </ul>
        ) : <p>No summary data.</p>}
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Status Breakdown</h2>
        <DataTable
          rows={(statusBreak.data as StatusRow[] | null) ?? []}
          columns={statusCols}
          emptyMessage="No status rows."
          rowKey={(r, i) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Zone Type Health (sorted weakest adhesion first)</h2>
        <DataTable
          rows={(zoneHealth.data as ZoneRow[] | null) ?? []}
          columns={zoneCols}
          emptyMessage="No zone data."
          rowKey={(r, i) => String(r.zone_type ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Urgent / Scheduled Replacements</h2>
        <DataTable
          rows={(urgent.data as UrgentRow[] | null) ?? []}
          columns={urgentCols}
          emptyMessage="No urgent zones."
          rowKey={(r, i) => `${r.hospital_name}-${r.zone_label}-${i}`}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Engineer Performance</h2>
        <DataTable
          rows={(eng.data as EngRow[] | null) ?? []}
          columns={engCols}
          emptyMessage="No engineer rows."
          rowKey={(r, i) => String(r.engineer_code ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Replacement Outcomes</h2>
        <DataTable
          rows={(outcomes.data as OutcomeRow[] | null) ?? []}
          columns={outcomeCols}
          emptyMessage="No outcome data."
          rowKey={(r, i) => String(r.outcome ?? i)}
        />
      </section>

      <section style={{ marginTop: 24 }}>
        <h2>Surface Prep Efficacy</h2>
        <DataTable
          rows={(prep.data as PrepRow[] | null) ?? []}
          columns={prepCols}
          emptyMessage="No prep data."
          rowKey={(r, i) => String(r.surface_prep ?? i)}
        />
      </section>
    </main>
  );
}
