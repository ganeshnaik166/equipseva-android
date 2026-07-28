import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = {
  provision_status: string;
  items: number;
  gross_exposure_rupees: number;
  provision_made_rupees: number;
  pct: number;
};
type TypeRow = {
  liability_type: string;
  items: number;
  gross_exposure_rupees: number;
  provision_made_rupees: number;
  contingent_disclosed_rupees: number;
  under_provided: number;
  no_provision: number;
  coverage_pct: number;
};
type MatrixRow = {
  liability_type: string;
  probability: string;
  items: number;
  gross_exposure_rupees: number;
  under_provided: number;
};
type TrendRow = {
  period_month: string;
  items: number;
  gross_exposure_rupees: number;
  provision_made_rupees: number;
  contingent_disclosed_rupees: number;
  under_provided: number;
};
type CapaRow = {
  capa_status: string;
  actions: number;
  avg_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type DigestRow = {
  finding_category: string;
  actions: number;
  open_actions: number;
  total_impact_rupees: number;
};
type RiskRow = {
  item_name: string;
  liability_type: string;
  probability: string;
  provision_status: string;
  gross_exposure_rupees: number;
  provision_made_rupees: number;
  contingent_disclosed_rupees: number;
  expected_resolution: string | null;
  counterparty: string | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    typeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3533_provision_status_rollup'),
    supabase.rpc('founder_r3533_liability_type_scorecard'),
    supabase.rpc('founder_r3533_liability_probability_matrix'),
    supabase.rpc('founder_r3533_monthly_exposure_trend'),
    supabase.rpc('founder_r3533_capa_status_board'),
    supabase.rpc('founder_r3533_root_cause_pareto'),
    supabase.rpc('founder_r3533_exposure_impact_digest'),
    supabase.rpc('founder_r3533_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const typeRows: TypeRow[] = (typeRes.data as TypeRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'provision_status', header: 'Provision Status' },
    { key: 'items', header: 'Items' },
    { key: 'gross_exposure_rupees', header: 'Gross Exposure (INR)' },
    { key: 'provision_made_rupees', header: 'Provision Made (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const typeCols: Column<TypeRow>[] = [
    { key: 'liability_type', header: 'Liability Type' },
    { key: 'items', header: 'Items' },
    { key: 'gross_exposure_rupees', header: 'Gross Exposure (INR)' },
    { key: 'provision_made_rupees', header: 'Provision Made (INR)' },
    { key: 'contingent_disclosed_rupees', header: 'Contingent Disclosed (INR)' },
    { key: 'under_provided', header: 'Under-Provided' },
    { key: 'no_provision', header: 'No Provision' },
    { key: 'coverage_pct', header: 'Coverage %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'liability_type', header: 'Liability Type' },
    { key: 'probability', header: 'Probability' },
    { key: 'items', header: 'Items' },
    { key: 'gross_exposure_rupees', header: 'Gross Exposure (INR)' },
    { key: 'under_provided', header: 'Under-Provided' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'period_month', header: 'Month' },
    { key: 'items', header: 'Items' },
    { key: 'gross_exposure_rupees', header: 'Gross Exposure (INR)' },
    { key: 'provision_made_rupees', header: 'Provision Made (INR)' },
    { key: 'contingent_disclosed_rupees', header: 'Contingent Disclosed (INR)' },
    { key: 'under_provided', header: 'Under-Provided' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'actions', header: 'Actions' },
    { key: 'avg_impact_rupees', header: 'Avg Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const digestCols: Column<DigestRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'actions', header: 'Actions' },
    { key: 'open_actions', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'item_name', header: 'Item' },
    { key: 'liability_type', header: 'Type' },
    { key: 'probability', header: 'Probability' },
    { key: 'provision_status', header: 'Status' },
    { key: 'gross_exposure_rupees', header: 'Gross Exposure (INR)' },
    { key: 'provision_made_rupees', header: 'Provision Made (INR)' },
    { key: 'contingent_disclosed_rupees', header: 'Contingent Disclosed (INR)' },
    { key: 'expected_resolution', header: 'Expected Resolution' },
    { key: 'counterparty', header: 'Counterparty' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Provisions / Contingent-Liability Register Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder-gated provisions &amp; contingent-liability register — liability type (litigation, tax
        disputes, warranty, guarantee, regulatory, onerous contracts) &times; probability (remote &rarr;
        virtually certain) &times; provision adequacy &times; gross exposure &times; provision made
        &times; contingent disclosed &times; expected resolution &amp; monthly trend, with CAPA closure.
        Board view: provision-status rollups, type scorecards, root-cause pareto, exposure-impact digest,
        and the high-risk queue of under-provided, probable &amp; large-exposure items.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Provision-status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No register items logged yet."
          rowKey={(r, i) => String(r.provision_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Liability-type scorecard</h2>
        <DataTable
          rows={typeRows}
          columns={typeCols}
          emptyMessage="No liability-type rollups."
          rowKey={(r, i) => String(r.liability_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Liability type &times; probability matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No items by liability type."
          rowKey={(r, i) => `${r.liability_type}-${r.probability}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly exposure trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.period_month ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>5. CAPA status board</h2>
        <DataTable
          rows={capaRows}
          columns={capaCols}
          emptyMessage="No CAPA actions."
          rowKey={(r, i) => String(r.capa_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Exposure-impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No finding-category rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk items."
          rowKey={(r, i) => `${r.item_name}-${i}`}
        />
      </section>
    </main>
  );
}
