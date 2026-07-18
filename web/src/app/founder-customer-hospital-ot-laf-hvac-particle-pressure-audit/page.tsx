import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { audit_verdict: string; audits: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  compliant: number;
  minor: number;
  major: number;
  critical: number;
  hepa_fail: number;
  pressure_fail: number;
  compliance_pct: number;
};
type CategoryRow = {
  ot_type: string;
  iso_class_target: string;
  audits: number;
  compliant: number;
  avg_particle: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  compliant: number;
  major_plus: number;
  avg_ach: number;
  avg_pressure: number;
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
  ahu_asset_tag: string;
  audit_date: string;
  audit_verdict: string;
  iso_class_measured: string | null;
  particle_verdict: string | null;
  pressure_verdict: string | null;
  hepa_integrity_result: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    categoryRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3158_verdict_rollup'),
    supabase.rpc('founder_r3158_hospital_scorecard'),
    supabase.rpc('founder_r3158_category_matrix'),
    supabase.rpc('founder_r3158_daily_trend'),
    supabase.rpc('founder_r3158_capa_status_board'),
    supabase.rpc('founder_r3158_root_cause_pareto'),
    supabase.rpc('founder_r3158_regulatory_impact_digest'),
    supabase.rpc('founder_r3158_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
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
    { key: 'minor', header: 'Minor' },
    { key: 'major', header: 'Major' },
    { key: 'critical', header: 'Critical' },
    { key: 'hepa_fail', header: 'HEPA Fail' },
    { key: 'pressure_fail', header: 'Pressure Fail' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'ot_type', header: 'OT Type' },
    { key: 'iso_class_target', header: 'ISO Target' },
    { key: 'audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'avg_particle', header: 'Avg Particle 0.5µm/m³' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'major_plus', header: 'Major+' },
    { key: 'avg_ach', header: 'Avg ACH' },
    { key: 'avg_pressure', header: 'Avg Pressure Pa' },
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
    { key: 'ahu_asset_tag', header: 'AHU' },
    { key: 'audit_date', header: 'Date' },
    { key: 'audit_verdict', header: 'Verdict' },
    { key: 'iso_class_measured', header: 'ISO Measured' },
    { key: 'particle_verdict', header: 'Particle' },
    { key: 'pressure_verdict', header: 'Pressure' },
    { key: 'hepa_integrity_result', header: 'HEPA' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital OT Laminar-Air-Flow &amp; HVAC Particle-Count / Pressure Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        OT air-quality validation log — ISO class target/measured &times; particle count 0.5&micro;m &times; air
        changes/hr &times; positive pressure Pa &times; temperature/humidity &times; HEPA integrity &amp; CAPA closure.
        Founder-gated view: verdict rollups, hospital scorecards, root-cause pareto, and regulatory-impact digest
        across NABH, CDSCO &amp; ISO 14644 surfaces.
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital compliance scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. OT type &times; ISO class matrix</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No audits by category."
          rowKey={(r, i) => `${r.ot_type}-${r.iso_class_target}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily air-quality trend</h2>
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk / priority queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk audits."
          rowKey={(r, i) => `${r.ahu_asset_tag}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
