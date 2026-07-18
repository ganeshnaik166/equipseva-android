import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; devices: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_devices: number;
  fit_for_use: number;
  repair_needed: number;
  replace_immediately: number;
  lock_failures: number;
  high_risk_devices: number;
  avg_risk_score: number;
  fit_pct: number;
};
type MatrixRow = {
  accessory_type: string;
  attachment_interface: string;
  devices: number;
  fit_for_use: number;
  avg_risk_score: number;
};
type TrendRow = {
  audit_date: string;
  audited: number;
  lock_pass: number;
  lock_fail: number;
  high_risk: number;
  inventory_gaps: number;
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
  ot_room_code: string;
  accessory_asset_tag: string;
  accessory_type: string;
  audit_date: string;
  audit_verdict: string;
  attachment_lock_test: string;
  padding_integrity: string;
  pressure_injury_risk_score: number;
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
    supabase.rpc('founder_r3227_verdict_rollup'),
    supabase.rpc('founder_r3227_hospital_scorecard'),
    supabase.rpc('founder_r3227_accessory_type_matrix'),
    supabase.rpc('founder_r3227_audit_daily_trend'),
    supabase.rpc('founder_r3227_capa_status_board'),
    supabase.rpc('founder_r3227_root_cause_pareto'),
    supabase.rpc('founder_r3227_regulatory_impact_digest'),
    supabase.rpc('founder_r3227_high_risk_queue'),
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
    { key: 'devices', header: 'Devices' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_devices', header: 'Devices' },
    { key: 'fit_for_use', header: 'Fit' },
    { key: 'repair_needed', header: 'Repair' },
    { key: 'replace_immediately', header: 'Replace' },
    { key: 'lock_failures', header: 'Lock Fails' },
    { key: 'high_risk_devices', header: 'High Risk' },
    { key: 'avg_risk_score', header: 'Avg Risk' },
    { key: 'fit_pct', header: 'Fit %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'accessory_type', header: 'Accessory Type' },
    { key: 'attachment_interface', header: 'Attachment' },
    { key: 'devices', header: 'Devices' },
    { key: 'fit_for_use', header: 'Fit' },
    { key: 'avg_risk_score', header: 'Avg Risk' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audited', header: 'Audited' },
    { key: 'lock_pass', header: 'Lock Pass' },
    { key: 'lock_fail', header: 'Lock Fail' },
    { key: 'high_risk', header: 'High Risk' },
    { key: 'inventory_gaps', header: 'Inventory Gaps' },
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
    { key: 'ot_room_code', header: 'OT' },
    { key: 'accessory_asset_tag', header: 'Asset' },
    { key: 'accessory_type', header: 'Type' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'attachment_lock_test', header: 'Lock Test' },
    { key: 'padding_integrity', header: 'Padding' },
    { key: 'pressure_injury_risk_score', header: 'Risk' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Surgical-Table Accessories &amp; Patient-Positioning Device Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Positioning QA — accessory type &times; attachment lock test &times; padding integrity &times;
        pressure-injury risk &times; sterilizable &amp; load rating &amp; inventory completeness with CAPA closure.
        Founder-gated view: audit verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH &amp; ISO 13485 surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No device audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital positioning-safety scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Accessory type &times; attachment matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No accessory breakdown."
          rowKey={(r, i) => `${r.accessory_type}-${r.attachment_interface}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk device queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk devices."
          rowKey={(r, i) => `${r.accessory_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
