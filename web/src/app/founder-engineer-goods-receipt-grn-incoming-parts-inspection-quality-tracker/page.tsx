import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = { grn_verdict: string; receipts: number; pct: number };
type StoreRow = {
  store_location: string;
  total_receipts: number;
  accepted: number;
  with_deviation: number;
  held_or_rejected: number;
  major_damage: number;
  doc_incomplete: number;
  counterfeit_flag: number;
  accept_pct: number;
};
type MatrixRow = {
  equipment_family: string;
  oem_or_vendor: string;
  receipts: number;
  accepted: number;
  avg_put_away_hours: number;
  discrepancy_receipts: number;
};
type TrendRow = {
  receipt_date: string;
  receipts: number;
  accepted: number;
  rejected: number;
  damage_flag: number;
  counterfeit_flag: number;
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
  store_location: string;
  grn_code: string;
  oem_or_vendor: string;
  receipt_date: string;
  grn_verdict: string;
  physical_damage: string | null;
  discrepancy_type: string | null;
  documentation_complete: boolean | null;
  genuineness_verified: boolean | null;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    storeRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    regRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3336_grn_verdict_rollup'),
    supabase.rpc('founder_r3336_store_scorecard'),
    supabase.rpc('founder_r3336_family_vendor_matrix'),
    supabase.rpc('founder_r3336_daily_receipt_trend'),
    supabase.rpc('founder_r3336_capa_status_board'),
    supabase.rpc('founder_r3336_root_cause_pareto'),
    supabase.rpc('founder_r3336_regulatory_impact_digest'),
    supabase.rpc('founder_r3336_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const storeRows: StoreRow[] = (storeRes.data as StoreRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const regRows: RegRow[] = (regRes.data as RegRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'grn_verdict', header: 'GRN Verdict' },
    { key: 'receipts', header: 'Receipts' },
    { key: 'pct', header: 'Share %' },
  ];

  const storeCols: Column<StoreRow>[] = [
    { key: 'store_location', header: 'Store' },
    { key: 'total_receipts', header: 'Receipts' },
    { key: 'accepted', header: 'Accepted' },
    { key: 'with_deviation', header: 'With Deviation' },
    { key: 'held_or_rejected', header: 'Held / Rejected' },
    { key: 'major_damage', header: 'Major Damage' },
    { key: 'doc_incomplete', header: 'Doc Incomplete' },
    { key: 'counterfeit_flag', header: 'Counterfeit Flag' },
    { key: 'accept_pct', header: 'Accept %' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'equipment_family', header: 'Equipment Family' },
    { key: 'oem_or_vendor', header: 'OEM / Vendor' },
    { key: 'receipts', header: 'Receipts' },
    { key: 'accepted', header: 'Accepted' },
    { key: 'avg_put_away_hours', header: 'Avg Put-Away Hrs' },
    { key: 'discrepancy_receipts', header: 'Discrepancy Receipts' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'receipt_date', header: 'Date' },
    { key: 'receipts', header: 'Receipts' },
    { key: 'accepted', header: 'Accepted' },
    { key: 'rejected', header: 'Rejected' },
    { key: 'damage_flag', header: 'Major Damage' },
    { key: 'counterfeit_flag', header: 'Counterfeit Flag' },
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
    { key: 'store_location', header: 'Store' },
    { key: 'grn_code', header: 'GRN' },
    { key: 'oem_or_vendor', header: 'Vendor' },
    { key: 'receipt_date', header: 'Date' },
    { key: 'grn_verdict', header: 'Verdict' },
    { key: 'physical_damage', header: 'Damage' },
    { key: 'discrepancy_type', header: 'Discrepancy' },
    { key: 'documentation_complete', header: 'Docs Complete' },
    { key: 'genuineness_verified', header: 'Genuine' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        Engineer Goods-Receipt (GRN) &amp; Incoming-Parts Inspection Quality Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Inbound supply-chain QA log — equipment family &times; OEM/vendor &times; PO-match &times;
        physical-damage grade &times; documentation completeness &times; genuineness (anti-counterfeit)
        &times; lot-expiry capture &times; put-away time &times; discrepancy type &times; GRN verdict
        &amp; CAPA closure. Founder-gated view: verdict rollups, store scorecards, root-cause pareto,
        and regulatory-impact digest across NABH &amp; CDSCO surfaces. Ensures received spares match
        the PO, are genuine, undamaged, and correctly documented before entering stock.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. GRN verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No goods receipts logged yet."
          rowKey={(r, i) => String(r.grn_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Store GRN scorecard</h2>
        <DataTable
          rows={storeRows}
          columns={storeCols}
          emptyMessage="No store rollups."
          rowKey={(r, i) => String(r.store_location ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>3. Equipment-family &times; vendor matrix</h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No receipts by family."
          rowKey={(r, i) => `${r.equipment_family}-${r.oem_or_vendor}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Daily receipt trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.receipt_date ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk GRN queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk receipts."
          rowKey={(r, i) => `${r.grn_code}-${r.receipt_date}-${i}`}
        />
      </section>
    </main>
  );
}
