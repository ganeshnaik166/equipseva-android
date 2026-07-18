import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { adherence_status: string; schedules: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_ppm: number;
  on_time: number;
  late: number;
  overdue: number;
  skipped: number;
  avg_days_late: number;
  adherence_pct: number;
};
type CategoryRow = {
  equipment_category: string;
  ppm_frequency: string;
  schedules: number;
  overdue_or_skipped: number;
  avg_days_late: number;
};
type TrendRow = {
  due_date: string;
  scheduled: number;
  on_time: number;
  late: number;
  overdue: number;
  skipped: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_cost_rupees: number;
  pct: number;
};
type RegRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type QueueRow = {
  hospital_name: string;
  department: string;
  equipment_category: string;
  equipment_asset_tag: string;
  due_date: string;
  adherence_status: string;
  days_late: number;
  downtime_risk: string;
  criticality: string;
  amc_vendor: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    hospRes,
    categoryRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3156_adherence_status_rollup'),
    supabase.rpc('founder_r3156_hospital_scorecard'),
    supabase.rpc('founder_r3156_category_matrix'),
    supabase.rpc('founder_r3156_due_date_trend'),
    supabase.rpc('founder_r3156_capa_status_board'),
    supabase.rpc('founder_r3156_root_cause_pareto'),
    supabase.rpc('founder_r3156_regulatory_impact_digest'),
    supabase.rpc('founder_r3156_priority_backlog_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'adherence_status', header: 'Adherence Status' },
    { key: 'schedules', header: 'Schedules' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_ppm', header: 'PPM Jobs' },
    { key: 'on_time', header: 'On Time' },
    { key: 'late', header: 'Late' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'skipped', header: 'Skipped' },
    { key: 'avg_days_late', header: 'Avg Days Late' },
    { key: 'adherence_pct', header: 'Adherence %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'equipment_category', header: 'Equipment Category' },
    { key: 'ppm_frequency', header: 'Frequency' },
    { key: 'schedules', header: 'Schedules' },
    { key: 'overdue_or_skipped', header: 'Overdue / Skipped' },
    { key: 'avg_days_late', header: 'Avg Days Late' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'due_date', header: 'Due Date' },
    { key: 'scheduled', header: 'Scheduled' },
    { key: 'on_time', header: 'On Time' },
    { key: 'late', header: 'Late' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'skipped', header: 'Skipped' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const regCols: Column<RegRow>[] = [
    { key: 'regulatory_impact', header: 'Regulatory Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'department', header: 'Dept' },
    { key: 'equipment_category', header: 'Equipment' },
    { key: 'equipment_asset_tag', header: 'Asset' },
    { key: 'due_date', header: 'Due Date' },
    { key: 'adherence_status', header: 'Status' },
    { key: 'days_late', header: 'Days Late' },
    { key: 'downtime_risk', header: 'Downtime Risk' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'amc_vendor', header: 'AMC Vendor' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Planned Preventive-Maintenance Schedule Adherence &amp; Backlog Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        PPM schedule log — equipment category &times; engineer &times; due/completed date &times;
        days-late &times; adherence status &times; downtime risk &times; criticality &amp; CAPA/backlog
        closure. Founder-gated view: adherence rollups, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Adherence status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No PPM schedules logged yet."
          rowKey={(r, i) => String(r.adherence_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital adherence scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment category &times; frequency matrix</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No schedules by category."
          rowKey={(r, i) => `${r.equipment_category}-${r.ppm_frequency}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Due-date adherence trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.due_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA &amp; backlog status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA findings."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk &amp; priority backlog queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk backlog."
          rowKey={(r, i) => `${r.equipment_asset_tag}-${r.due_date}-${i}`}
        />
      </section>
    </main>
  );
}
