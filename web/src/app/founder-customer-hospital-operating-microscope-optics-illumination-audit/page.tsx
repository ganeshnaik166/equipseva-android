import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; scopes: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  fit_for_use: number;
  restricted: number;
  condemned: number;
  fungus_hits: number;
  lamp_over_80pct: number;
  avg_illumination_lux: number;
  fit_pct: number;
};
type MatrixRow = {
  scope_specialty: string;
  lamp_type: string;
  audits: number;
  fit_for_use: number;
  avg_lux: number;
  avg_lamp_life_used_pct: number | null;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  fit_for_use: number;
  needs_service: number;
  fungus_flagged: number;
  avg_lux: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  avg_cost_rupees: number;
  overdue_or_escalated: number;
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
  ot_room_code: string;
  scope_asset_tag: string;
  audit_date: string;
  audit_verdict: string;
  fungus_check: string | null;
  focus_zoom_motor: string | null;
  illumination_verdict: string | null;
  lamp_life_used_pct: number | null;
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
    supabase.rpc('founder_r3203_audit_verdict_rollup'),
    supabase.rpc('founder_r3203_hospital_scorecard'),
    supabase.rpc('founder_r3203_specialty_lamp_matrix'),
    supabase.rpc('founder_r3203_daily_audit_trend'),
    supabase.rpc('founder_r3203_capa_status_board'),
    supabase.rpc('founder_r3203_root_cause_pareto'),
    supabase.rpc('founder_r3203_regulatory_impact_digest'),
    supabase.rpc('founder_r3203_high_risk_scopes'),
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
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'scopes', header: 'Scopes' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit' },
    { key: 'restricted', header: 'Restricted' },
    { key: 'condemned', header: 'Condemned' },
    { key: 'fungus_hits', header: 'Fungus' },
    { key: 'lamp_over_80pct', header: 'Lamp >80%' },
    { key: 'avg_illumination_lux', header: 'Avg Lux' },
    { key: 'fit_pct', header: 'Fit %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'scope_specialty', header: 'Specialty' },
    { key: 'lamp_type', header: 'Lamp' },
    { key: 'audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit' },
    { key: 'avg_lux', header: 'Avg Lux' },
    { key: 'avg_lamp_life_used_pct', header: 'Avg Lamp Life %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'fit_for_use', header: 'Fit' },
    { key: 'needs_service', header: 'Needs Service' },
    { key: 'fungus_flagged', header: 'Fungus Flagged' },
    { key: 'avg_lux', header: 'Avg Lux' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'avg_cost_rupees', header: 'Avg Cost (INR)' },
    { key: 'overdue_or_escalated', header: 'Overdue / Escalated' },
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
    { key: 'ot_room_code', header: 'OT' },
    { key: 'scope_asset_tag', header: 'Asset' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'fungus_check', header: 'Fungus' },
    { key: 'focus_zoom_motor', header: 'Focus/Zoom' },
    { key: 'illumination_verdict', header: 'Illumination' },
    { key: 'lamp_life_used_pct', header: 'Lamp Life %' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Operating-Microscope &amp; Loupe Optics-Illumination Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Microscope QA log &mdash; specialty scope &times; magnification steps &times; illumination lux &times;
        xenon/LED lamp hours &times; balance-arm drift &times; focus/zoom motor &times; sterile-drape fit &times;
        fungus check &amp; CAPA closure. Founder-gated view: audit verdicts, hospital scorecards,
        root-cause pareto, and regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No microscope audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital optics scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Specialty &times; lamp-type matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No audits by specialty."
          rowKey={(r, i) => `${r.scope_specialty}-${r.lamp_type}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk scopes queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk scopes."
          rowKey={(r, i) => `${r.scope_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
