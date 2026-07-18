import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { readiness_verdict: string; carts: number; pct: number };
type HospRow = {
  hospital_name: string;
  total_audits: number;
  fully_ready: number;
  restock_required: number;
  critical_gaps: number;
  out_of_service: number;
  seal_issues: number;
  defib_issues: number;
  checklist_signed_pct: number;
  readiness_pct: number;
};
type LocRow = {
  cart_location: string;
  audits: number;
  fully_ready: number;
  critical_gaps: number;
  avg_drug_expiry_days: number;
  avg_restock_tat_hours: number;
};
type TrendRow = {
  audit_date: string;
  audits: number;
  fully_ready: number;
  critical_gaps: number;
  seal_intact: number;
  checklist_signed: number;
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
  ward_name: string;
  cart_code: string;
  audit_date: string;
  readiness_verdict: string;
  seal_status: string;
  defib_status: string;
  suction_status: string;
  o2_cylinder_level: string;
  drug_expiry_nearest_days: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    hospRes,
    locRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3187_readiness_verdict_rollup'),
    supabase.rpc('founder_r3187_hospital_scorecard'),
    supabase.rpc('founder_r3187_location_matrix'),
    supabase.rpc('founder_r3187_daily_trend'),
    supabase.rpc('founder_r3187_capa_status_board'),
    supabase.rpc('founder_r3187_root_cause_pareto'),
    supabase.rpc('founder_r3187_regulatory_impact_digest'),
    supabase.rpc('founder_r3187_high_risk_carts'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const hospRows: HospRow[] = (hospRes.data as HospRow[]) ?? [];
  const locRows: LocRow[] = (locRes.data as LocRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'carts', header: 'Carts' },
    { key: 'pct', header: 'Share %' },
  ];

  const hospCols: Column<HospRow>[] = [
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'total_audits', header: 'Audits' },
    { key: 'fully_ready', header: 'Fully Ready' },
    { key: 'restock_required', header: 'Restock Reqd' },
    { key: 'critical_gaps', header: 'Critical Gaps' },
    { key: 'out_of_service', header: 'Out of Service' },
    { key: 'seal_issues', header: 'Seal Issues' },
    { key: 'defib_issues', header: 'Defib Issues' },
    { key: 'checklist_signed_pct', header: 'Checklist %' },
    { key: 'readiness_pct', header: 'Readiness %' },
  ];

  const locCols: Column<LocRow>[] = [
    { key: 'cart_location', header: 'Location' },
    { key: 'audits', header: 'Audits' },
    { key: 'fully_ready', header: 'Fully Ready' },
    { key: 'critical_gaps', header: 'Critical Gaps' },
    { key: 'avg_drug_expiry_days', header: 'Avg Nearest Expiry (days)' },
    { key: 'avg_restock_tat_hours', header: 'Avg Restock TAT (hrs)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'audit_date', header: 'Date' },
    { key: 'audits', header: 'Audits' },
    { key: 'fully_ready', header: 'Fully Ready' },
    { key: 'critical_gaps', header: 'Critical Gaps' },
    { key: 'seal_intact', header: 'Seal Intact' },
    { key: 'checklist_signed', header: 'Checklist Signed' },
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
    { key: 'ward_name', header: 'Ward' },
    { key: 'cart_code', header: 'Cart' },
    { key: 'audit_date', header: 'Date' },
    { key: 'readiness_verdict', header: 'Verdict' },
    { key: 'seal_status', header: 'Seal' },
    { key: 'defib_status', header: 'Defib' },
    { key: 'suction_status', header: 'Suction' },
    { key: 'o2_cylinder_level', header: 'O2 Level' },
    { key: 'drug_expiry_nearest_days', header: 'Nearest Expiry (days)' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Customer Hospital Emergency-Trolley (Crash-Cart) Readiness &amp; Restock Audit
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Crash-cart audit log &mdash; location &times; seal &times; drug-expiry &times; defib &times;
        suction &times; airway kit &times; O2 cylinder level &times; checklist &amp; restock TAT with
        CAPA closure. Founder-gated view: readiness verdicts, hospital scorecards, root-cause pareto,
        and regulatory-impact digest across NABH &amp; code-blue readiness surfaces.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Readiness verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No crash-cart audits logged yet."
          rowKey={(r, i) => String(r.readiness_verdict ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Cart-location readiness matrix</h2>
        <DataTable
          rows={locRows}
          columns={locCols}
          emptyMessage="No audits by location."
          rowKey={(r, i) => String(r.cart_location ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk carts queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk carts."
          rowKey={(r, i) => `${r.cart_code}-${r.audit_date}-${i}`}
        />
      </section>
    </main>
  );
}
