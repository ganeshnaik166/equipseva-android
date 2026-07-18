import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  compliant: number;
  major_nc: number;
  critical: number;
  detector_fails: number;
  routes_blocked: number;
  noc_lapsed: number;
  compliance_pct: number;
};
type AssetRow = {
  asset_type: string;
  audits: number;
  compliant: number;
  minor_nc: number;
  major_nc: number;
  critical: number;
  avg_hydrant_flow_lpm: number | null;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  compliant: number;
  critical: number;
  detector_fails: number;
  routes_blocked: number;
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
  building_block: string;
  floor_zone: string;
  asset_tag: string;
  asset_type: string;
  audit_date: string;
  audit_verdict: string;
  evacuation_route_status: string;
  noc_status: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    assetRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3195_audit_verdict_rollup'),
    supabase.rpc('founder_r3195_hospital_scorecard'),
    supabase.rpc('founder_r3195_asset_type_matrix'),
    supabase.rpc('founder_r3195_daily_trend'),
    supabase.rpc('founder_r3195_capa_status_board'),
    supabase.rpc('founder_r3195_root_cause_pareto'),
    supabase.rpc('founder_r3195_regulatory_impact_digest'),
    supabase.rpc('founder_r3195_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const assetRows: AssetRow[] = (assetRes.data as AssetRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'major_nc', header: 'Major NC' },
    { key: 'critical', header: 'Critical' },
    { key: 'detector_fails', header: 'Detector Fails' },
    { key: 'routes_blocked', header: 'Routes Blocked' },
    { key: 'noc_lapsed', header: 'NOC Lapsed' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const assetCols: Column<AssetRow>[] = [
    { key: 'asset_type', header: 'Asset Type' },
    { key: 'audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'minor_nc', header: 'Minor NC' },
    { key: 'major_nc', header: 'Major NC' },
    { key: 'critical', header: 'Critical' },
    { key: 'avg_hydrant_flow_lpm', header: 'Avg Flow (LPM)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'critical', header: 'Critical' },
    { key: 'detector_fails', header: 'Detector Fails' },
    { key: 'routes_blocked', header: 'Routes Blocked' },
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
    { key: 'building_block', header: 'Block' },
    { key: 'floor_zone', header: 'Floor / Zone' },
    { key: 'asset_tag', header: 'Asset' },
    { key: 'asset_type', header: 'Type' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'evacuation_route_status', header: 'Evac Route' },
    { key: 'noc_status', header: 'NOC' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Fire-Safety Equipment (Extinguisher / Hydrant / Smoke-Detector) Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Fire-safety asset audit log &mdash; asset type &times; pressure gauge &times; refill due &times;
        detector test &times; panel zone &times; evacuation route &times; NOC validity &amp; CAPA closure.
        Founder-gated view: audit verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across fire-NOC, NABH &amp; municipal surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital fire-safety scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Asset type &times; verdict matrix</h2>
        <DataTable
          rows={assetRows}
          columns={assetCols}
          emptyMessage="No audits by asset type."
          rowKey={(r, i) => `${r.asset_type}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk assets queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk assets."
          rowKey={(r, i) => `${r.asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
