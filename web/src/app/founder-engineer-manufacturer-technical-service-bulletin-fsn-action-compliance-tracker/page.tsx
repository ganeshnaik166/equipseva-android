import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  compliance_verdict: string;
  bulletins: number;
  affected_units: number;
  overdue_units: number;
  pct: number;
};
type VendorRow = {
  oem_vendor: string;
  total_bulletins: number;
  fully_actioned: number;
  on_track: number;
  at_risk: number;
  overdue: number;
  affected_units: number;
  units_actioned: number;
  action_pct: number;
};
type MatrixRow = {
  bulletin_type: string;
  equipment_type: string;
  bulletins: number;
  affected_units: number;
  units_actioned: number;
  overdue_units: number;
  avg_completion_pct: number;
};
type TrendRow = {
  issue_date: string;
  bulletins: number;
  affected_units: number;
  units_actioned: number;
  overdue_units: number;
  at_risk_or_overdue: number;
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
  oem_vendor: string;
  bulletin_ref: string;
  site_name: string;
  equipment_type: string;
  criticality: string;
  oem_deadline: string;
  compliance_verdict: string;
  affected_units: number;
  units_actioned: number;
  overdue_units: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    vendorRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3304_compliance_verdict_rollup'),
    supabase.rpc('founder_r3304_vendor_scorecard'),
    supabase.rpc('founder_r3304_bulletin_equipment_matrix'),
    supabase.rpc('founder_r3304_bulletin_trend'),
    supabase.rpc('founder_r3304_capa_status_board'),
    supabase.rpc('founder_r3304_root_cause_pareto'),
    supabase.rpc('founder_r3304_regulatory_impact_digest'),
    supabase.rpc('founder_r3304_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const vendorRows: VendorRow[] = (vendorRes.data as VendorRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'compliance_verdict', header: 'Compliance Verdict' },
    { key: 'bulletins', header: 'Bulletins' },
    { key: 'affected_units', header: 'Affected Units' },
    { key: 'overdue_units', header: 'Overdue Units' },
    { key: 'pct', header: 'Share %' },
  ];

  const vendorCols: Column<VendorRow>[] = [
    { key: 'oem_vendor', header: 'OEM Vendor' },
    { key: 'total_bulletins', header: 'Bulletins' },
    { key: 'fully_actioned', header: 'Fully Actioned' },
    { key: 'on_track', header: 'On Track' },
    { key: 'at_risk', header: 'At Risk' },
    { key: 'overdue', header: 'Overdue' },
    { key: 'affected_units', header: 'Affected Units' },
    { key: 'units_actioned', header: 'Units Actioned' },
    { key: 'action_pct', header: 'Action %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'bulletin_type', header: 'Bulletin Type' },
    { key: 'equipment_type', header: 'Equipment Type' },
    { key: 'bulletins', header: 'Bulletins' },
    { key: 'affected_units', header: 'Affected Units' },
    { key: 'units_actioned', header: 'Units Actioned' },
    { key: 'overdue_units', header: 'Overdue Units' },
    { key: 'avg_completion_pct', header: 'Avg Completion %' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'issue_date', header: 'Issue Date' },
    { key: 'bulletins', header: 'Bulletins' },
    { key: 'affected_units', header: 'Affected Units' },
    { key: 'units_actioned', header: 'Units Actioned' },
    { key: 'overdue_units', header: 'Overdue Units' },
    { key: 'at_risk_or_overdue', header: 'At-Risk / Overdue' },
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
    { key: 'oem_vendor', header: 'OEM Vendor' },
    { key: 'bulletin_ref', header: 'Bulletin Ref' },
    { key: 'site_name', header: 'Site' },
    { key: 'equipment_type', header: 'Equipment' },
    { key: 'criticality', header: 'Criticality' },
    { key: 'oem_deadline', header: 'OEM Deadline' },
    { key: 'compliance_verdict', header: 'Verdict' },
    { key: 'affected_units', header: 'Affected' },
    { key: 'units_actioned', header: 'Actioned' },
    { key: 'overdue_units', header: 'Overdue' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Manufacturer TSB &amp; FSN Action-Compliance Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        OEM bulletin action across the installed base — vendor &times; bulletin type
        (TSB / FSN / mandatory upgrade / voluntary recall / software advisory) &times; equipment type
        &times; criticality &times; affected/actioned/overdue units &times; OEM deadline &times;
        compliance verdict &amp; CAPA expedite/escalation. Founder-gated view: verdict rollup, vendor
        scorecards, root-cause pareto, and regulatory-impact digest across CDSCO &amp; MDR field-action
        surfaces. Overdue units when actioned &lt; affected past the OEM deadline.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Compliance verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No bulletin actions logged yet."
          rowKey={(r, i) => String(r.compliance_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. OEM vendor scorecard</h2>
        <DataTable
          rows={vendorRows}
          columns={vendorCols}
          emptyMessage="No vendor rollups."
          rowKey={(r, i) => String(r.oem_vendor ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Bulletin type &times; equipment matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No bulletins by type."
          rowKey={(r, i) => `${r.bulletin_type}-${r.equipment_type}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily bulletin issue trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.issue_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk bulletin action queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk bulletins."
          rowKey={(r, i) => `${r.bulletin_ref}-${r.site_name}-${i}`}
        />
      </section>
    </main>
  );
}
