import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type StatusRow = { classification_status: string; tickets: number; pct: number };
type CategoryRow = {
  repair_category: string;
  tickets: number;
  total_cost_rupees: number;
  recovered_rupees: number;
  unrecovered_rupees: number;
  recovery_pct: number;
  misclassified: number;
};
type MatrixRow = {
  repair_category: string;
  classification_status: string;
  tickets: number;
  total_cost_rupees: number;
  recovered_rupees: number;
};
type TrendRow = {
  repair_month: string;
  tickets: number;
  total_cost_rupees: number;
  recovered_rupees: number;
  unrecovered_rupees: number;
  misclassified: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  total_impact_rupees: number;
  overdue_flag: number;
};
type CauseRow = {
  root_cause: string;
  occurrences: number;
  total_impact_rupees: number;
  pct: number;
};
type FindingRow = {
  finding_category: string;
  findings: number;
  open_findings: number;
  total_impact_rupees: number;
};
type RiskRow = {
  engineer_name: string;
  hospital_name: string;
  ticket_code: string;
  device_model: string;
  repair_category: string;
  classification_status: string;
  total_cost_rupees: number;
  recovered_rupees: number;
  unrecovered_rupees: number;
  repair_date: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    statusRes,
    categoryRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    findingRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3516_classification_status_rollup'),
    supabase.rpc('founder_r3516_repair_category_scorecard'),
    supabase.rpc('founder_r3516_category_status_matrix'),
    supabase.rpc('founder_r3516_monthly_cost_trend'),
    supabase.rpc('founder_r3516_capa_status_board'),
    supabase.rpc('founder_r3516_root_cause_pareto'),
    supabase.rpc('founder_r3516_finding_impact_digest'),
    supabase.rpc('founder_r3516_high_risk_queue'),
  ]);

  const statusRows: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const categoryRows: CategoryRow[] = (categoryRes.data as CategoryRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const findingRows: FindingRow[] = (findingRes.data as FindingRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const statusCols: Column<StatusRow>[] = [
    { key: 'classification_status', header: 'Classification Status' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'pct', header: 'Share %' },
  ];

  const categoryCols: Column<CategoryRow>[] = [
    { key: 'repair_category', header: 'Repair Category' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'recovered_rupees', header: 'Recovered (INR)' },
    { key: 'unrecovered_rupees', header: 'Unrecovered (INR)' },
    { key: 'recovery_pct', header: 'Recovery %' },
    { key: 'misclassified', header: 'Flagged' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'repair_category', header: 'Repair Category' },
    { key: 'classification_status', header: 'Status' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'recovered_rupees', header: 'Recovered (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'repair_month', header: 'Month' },
    { key: 'tickets', header: 'Tickets' },
    { key: 'total_cost_rupees', header: 'Total Cost (INR)' },
    { key: 'recovered_rupees', header: 'Recovered (INR)' },
    { key: 'unrecovered_rupees', header: 'Unrecovered (INR)' },
    { key: 'misclassified', header: 'Flagged' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'overdue_flag', header: 'Overdue / Escalated' },
  ];

  const causeCols: Column<CauseRow>[] = [
    { key: 'root_cause', header: 'Root Cause' },
    { key: 'occurrences', header: 'Occurrences' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const findingCols: Column<FindingRow>[] = [
    { key: 'finding_category', header: 'Finding Category' },
    { key: 'findings', header: 'Findings' },
    { key: 'open_findings', header: 'Open' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'engineer_name', header: 'Engineer' },
    { key: 'hospital_name', header: 'Hospital' },
    { key: 'ticket_code', header: 'Ticket' },
    { key: 'device_model', header: 'Device' },
    { key: 'repair_category', header: 'Category' },
    { key: 'classification_status', header: 'Status' },
    { key: 'total_cost_rupees', header: 'Total (INR)' },
    { key: 'recovered_rupees', header: 'Recovered (INR)' },
    { key: 'unrecovered_rupees', header: 'Unrecovered (INR)' },
    { key: 'repair_date', header: 'Repair Date' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Warranty-vs-Billable Repair-Cost Classification Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Repair-cost classification ledger — repair category (in-warranty, out-of-warranty, AMC-covered,
        goodwill, chargeable, recall) &times; parts, labor &amp; total cost &times; amount recovered
        &times; classification accuracy (correct, misclassified, under-review, disputed, corrected)
        &amp; CAPA closure. Founder-gated view: classification distribution, category scorecards,
        cost-recovery vs leakage, root-cause pareto and a high-risk queue of misclassified, disputed
        &amp; unrecovered repairs.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Classification status distribution</h2>
        <DataTable
          rows={statusRows}
          columns={statusCols}
          emptyMessage="No repairs classified yet."
          rowKey={(r, i) => String(r.classification_status ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Repair-category scorecard</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No category rollups."
          rowKey={(r, i) => String(r.repair_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Repair category &times; classification status matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No matrix data."
          rowKey={(r, i) => `${r.repair_category}-${r.classification_status}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly cost trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.repair_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. Cost-recovery impact digest</h2>
        <DataTable
          rows={findingRows}
          columns={findingCols}
          emptyMessage="No finding-impact rollups."
          rowKey={(r, i) => String(r.finding_category ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk repair queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk repairs."
          rowKey={(r, i) => `${r.ticket_code}-${i}`}
        />
      </section>
    </main>
  );
}
