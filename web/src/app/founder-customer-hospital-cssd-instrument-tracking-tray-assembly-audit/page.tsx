import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { assembly_verdict: string; trays: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_trays: number;
  released: number;
  quarantined: number;
  recalls: number;
  missing_total: number;
  damaged_total: number;
  integrity_pct: number;
};
type MatrixRow = {
  specialty_set: string;
  chemical_indicator_result: string;
  trays: number;
  released: number;
  avg_instruments: number;
};
type TrendRow = {
  audit_date: string;
  trays: number;
  released: number;
  quarantined: number;
  missing_total: number;
  damaged_total: number;
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
  cssd_zone_code: string;
  tray_barcode: string;
  tray_name: string;
  audit_date: string;
  assembly_verdict: string;
  chemical_indicator_result: string | null;
  wrap_integrity: string | null;
  missing_count: number;
  damaged_count: number;
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
    supabase.rpc('founder_r3163_verdict_rollup'),
    supabase.rpc('founder_r3163_hospital_scorecard'),
    supabase.rpc('founder_r3163_specialty_integrity_matrix'),
    supabase.rpc('founder_r3163_audit_daily_trend'),
    supabase.rpc('founder_r3163_capa_status_board'),
    supabase.rpc('founder_r3163_root_cause_pareto'),
    supabase.rpc('founder_r3163_regulatory_impact_digest'),
    supabase.rpc('founder_r3163_high_risk_trays'),
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
    { key: 'assembly_verdict', header: 'Verdict' },
    { key: 'trays', header: 'Trays' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_trays', header: 'Trays' },
    { key: 'released', header: 'Released' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'recalls', header: 'Recalls / Rejects' },
    { key: 'missing_total', header: 'Missing' },
    { key: 'damaged_total', header: 'Damaged' },
    { key: 'integrity_pct', header: 'Integrity %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'specialty_set', header: 'Specialty Set' },
    { key: 'chemical_indicator_result', header: 'Chem Indicator' },
    { key: 'trays', header: 'Trays' },
    { key: 'released', header: 'Released' },
    { key: 'avg_instruments', header: 'Avg Instruments' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'trays', header: 'Trays' },
    { key: 'released', header: 'Released' },
    { key: 'quarantined', header: 'Quarantined' },
    { key: 'missing_total', header: 'Missing' },
    { key: 'damaged_total', header: 'Damaged' },
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
    { key: 'cssd_zone_code', header: 'Zone' },
    { key: 'tray_barcode', header: 'Barcode' },
    { key: 'tray_name', header: 'Tray' },
    { key: 'audit_date', header: 'Date' },
    { key: 'assembly_verdict', header: 'Verdict' },
    { key: 'chemical_indicator_result', header: 'Chem' },
    { key: 'wrap_integrity', header: 'Wrap' },
    { key: 'missing_count', header: 'Missing' },
    { key: 'damaged_count', header: 'Damaged' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital CSSD Instrument-Tracking &amp; Tray-Assembly Integrity Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        CSSD tray-assembly audit — specialty set &times; instruments expected/found &times; missing/damaged &times;
        chemical &amp; biological indicators &times; wrap integrity &times; load number &times; traceability barcode &amp; CAPA closure.
        Founder-gated view: assembly verdicts, hospital scorecards, root-cause pareto, and regulatory-impact digest across NABH &amp; CDSCO surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Assembly verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No trays audited yet."
          rowKey={(r, i) => String(r.assembly_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital integrity scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Specialty set &times; chemical-indicator matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No trays by specialty."
          rowKey={(r, i) => `${r.specialty_set}-${r.chemical_indicator_result}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk trays queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk trays."
          rowKey={(r, i) => `${r.tray_barcode}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
