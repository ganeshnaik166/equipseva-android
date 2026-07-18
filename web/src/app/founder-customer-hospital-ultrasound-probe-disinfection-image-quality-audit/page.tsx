import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  passed: number;
  quarantined: number;
  failed: number;
  lens_cracks: number;
  cable_faults: number;
  high_dropout: number;
  pass_pct: number;
};
type MatrixRow = {
  probe_type: string;
  disinfection_level: string;
  audits: number;
  passed: number;
  avg_dropout: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  passed: number;
  quarantined: number;
  failed: number;
  avg_dropout: number;
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
  ultrasound_room_code: string;
  probe_asset_tag: string;
  probe_type: string;
  audit_date: string;
  verdict: string;
  image_uniformity: string | null;
  lens_condition: string | null;
  cable_integrity: string | null;
  crystal_dropout_pct: number | null;
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
    supabase.rpc('founder_r3167_verdict_rollup'),
    supabase.rpc('founder_r3167_hospital_scorecard'),
    supabase.rpc('founder_r3167_probe_type_matrix'),
    supabase.rpc('founder_r3167_daily_trend'),
    supabase.rpc('founder_r3167_capa_status_board'),
    supabase.rpc('founder_r3167_root_cause_pareto'),
    supabase.rpc('founder_r3167_regulatory_impact_digest'),
    supabase.rpc('founder_r3167_high_risk_queue'),
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
    { key: 'verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'failed', header: 'Failed' },
    { key: 'lens_cracks', header: 'Lens Cracks' },
    { key: 'cable_faults', header: 'Cable Faults' },
    { key: 'high_dropout', header: 'Dropout ≥ 10%' },
    { key: 'pass_pct', header: 'Pass %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'probe_type', header: 'Probe Type' },
    { key: 'disinfection_level', header: 'Disinfection Level' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'avg_dropout', header: 'Avg Dropout %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'passed', header: 'Passed' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'failed', header: 'Failed' },
    { key: 'avg_dropout', header: 'Avg Dropout %' },
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
    { key: 'ultrasound_room_code', header: 'Room' },
    { key: 'probe_asset_tag', header: 'Probe' },
    { key: 'probe_type', header: 'Type' },
    { key: 'audit_date', header: 'Date' },
    { key: 'verdict', header: 'Verdict' },
    { key: 'image_uniformity', header: 'Image' },
    { key: 'lens_condition', header: 'Lens' },
    { key: 'cable_integrity', header: 'Cable' },
    { key: 'crystal_dropout_pct', header: 'Dropout %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Ultrasound Probe Disinfection &amp; Image-Quality Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        US probe QA log — probe type &times; disinfection level/method &times; reprocessing method &times;
        crystal drop-out &times; image uniformity &times; lens/cable integrity &amp; CAPA closure. Founder-gated
        view: verdict rollups, hospital scorecards, root-cause pareto, and regulatory-impact digest across
        NABH, CDSCO &amp; infection-control surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No probe audits logged yet."
          rowKey={(r, i) => String(r.verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital QA scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Probe type &times; disinfection level matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by probe type."
          rowKey={(r, i) => `${r.probe_type}-${r.disinfection_level}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily audit trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.audit_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk probes priority queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk probes."
          rowKey={(r, i) => `${r.probe_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
