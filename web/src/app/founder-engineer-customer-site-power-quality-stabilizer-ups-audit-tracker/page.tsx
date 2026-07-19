import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { power_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  healthy: number;
  action_needed: number;
  critical: number;
  earthing_fail: number;
  ups_inadequate: number;
  spike_exposed: number;
  healthy_pct: number;
};
type MatrixRow = {
  equipment_protected: string;
  region: string;
  audits: number;
  healthy: number;
  avg_earthing_ohm: number;
  avg_ups_minutes: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  healthy: number;
  critical: number;
  earthing_fail: number;
  ups_inadequate: number;
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
  region: string;
  audit_code: string;
  audit_date: string;
  power_verdict: string;
  voltage_range_ok: string | null;
  earthing_status: string | null;
  isolation_transformer_ok: string | null;
  ups_status: string | null;
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
    supabase.rpc('founder_r3384_power_verdict_rollup'),
    supabase.rpc('founder_r3384_hospital_scorecard'),
    supabase.rpc('founder_r3384_equipment_region_matrix'),
    supabase.rpc('founder_r3384_daily_audit_trend'),
    supabase.rpc('founder_r3384_capa_status_board'),
    supabase.rpc('founder_r3384_root_cause_pareto'),
    supabase.rpc('founder_r3384_regulatory_impact_digest'),
    supabase.rpc('founder_r3384_high_risk_queue'),
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
    { key: 'power_verdict', header: 'Power Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'action_needed', header: 'Action Needed' },
    { key: 'critical', header: 'Critical' },
    { key: 'earthing_fail', header: 'Earthing Fail' },
    { key: 'ups_inadequate', header: 'UPS Inadequate' },
    { key: 'spike_exposed', header: 'Spike Exposed' },
    { key: 'healthy_pct', header: 'Healthy %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_protected', header: 'Equipment Protected' },
    { key: 'region', header: 'Region' },
    { key: 'audits', header: 'Audits' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'avg_earthing_ohm', header: 'Avg Earthing (ohm)' },
    { key: 'avg_ups_minutes', header: 'Avg UPS (min)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'healthy', header: 'Healthy' },
    { key: 'critical', header: 'Critical' },
    { key: 'earthing_fail', header: 'Earthing Fail' },
    { key: 'ups_inadequate', header: 'UPS Inadequate' },
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
    { key: 'region', header: 'Region' },
    { key: 'audit_code', header: 'Audit' },
    { key: 'audit_date', header: 'Date' },
    { key: 'power_verdict', header: 'Verdict' },
    { key: 'voltage_range_ok', header: 'Voltage' },
    { key: 'earthing_status', header: 'Earthing' },
    { key: 'isolation_transformer_ok', header: 'Isolation Txfmr' },
    { key: 'ups_status', header: 'UPS' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Customer-Site Power-Quality, Stabilizer &amp; UPS Audit Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Field electrical-environment audit &mdash; equipment protected &times; region &times; mains
        voltage stability &times; earthing resistance ohm &times; isolation-transformer state &times;
        voltage-stabilizer function &times; UPS runtime minutes &times; spike/surge protection &times;
        neutral-earth voltage &amp; CAPA closure. Poor power damages MRI, CT, cath-lab and lab
        analyzers &mdash; founder-gated view: power verdicts, hospital scorecards, root-cause pareto,
        and regulatory-impact digest across NABH &amp; CEA electrical-safety surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Power verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No site audits logged yet."
          rowKey={(r, i) => String(r.power_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital power-quality scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment protected &times; region matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by equipment."
          rowKey={(r, i) => `${r.equipment_protected}-${r.region}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk power-quality queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk audits."
          rowKey={(r, i) => `${r.audit_code}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
