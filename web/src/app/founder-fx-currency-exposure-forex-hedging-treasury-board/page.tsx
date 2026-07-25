import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type VerdictRow = {
  hedge_verdict: string;
  exposures: number;
  total_exposure_rupees: number;
  net_mtm_rupees: number;
  pct: number;
};
type PairRow = {
  currency_pair: string;
  exposures: number;
  total_exposure_rupees: number;
  adequately_hedged: number;
  under_hedged: number;
  unhedged_exposed: number;
  avg_hedge_ratio_pct: number;
  net_mtm_rupees: number;
};
type MatrixRow = {
  exposure_type: string;
  hedge_instrument: string;
  exposures: number;
  total_exposure_rupees: number;
  avg_hedge_ratio_pct: number;
  net_mtm_rupees: number;
};
type TrendRow = {
  value_month: string;
  exposures: number;
  total_exposure_rupees: number;
  net_mtm_rupees: number;
  mtm_loss_rupees: number;
  unhedged_count: number;
};
type CapaRow = {
  capa_status: string;
  findings: number;
  total_impact_rupees: number;
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
  exposure_type: string;
  exposures: number;
  total_exposure_rupees: number;
  mtm_gain_rupees: number;
  mtm_loss_rupees: number;
  net_mtm_rupees: number;
};
type RiskRow = {
  exposure_name: string;
  exposure_code: string;
  currency_pair: string;
  exposure_type: string;
  exposure_amount_rupees: number;
  hedge_instrument: string;
  hedge_ratio_pct: number | null;
  mtm_gain_loss_rupees: number | null;
  value_date: string | null;
  counterparty_bank: string | null;
  hedge_verdict: string;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    verdictRes,
    pairRes,
    matrixRes,
    trendRes,
    capaRes,
    causeRes,
    digestRes,
    riskRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3429_hedge_verdict_rollup'),
    supabase.rpc('founder_r3429_currency_pair_scorecard'),
    supabase.rpc('founder_r3429_exposure_hedge_matrix'),
    supabase.rpc('founder_r3429_monthly_mtm_trend'),
    supabase.rpc('founder_r3429_capa_status_board'),
    supabase.rpc('founder_r3429_root_cause_pareto'),
    supabase.rpc('founder_r3429_mtm_impact_digest'),
    supabase.rpc('founder_r3429_high_risk_queue'),
  ]);

  const verdictRows: VerdictRow[] = (verdictRes.data as VerdictRow[]) ?? [];
  const pairRows: PairRow[] = (pairRes.data as PairRow[]) ?? [];
  const matrixRows: MatrixRow[] = (matrixRes.data as MatrixRow[]) ?? [];
  const trendRows: TrendRow[] = (trendRes.data as TrendRow[]) ?? [];
  const capaRows: CapaRow[] = (capaRes.data as CapaRow[]) ?? [];
  const causeRows: CauseRow[] = (causeRes.data as CauseRow[]) ?? [];
  const digestRows: DigestRow[] = (digestRes.data as DigestRow[]) ?? [];
  const riskRows: RiskRow[] = (riskRes.data as RiskRow[]) ?? [];

  const verdictCols: Column<VerdictRow>[] = [
    { key: 'hedge_verdict', header: 'Hedge Verdict' },
    { key: 'exposures', header: 'Exposures' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'net_mtm_rupees', header: 'Net MTM (INR)' },
    { key: 'pct', header: 'Share %' },
  ];

  const pairCols: Column<PairRow>[] = [
    { key: 'currency_pair', header: 'Currency Pair' },
    { key: 'exposures', header: 'Exposures' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'adequately_hedged', header: 'Adequately Hedged' },
    { key: 'under_hedged', header: 'Under-Hedged' },
    { key: 'unhedged_exposed', header: 'Unhedged Exposed' },
    { key: 'avg_hedge_ratio_pct', header: 'Avg Hedge Ratio %' },
    { key: 'net_mtm_rupees', header: 'Net MTM (INR)' },
  ];

  const matrixCols: Column<MatrixRow>[] = [
    { key: 'exposure_type', header: 'Exposure Type' },
    { key: 'hedge_instrument', header: 'Hedge Instrument' },
    { key: 'exposures', header: 'Exposures' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'avg_hedge_ratio_pct', header: 'Avg Hedge Ratio %' },
    { key: 'net_mtm_rupees', header: 'Net MTM (INR)' },
  ];

  const trendCols: Column<TrendRow>[] = [
    { key: 'value_month', header: 'Value Month' },
    { key: 'exposures', header: 'Exposures' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'net_mtm_rupees', header: 'Net MTM (INR)' },
    { key: 'mtm_loss_rupees', header: 'MTM Loss (INR)' },
    { key: 'unhedged_count', header: 'Unhedged Count' },
  ];

  const capaCols: Column<CapaRow>[] = [
    { key: 'capa_status', header: 'CAPA Status' },
    { key: 'findings', header: 'Findings' },
    { key: 'total_impact_rupees', header: 'Total Impact (INR)' },
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
    { key: 'exposure_type', header: 'Exposure Type' },
    { key: 'exposures', header: 'Exposures' },
    { key: 'total_exposure_rupees', header: 'Total Exposure (INR)' },
    { key: 'mtm_gain_rupees', header: 'MTM Gain (INR)' },
    { key: 'mtm_loss_rupees', header: 'MTM Loss (INR)' },
    { key: 'net_mtm_rupees', header: 'Net MTM (INR)' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'exposure_name', header: 'Exposure' },
    { key: 'exposure_code', header: 'Code' },
    { key: 'currency_pair', header: 'Pair' },
    { key: 'exposure_type', header: 'Type' },
    { key: 'exposure_amount_rupees', header: 'Amount (INR)' },
    { key: 'hedge_instrument', header: 'Instrument' },
    { key: 'hedge_ratio_pct', header: 'Hedge %' },
    { key: 'mtm_gain_loss_rupees', header: 'MTM (INR)' },
    { key: 'value_date', header: 'Value Date' },
    { key: 'counterparty_bank', header: 'Bank' },
    { key: 'hedge_verdict', header: 'Verdict' },
    { key: 'notes', header: 'Notes' },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: '1.75rem', marginBottom: '0.5rem' }}>
        FX Currency-Exposure / Forex-Hedging Treasury Board
      </h1>
      <p style={{ color: '#555', marginBottom: '2rem' }}>
        Founder treasury view of foreign-currency exposures &amp; hedging posture — currency pair
        (USD, EUR, GBP, JPY, SGD, CHF vs INR) &times; exposure type (import payables, export
        receivables, foreign loans, capex commitments, royalties) &times; hedge instrument (forward,
        option, swap, natural hedge, unhedged) &times; hedge ratio &times; spot vs booked rate
        &times; mark-to-market gain/loss &times; value date &times; counterparty bank &amp; CAPA
        remediation. Founder-gated: hedge verdicts, currency-pair scorecards, exposure-type
        &times; instrument matrix, monthly MTM trend, root-cause pareto, and a high-risk queue of
        unhedged, under-hedged, over-hedged &amp; large-MTM-loss positions.
      </p>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>1. Hedge verdict distribution</h2>
        <DataTable
          rows={verdictRows}
          columns={verdictCols}
          emptyMessage="No exposures logged yet."
          rowKey={(r, i) => String(r.hedge_verdict ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>2. Currency-pair scorecard</h2>
        <DataTable
          rows={pairRows}
          columns={pairCols}
          emptyMessage="No currency-pair rollups."
          rowKey={(r, i) => String(r.currency_pair ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>
          3. Exposure type &times; hedge instrument matrix
        </h2>
        <DataTable
          rows={matrixRows}
          columns={matrixCols}
          emptyMessage="No exposures by type."
          rowKey={(r, i) => `${r.exposure_type}-${r.hedge_instrument}-${i}`}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>4. Monthly value-date &amp; MTM trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r, i) => String(r.value_month ?? i)}
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
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>6. Root-cause pareto</h2>
        <DataTable
          rows={causeRows}
          columns={causeCols}
          emptyMessage="No root-cause data."
          rowKey={(r, i) => String(r.root_cause ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>7. MTM impact digest</h2>
        <DataTable
          rows={digestRows}
          columns={digestCols}
          emptyMessage="No MTM impact data."
          rowKey={(r, i) => String(r.exposure_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.2rem', marginBottom: '0.5rem' }}>8. High-risk exposure queue</h2>
        <DataTable
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No high-risk exposures."
          rowKey={(r, i) => `${r.exposure_code}-${i}`}
        />
      </section>
    </main>
  );
}
