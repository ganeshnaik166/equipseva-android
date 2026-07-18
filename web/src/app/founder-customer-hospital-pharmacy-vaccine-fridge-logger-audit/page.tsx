import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; units: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_units: number;
  compliant: number;
  major_gaps: number;
  critical: number;
  no_logger: number;
  excursions_30d: number;
  stock_at_risk_rupees: number;
  compliance_pct: number;
};
type UnitTypeRow = {
  unit_type: string;
  target_range: string;
  units: number;
  compliant: number;
  avg_excursions_30d: number;
  avg_interval_min: number | null;
};
type TrendRow = {
  audit_date: string;
  units_audited: number;
  compliant: number;
  gaps: number;
  critical: number;
  excursions_logged: number;
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
  pharmacy_code: string;
  unit_asset_tag: string;
  unit_type: string;
  audit_date: string;
  audit_verdict: string;
  excursion_count_30d: number;
  max_excursion_c: number | null;
  stock_value_at_risk_rupees: number | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    unitTypeRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3183_verdict_rollup'),
    supabase.rpc('founder_r3183_hospital_scorecard'),
    supabase.rpc('founder_r3183_unit_type_matrix'),
    supabase.rpc('founder_r3183_audit_daily_trend'),
    supabase.rpc('founder_r3183_capa_status_board'),
    supabase.rpc('founder_r3183_root_cause_pareto'),
    supabase.rpc('founder_r3183_regulatory_impact_digest'),
    supabase.rpc('founder_r3183_high_risk_units'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const unitTypeRows: UnitTypeRow[] = (unitTypeRes.data as UnitTypeRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'units', header: 'Units' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_units', header: 'Units' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'major_gaps', header: 'Major Gaps' },
    { key: 'critical', header: 'Critical' },
    { key: 'no_logger', header: 'No Logger' },
    { key: 'excursions_30d', header: 'Excursions 30d' },
    { key: 'stock_at_risk_rupees', header: 'Stock at Risk (INR)' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const unitTypeCols: Column<UnitTypeRow>[] = [
    { key: 'unit_type', header: 'Unit Type' },
    { key: 'target_range', header: 'Target Range' },
    { key: 'units', header: 'Units' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'avg_excursions_30d', header: 'Avg Excursions 30d' },
    { key: 'avg_interval_min', header: 'Avg Interval (min)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'units_audited', header: 'Units Audited' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'gaps', header: 'Gaps' },
    { key: 'critical', header: 'Critical' },
    { key: 'excursions_logged', header: 'Excursions Logged' },
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
    { key: 'pharmacy_code', header: 'Pharmacy' },
    { key: 'unit_asset_tag', header: 'Asset' },
    { key: 'unit_type', header: 'Type' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'excursion_count_30d', header: 'Excursions 30d' },
    { key: 'max_excursion_c', header: 'Max Excursion °C' },
    { key: 'stock_value_at_risk_rupees', header: 'Stock at Risk (INR)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Pharmacy Cold-Chain Vaccine-Fridge &amp; Ice-Pack Logger Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Pharmacy cold-chain audit — unit type &times; logger coverage &times; logging interval &times;
        30-day excursions &times; alarm health &times; stock value at risk &amp; CAPA closure.
        Founder-gated view: audit verdicts, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across NABH, CDSCO &amp; WHO-EVM surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No cold-chain audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital cold-chain scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Unit type &times; target range matrix</h2>
        <DataTable
          rows={unitTypeRows}
          columns={unitTypeCols}
          emptyMessage="No units by type."
          rowKey={(r, i) => `${r.unit_type}-${r.target_range}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Audit daily trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk units queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk units."
          rowKey={(r, i) => `${r.unit_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
