import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  compliant: number;
  minor_observations: number;
  major_non_compliant: number;
  critical_stop: number;
  avg_excursions_30d: number;
  compliance_pct: number;
};
type MatrixRow = {
  storage_location_type: string;
  temp_range_compliance: string;
  audits: number;
  avg_excursions_30d: number;
  min_stock_expiry_days: number | null;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  within_range: number;
  minor_excursions: number;
  major_excursions: number;
  no_data: number;
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
  ward_name: string;
  storage_unit_tag: string;
  storage_location_type: string;
  audit_date: string;
  audit_verdict: string;
  temp_range_compliance: string;
  excursions_30d: number;
  nearest_stock_expiry_days: number | null;
  lock_access_control: string;
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
    supabase.rpc('founder_r3239_verdict_rollup'),
    supabase.rpc('founder_r3239_hospital_scorecard'),
    supabase.rpc('founder_r3239_location_compliance_matrix'),
    supabase.rpc('founder_r3239_daily_trend'),
    supabase.rpc('founder_r3239_capa_status_board'),
    supabase.rpc('founder_r3239_root_cause_pareto'),
    supabase.rpc('founder_r3239_regulatory_impact_digest'),
    supabase.rpc('founder_r3239_high_risk_storage_queue'),
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
    { key: 'audits', header: 'Audits' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'minor_observations', header: 'Minor Obs' },
    { key: 'major_non_compliant', header: 'Major NC' },
    { key: 'critical_stop', header: 'Critical Stop' },
    { key: 'avg_excursions_30d', header: 'Avg Excursions 30d' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'storage_location_type', header: 'Location Type' },
    { key: 'temp_range_compliance', header: 'Temp Compliance' },
    { key: 'audits', header: 'Audits' },
    { key: 'avg_excursions_30d', header: 'Avg Excursions 30d' },
    { key: 'min_stock_expiry_days', header: 'Min Expiry (days)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'within_range', header: 'Within Range' },
    { key: 'minor_excursions', header: 'Minor Excursion' },
    { key: 'major_excursions', header: 'Major Excursion' },
    { key: 'no_data', header: 'No Data' },
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
    { key: 'ward_name', header: 'Ward' },
    { key: 'storage_unit_tag', header: 'Unit' },
    { key: 'storage_location_type', header: 'Location Type' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'temp_range_compliance', header: 'Temp Compliance' },
    { key: 'excursions_30d', header: 'Excursions 30d' },
    { key: 'nearest_stock_expiry_days', header: 'Expiry (days)' },
    { key: 'lock_access_control', header: 'Lock / Access' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Medication-Refrigerator &amp; Ward-Drug-Storage Temperature Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Med storage QA — location type &times; temp-range compliance &times; data logger &times;
        30-day excursions &times; nearest stock expiry &times; lock/access control &times;
        high-alert segregation &amp; CAPA closure. Founder-gated view: audit verdicts, hospital
        scorecards, root-cause pareto, and regulatory-impact digest across NABH &amp; state drug
        authority surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Audit verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No storage audits logged yet."
          rowKey={(r, i) => String(r.audit_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital compliance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Location type &times; temp compliance matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No location rollups."
          rowKey={(r, i) => `${r.storage_location_type}-${r.temp_range_compliance}-${i}`}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk storage units queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk storage units."
          rowKey={(r, i) => `${r.storage_unit_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
