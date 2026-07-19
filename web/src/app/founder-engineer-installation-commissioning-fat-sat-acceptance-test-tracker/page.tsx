import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { commissioning_verdict: string; jobs: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_jobs: number;
  accepted: number;
  conditional: number;
  not_accepted: number;
  critical_open: number;
  total_deviations: number;
  avg_checklist_pass_pct: number;
  accepted_pct: number;
};
type MatrixRow = {
  equipment_type: string;
  commissioning_stage: string;
  jobs: number;
  accepted: number;
  avg_checklist_pass_pct: number;
  total_deviations: number;
};
type TrendRow = {
  scheduled_date: string;
  jobs: number;
  accepted: number;
  not_accepted: number;
  critical_open: number;
  total_deviations: number;
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
type RiskRow = {
  hospital_name: string;
  job_code: string;
  engineer_name: string;
  equipment_type: string;
  commissioning_stage: string;
  scheduled_date: string;
  commissioning_verdict: string;
  deviations_found: number;
  critical_open: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3340_verdict_rollup'),
    supabase.rpc('founder_r3340_hospital_scorecard'),
    supabase.rpc('founder_r3340_equipment_stage_matrix'),
    supabase.rpc('founder_r3340_daily_commissioning_trend'),
    supabase.rpc('founder_r3340_capa_status_board'),
    supabase.rpc('founder_r3340_root_cause_pareto'),
    supabase.rpc('founder_r3340_regulatory_impact_digest'),
    supabase.rpc('founder_r3340_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'commissioning_verdict', header: 'Verdict' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_jobs', header: 'Jobs' },
    { key: 'accepted', header: 'Accepted' },
    { key: 'conditional', header: 'Conditional' },
    { key: 'not_accepted', header: 'Not Accepted' },
    { key: 'critical_open', header: 'Critical Open' },
    { key: 'total_deviations', header: 'Deviations' },
    { key: 'avg_checklist_pass_pct', header: 'Avg Checklist Pass %' },
    { key: 'accepted_pct', header: 'Accepted %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'commissioning_stage', header: 'Stage' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'accepted', header: 'Accepted' },
    { key: 'avg_checklist_pass_pct', header: 'Avg Checklist Pass %' },
    { key: 'total_deviations', header: 'Deviations' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'scheduled_date', header: 'Date' },
    { key: 'jobs', header: 'Jobs' },
    { key: 'accepted', header: 'Accepted' },
    { key: 'not_accepted', header: 'Not Accepted' },
    { key: 'critical_open', header: 'Critical Open' },
    { key: 'total_deviations', header: 'Deviations' },
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

  const riskCols: Column<RiskRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'job_code', header: 'Job' },
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'commissioning_stage', header: 'Stage' },
    { key: 'scheduled_date', header: 'Date' },
    { key: 'commissioning_verdict', header: 'Verdict' },
    { key: 'deviations_found', header: 'Deviations' },
    { key: 'critical_open', header: 'Critical Open' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Installation-Commissioning FAT / SAT Acceptance-Test Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Commissioning log for newly installed hospital equipment — equipment type &times;
        commissioning stage (FAT &rarr; site-readiness &rarr; installation &rarr; SAT &rarr; IQ/OQ/PQ
        &rarr; handover) &times; checklist pass rate &times; deviations found &times;
        utilities / calibration / training / customer-signoff &times; commissioning verdict &amp; CAPA
        closure. Founder-gated view: verdict rollups, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH, CDSCO &amp; AERB surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Commissioning verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No commissioning jobs logged yet."
          rowKey={(r, i) => String(r.commissioning_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital commissioning scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment &times; stage matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No jobs by equipment / stage."
          rowKey={(r, i) => `${r.equipment_type}-${r.commissioning_stage}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily commissioning trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.scheduled_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Regulatory impact digest</h2>
        <DataTable
          rows={regRows}
          columns={regCols}
          emptyMessage="No regulatory-impact rollups."
          rowKey={(r, i) => String(r.regulatory_impact ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk commissioning queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk jobs."
          rowKey={(r, i) => `${r.job_code}-${r.scheduled_date}-${i}`}
        />
      </section>
    </main>
  );
}
