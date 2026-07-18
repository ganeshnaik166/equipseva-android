import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { feedback_status: string; visits: number; pct: number };
type HospRow = {
  hospital_name: string;
  visits: number;
  promoters: number;
  passives: number;
  detractors: number;
  avg_nps: number;
  nps_net: number;
  fix_first_time_pct: number;
};
type MatrixRow = {
  visit_type: string;
  equipment_domain: string;
  visits: number;
  avg_nps: number;
  detractors: number;
};
type TrendRow = {
  visit_date: string;
  visits: number;
  avg_nps: number;
  promoters: number;
  detractors: number;
  nps_net: number;
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
type ImpactRow = {
  regulatory_impact: string;
  findings: number;
  open_findings: number;
  total_cost_rupees: number;
};
type QueueRow = {
  hospital_name: string;
  engineer_name: string;
  visit_date: string;
  visit_type: string;
  nps_score: number;
  nps_segment: string;
  feedback_status: string;
  punctuality_rating: string;
  would_rebook: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    impactRes,
    queueRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3164_feedback_status_rollup'),
    supabase.rpc('founder_r3164_hospital_scorecard'),
    supabase.rpc('founder_r3164_visit_equipment_matrix'),
    supabase.rpc('founder_r3164_nps_daily_trend'),
    supabase.rpc('founder_r3164_capa_status_board'),
    supabase.rpc('founder_r3164_root_cause_pareto'),
    supabase.rpc('founder_r3164_impact_digest'),
    supabase.rpc('founder_r3164_priority_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const impactRows: ImpactRow[] = (impactRes.data as ImpactRow[]) ?? [];
  const queueRows: QueueRow[] = (queueRes.data as QueueRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'feedback_status', header: 'Verdict' },
    { key: 'visits', header: 'Visits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'visits', header: 'Visits' },
    { key: 'promoters', header: 'Promoters' },
    { key: 'passives', header: 'Passives' },
    { key: 'detractors', header: 'Detractors' },
    { key: 'avg_nps', header: 'Avg NPS' },
    { key: 'nps_net', header: 'Net NPS' },
    { key: 'fix_first_time_pct', header: 'Fix-First %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'visit_type', header: 'Visit Type' },
    { key: 'equipment_domain', header: 'Equipment Domain' },
    { key: 'visits', header: 'Visits' },
    { key: 'avg_nps', header: 'Avg NPS' },
    { key: 'detractors', header: 'Detractors' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'visit_date', header: 'Date' },
    { key: 'visits', header: 'Visits' },
    { key: 'avg_nps', header: 'Avg NPS' },
    { key: 'promoters', header: 'Promoters' },
    { key: 'detractors', header: 'Detractors' },
    { key: 'nps_net', header: 'Net NPS' },
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

  const impactCols: Column<ImpactRow>[] = [
    { key: 'regulatory_impact', header: 'Service Impact' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
  ];

  const queueCols: Column<QueueRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'visit_date', header: 'Date' },
    { key: 'visit_type', header: 'Visit Type' },
    { key: 'nps_score', header: 'NPS' },
    { key: 'nps_segment', header: 'Segment' },
    { key: 'feedback_status', header: 'Verdict' },
    { key: 'punctuality_rating', header: 'Punctuality' },
    { key: 'would_rebook', header: 'Rebook' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Per-Visit Customer NPS &amp; Service-Quality Feedback Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Per-visit customer feedback — engineer &times; visit type &times; NPS 0&ndash;10 &times; segment
        &times; punctuality &times; fix-first-time &times; cleanliness &times; would-rebook &times; sentiment
        &amp; verdict, with follow-up/CAPA closure. Founder-gated view: status rollups, hospital scorecards,
        root-cause pareto, and service-impact digest across the engineer field force.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Feedback verdict distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No feedback logged yet."
          rowKey={(r, i) => String(r.feedback_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital NPS scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Visit type &times; equipment domain matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No visits by domain."
          rowKey={(r, i) => `${r.visit_type}-${r.equipment_domain}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily NPS trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.visit_date ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Service-impact digest</h2>
        <DataTable
          rows={impactRows}
          columns={impactCols}
          emptyMessage="No service-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk feedback queue</h2>
        <DataTable
          rows={queueRows}
          columns={queueCols}
          emptyMessage="No high-risk feedback."
          rowKey={(r, i) => `${r.hospital_name}-${r.visit_date}-${i}`}
        />
      </section>
    </main>
  );
}
