import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChainSummary = {
  chain_name: string;
  total_units: number;
  total_cost_lakh: number;
  critical_units: number;
  approved_funding_lakh: number;
};

type QuarterUrgency = {
  forecast_quarter: string;
  critical_count: number;
  high_count: number;
  medium_count: number;
  low_count: number;
  watch_count: number;
  total_cost_lakh: number;
};

type CategoryBreakdown = {
  equipment_category: string;
  line_items: number;
  total_units: number;
  total_cost_lakh: number;
  avg_age: number;
};

type FundingMix = {
  funding_source: string;
  entries: number;
  total_lakh: number;
  approved_lakh: number;
  red_flag_count: number;
};

type CriticalGap = {
  chain_name: string;
  equipment_category: string;
  forecast_quarter: string;
  units_due: number;
  replacement_cost_lakh: number;
  funding_status: string;
  notes: string | null;
};

type RedFlag = {
  chain_name: string;
  fiscal_quarter: string;
  funding_source: string;
  amount_lakh: number;
  approval_state: string;
  expected_disbursal_date: string;
  decision_owner: string;
  remarks: string | null;
};

type CreditOpp = {
  chain_name: string;
  current_amc_credit_lakh: number;
  forecast_total_lakh: number;
  gap_lakh: number;
  recommended_action: string;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [summary, urgency, category, mix, gaps, red, credit] = await Promise.all([
    supabase.rpc('r2935_chainwide_quarter_summary'),
    supabase.rpc('r2935_quarter_urgency_distribution'),
    supabase.rpc('r2935_category_cost_breakdown'),
    supabase.rpc('r2935_funding_source_mix'),
    supabase.rpc('r2935_critical_unfunded_gaps'),
    supabase.rpc('r2935_red_flag_funding_lines'),
    supabase.rpc('r2935_equipseva_credit_opportunity'),
  ]);

  const summaryRows: ChainSummary[] = (summary.data as ChainSummary[]) ?? [];
  const urgencyRows: QuarterUrgency[] = (urgency.data as QuarterUrgency[]) ?? [];
  const categoryRows: CategoryBreakdown[] = (category.data as CategoryBreakdown[]) ?? [];
  const mixRows: FundingMix[] = (mix.data as FundingMix[]) ?? [];
  const gapRows: CriticalGap[] = (gaps.data as CriticalGap[]) ?? [];
  const redRows: RedFlag[] = (red.data as RedFlag[]) ?? [];
  const creditRows: CreditOpp[] = (credit.data as CreditOpp[]) ?? [];

  const summaryCols: Column<ChainSummary>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'total_units', header: 'Units due', render: (r) => r.total_units },
    { key: 'total_cost_lakh', header: 'Cost (Lakh)', render: (r) => `Rs ${r.total_cost_lakh}` },
    { key: 'critical_units', header: 'Critical lines', render: (r) => r.critical_units },
    { key: 'approved_funding_lakh', header: 'Approved fund (Lakh)', render: (r) => `Rs ${r.approved_funding_lakh}` },
  ];

  const urgencyCols: Column<QuarterUrgency>[] = [
    { key: 'forecast_quarter', header: 'Quarter', render: (r) => r.forecast_quarter },
    { key: 'critical_count', header: 'Critical', render: (r) => r.critical_count },
    { key: 'high_count', header: 'High', render: (r) => r.high_count },
    { key: 'medium_count', header: 'Medium', render: (r) => r.medium_count },
    { key: 'low_count', header: 'Low', render: (r) => r.low_count },
    { key: 'watch_count', header: 'Watch', render: (r) => r.watch_count },
    { key: 'total_cost_lakh', header: 'Total (Lakh)', render: (r) => `Rs ${r.total_cost_lakh}` },
  ];

  const categoryCols: Column<CategoryBreakdown>[] = [
    { key: 'equipment_category', header: 'Category', render: (r) => r.equipment_category },
    { key: 'line_items', header: 'Lines', render: (r) => r.line_items },
    { key: 'total_units', header: 'Units', render: (r) => r.total_units },
    { key: 'total_cost_lakh', header: 'Cost (Lakh)', render: (r) => `Rs ${r.total_cost_lakh}` },
    { key: 'avg_age', header: 'Avg age (yr)', render: (r) => r.avg_age },
  ];

  const mixCols: Column<FundingMix>[] = [
    { key: 'funding_source', header: 'Source', render: (r) => r.funding_source },
    { key: 'entries', header: 'Lines', render: (r) => r.entries },
    { key: 'total_lakh', header: 'Total (Lakh)', render: (r) => `Rs ${r.total_lakh}` },
    { key: 'approved_lakh', header: 'Approved (Lakh)', render: (r) => `Rs ${r.approved_lakh}` },
    { key: 'red_flag_count', header: 'Red flags', render: (r) => r.red_flag_count },
  ];

  const gapCols: Column<CriticalGap>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'equipment_category', header: 'Category', render: (r) => r.equipment_category },
    { key: 'forecast_quarter', header: 'Quarter', render: (r) => r.forecast_quarter },
    { key: 'units_due', header: 'Units', render: (r) => r.units_due },
    { key: 'replacement_cost_lakh', header: 'Cost (Lakh)', render: (r) => `Rs ${r.replacement_cost_lakh}` },
    { key: 'funding_status', header: 'Funding state', render: (r) => r.funding_status },
    { key: 'notes', header: 'Notes', render: (r) => r.notes ?? '' },
  ];

  const redCols: Column<RedFlag>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'fiscal_quarter', header: 'Quarter', render: (r) => r.fiscal_quarter },
    { key: 'funding_source', header: 'Source', render: (r) => r.funding_source },
    { key: 'amount_lakh', header: 'Amount (Lakh)', render: (r) => `Rs ${r.amount_lakh}` },
    { key: 'approval_state', header: 'State', render: (r) => r.approval_state },
    { key: 'expected_disbursal_date', header: 'Disbursal', render: (r) => r.expected_disbursal_date },
    { key: 'decision_owner', header: 'Owner', render: (r) => r.decision_owner },
    { key: 'remarks', header: 'Remarks', render: (r) => r.remarks ?? '' },
  ];

  const creditCols: Column<CreditOpp>[] = [
    { key: 'chain_name', header: 'Chain', render: (r) => r.chain_name },
    { key: 'current_amc_credit_lakh', header: 'Current AMC credit (Lakh)', render: (r) => `Rs ${r.current_amc_credit_lakh}` },
    { key: 'forecast_total_lakh', header: 'Forecast total (Lakh)', render: (r) => `Rs ${r.forecast_total_lakh}` },
    { key: 'gap_lakh', header: 'Gap (Lakh)', render: (r) => `Rs ${r.gap_lakh}` },
    { key: 'recommended_action', header: 'Recommended action', render: (r) => r.recommended_action },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>
          Hospital Chain Quarterly Equipment-Lifecycle Replacement Forecast Plan
        </h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Round r2935 — founder console: roll up every hospital chain's end-of-life equipment by quarter, map funding sources, surface critical unfunded gaps, and quantify EquipSeva AMC credit opportunity.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Chain-wide forecast summary</h2>
        <DataTable
          rows={summaryRows}
          columns={summaryCols}
          emptyMessage="No chain summary available"
          rowKey={(r, i) => String((r as ChainSummary).chain_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Quarter urgency distribution</h2>
        <DataTable
          rows={urgencyRows}
          columns={urgencyCols}
          emptyMessage="No urgency rows"
          rowKey={(r, i) => String((r as QuarterUrgency).forecast_quarter ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Category cost breakdown</h2>
        <DataTable
          rows={categoryRows}
          columns={categoryCols}
          emptyMessage="No categories"
          rowKey={(r, i) => String((r as CategoryBreakdown).equipment_category ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Funding source mix</h2>
        <DataTable
          rows={mixRows}
          columns={mixCols}
          emptyMessage="No funding mix"
          rowKey={(r, i) => String((r as FundingMix).funding_source ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Critical unfunded gaps</h2>
        <DataTable
          rows={gapRows}
          columns={gapCols}
          emptyMessage="No critical unfunded gaps — all critical lines covered"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Red-flag funding lines</h2>
        <DataTable
          rows={redRows}
          columns={redCols}
          emptyMessage="No red-flag funding lines"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>EquipSeva AMC credit opportunity</h2>
        <DataTable
          rows={creditRows}
          columns={creditCols}
          emptyMessage="No credit opportunity rows"
          rowKey={(r, i) => String((r as CreditOpp).chain_name ?? i)}
        />
      </section>
    </div>
  );
}
