import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { status: string; entries: number; pct: number };
type HospRow = {
  hospital_name: string;
  entries: number;
  compliant: number;
  non_compliant: number;
  breach_notified: number;
  critical_gaps: number;
  avg_readiness: number;
  compliance_pct: number;
};
type CategoryRow = {
  data_category: string;
  processing_purpose: string;
  entries: number;
  avg_readiness: number;
  avg_retention_days: number;
};
type TrendRow = {
  breach_drill_date: string;
  drills: number;
  avg_readiness: number;
  high_gaps: number;
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
  entity_unit: string;
  register_ref: string;
  data_category: string;
  consent_basis: string;
  retention_days: number;
  breach_drill_date: string | null;
  gap_flag: string;
  status: string;
  dpo_owner: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    hospRes,
    categoryRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3165_status_rollup'),
    supabase.rpc('founder_r3165_hospital_scorecard'),
    supabase.rpc('founder_r3165_category_matrix'),
    supabase.rpc('founder_r3165_breach_drill_trend'),
    supabase.rpc('founder_r3165_capa_status_board'),
    supabase.rpc('founder_r3165_root_cause_pareto'),
    supabase.rpc('founder_r3165_regulatory_impact_digest'),
    supabase.rpc('founder_r3165_high_risk_register'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'status', header: 'Status' },
    { key: 'entries', header: 'Entries' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'entries', header: 'Entries' },
    { key: 'compliant', header: 'Compliant' },
    { key: 'non_compliant', header: 'Non-Compliant' },
    { key: 'breach_notified', header: 'Breach Notified' },
    { key: 'critical_gaps', header: 'Critical Gaps' },
    { key: 'avg_readiness', header: 'Avg Readiness' },
    { key: 'compliance_pct', header: 'Compliance %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'data_category', header: 'Data Category' },
    { key: 'processing_purpose', header: 'Processing Purpose' },
    { key: 'entries', header: 'Entries' },
    { key: 'avg_readiness', header: 'Avg Readiness' },
    { key: 'avg_retention_days', header: 'Avg Retention (days)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'breach_drill_date', header: 'Drill Date' },
    { key: 'drills', header: 'Drills' },
    { key: 'avg_readiness', header: 'Avg Readiness' },
    { key: 'high_gaps', header: 'Major / Critical Gaps' },
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
    { key: 'entity_unit', header: 'Unit' },
    { key: 'register_ref', header: 'Ref' },
    { key: 'data_category', header: 'Data Category' },
    { key: 'consent_basis', header: 'Consent Basis' },
    { key: 'retention_days', header: 'Retention (days)' },
    { key: 'breach_drill_date', header: 'Last Drill' },
    { key: 'gap_flag', header: 'Gap' },
    { key: 'status', header: 'Status' },
    { key: 'dpo_owner', header: 'DPO Owner' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Founder Data-Privacy (DPDP) Consent &amp; Breach-Readiness Register
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        DPDP register — data category &times; processing purpose &times; consent basis &times; retention days
        &times; subject-request SLA &times; breach-drill date &times; readiness score &times; gap flag &amp;
        status. Founder-gated view: status rollups, hospital scorecards, root-cause pareto, and
        regulatory-impact digest across DPDP &amp; CERT-In surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No register entries yet."
          rowKey={(r, i) => String(r.status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Hospital readiness scorecard</h2>
        <DataTable
          rows={hospRows}
          columns={hospCols}
          emptyMessage="No hospital rollups."
          rowKey={(r, i) => String(r.hospital_name ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Data category &times; purpose matrix</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No entries by category."
          rowKey={(r, i) => `${r.data_category}-${r.processing_purpose}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Breach-drill readiness trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No breach-drill data."
          rowKey={(r, i) => String(r.breach_drill_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk register queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk register entries."
          rowKey={(r, i) => `${r.register_ref}-${i}`}
        />
      </section>
    </main>
  );
}
