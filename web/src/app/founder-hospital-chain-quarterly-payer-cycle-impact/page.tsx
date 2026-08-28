import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type KpiRow = {
  total_cycles: number;
  distressed_cycles: number;
  total_claims_rupees: number;
  total_amc_impact_rupees: number;
  total_bridge_extended_rupees: number;
  avg_delay_days: number;
  distinct_chains: number;
};

type LedgerRow = {
  chain_name: string;
  payer_name: string;
  payer_kind: string;
  fiscal_quarter: string;
  claims_submitted_rupees: number;
  claims_settled_rupees: number;
  settlement_pct: number;
  delay_days: number;
  amc_invoice_impact_rupees: number;
  our_amc_role: string;
  cycle_outcome: string;
};

type HeatmapRow = {
  fiscal_quarter: string;
  payer_kind: string;
  cycles_count: number;
  avg_delay_days: number;
  max_delay_days: number;
  total_claims_rupees: number;
  total_amc_impact_rupees: number;
};

type CushionRow = {
  chain_name: string;
  fiscal_quarter: string;
  amc_invoices_due_rupees: number;
  amc_invoices_collected_rupees: number;
  collection_pct: number;
  bridge_credit_extended_rupees: number;
  dso_days: number;
  payer_concentration_top1_pct: number;
  cushion_strategy: string;
  renewal_risk_score: number;
  recovered_in_quarter: boolean;
};

type DistressedRow = {
  chain_name: string;
  payer_name: string;
  fiscal_quarter: string;
  delay_days: number;
  settlement_pct: number;
  amc_invoice_impact_rupees: number;
  our_amc_role: string;
  notes: string | null;
};

type RoleRow = {
  our_amc_role: string;
  cycle_count: number;
  total_amc_impact_rupees: number;
  avg_delay_days: number;
  distinct_chains: number;
};

type RenewalRow = {
  chain_name: string;
  total_quarters: number;
  avg_dso_days: number;
  avg_renewal_risk: number;
  total_bridge_extended_rupees: number;
  recovered_quarters: number;
  risk_band: string;
};

type StrategyRow = {
  cushion_strategy: string;
  quarter_count: number;
  total_due_rupees: number;
  total_collected_rupees: number;
  collection_pct: number;
  avg_renewal_risk: number;
};

function inr(n: number | null | undefined): string {
  if (n === null || n === undefined) return '0';
  return new Intl.NumberFormat('en-IN').format(n);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, ledgerRes, heatmapRes, cushionRes, distressedRes, roleRes, renewalRes, strategyRes] = await Promise.all([
    supabase.rpc('founder_r2731_headline_kpis'),
    supabase.rpc('founder_r2731_chain_payer_cycle_ledger'),
    supabase.rpc('founder_r2731_quarterly_delay_heatmap'),
    supabase.rpc('founder_r2731_chain_cushion_ledger'),
    supabase.rpc('founder_r2731_distressed_cycles'),
    supabase.rpc('founder_r2731_amc_role_distribution'),
    supabase.rpc('founder_r2731_renewal_risk_board'),
    supabase.rpc('founder_r2731_cushion_strategy_mix'),
  ]);

  const kpi: KpiRow | null = (kpisRes.data as KpiRow[] | null)?.[0] ?? null;
  const ledger: LedgerRow[] = (ledgerRes.data as LedgerRow[] | null) ?? [];
  const heatmap: HeatmapRow[] = (heatmapRes.data as HeatmapRow[] | null) ?? [];
  const cushion: CushionRow[] = (cushionRes.data as CushionRow[] | null) ?? [];
  const distressed: DistressedRow[] = (distressedRes.data as DistressedRow[] | null) ?? [];
  const roles: RoleRow[] = (roleRes.data as RoleRow[] | null) ?? [];
  const renewal: RenewalRow[] = (renewalRes.data as RenewalRow[] | null) ?? [];
  const strategy: StrategyRow[] = (strategyRes.data as StrategyRow[] | null) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Payer Cycle Impact</h1>
        <p className="text-sm text-gray-600">
          How quarterly insurance and govt payer claim cycles ripple into hospital chain cash flow,
          AMC invoice timing, and our role cushioning the shock. Chain × payer × cycle × delay
          × AMC role × outcome.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total Cycles Tracked</div>
          <div className="text-2xl font-semibold">{kpi?.total_cycles ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Distressed Cycles</div>
          <div className="text-2xl font-semibold text-red-600">{kpi?.distressed_cycles ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Distinct Chains</div>
          <div className="text-2xl font-semibold">{kpi?.distinct_chains ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Avg Delay (days)</div>
          <div className="text-2xl font-semibold">{kpi?.avg_delay_days ?? 0}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Claims Volume (Rs)</div>
          <div className="text-2xl font-semibold">{inr(kpi?.total_claims_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">AMC Impact (Rs)</div>
          <div className="text-2xl font-semibold text-amber-600">{inr(kpi?.total_amc_impact_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Bridge Credit Extended (Rs)</div>
          <div className="text-2xl font-semibold">{inr(kpi?.total_bridge_extended_rupees ?? 0)}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Round</div>
          <div className="text-2xl font-semibold">r2731</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Chain × Payer Cycle Ledger</h2>
        <p className="text-xs text-gray-500">
          Settlement pct &lt; 60 percent or delay &gt;= 30 days typically triggers AMC role escalation.
        </p>
        <DataTable
          rows={ledger}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: LedgerRow) => r.chain_name },
            { key: 'payer_name', header: 'Payer', render: (r: LedgerRow) => r.payer_name },
            { key: 'payer_kind', header: 'Kind', render: (r: LedgerRow) => r.payer_kind },
            { key: 'fiscal_quarter', header: 'Quarter', render: (r: LedgerRow) => r.fiscal_quarter },
            { key: 'claims_submitted_rupees', header: 'Submitted (Rs)', render: (r: LedgerRow) => inr(r.claims_submitted_rupees) },
            { key: 'claims_settled_rupees', header: 'Settled (Rs)', render: (r: LedgerRow) => inr(r.claims_settled_rupees) },
            { key: 'settlement_pct', header: 'Settle %', render: (r: LedgerRow) => `${r.settlement_pct ?? 0}%` },
            { key: 'delay_days', header: 'Delay (d)', render: (r: LedgerRow) => String(r.delay_days) },
            { key: 'amc_invoice_impact_rupees', header: 'AMC Impact', render: (r: LedgerRow) => inr(r.amc_invoice_impact_rupees) },
            { key: 'our_amc_role', header: 'Our Role', render: (r: LedgerRow) => r.our_amc_role },
            { key: 'cycle_outcome', header: 'Outcome', render: (r: LedgerRow) => r.cycle_outcome },
          ]}
          emptyMessage="No data"
          rowKey={(_r, i) => String(i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Quarterly Delay Heatmap (by Payer Kind)</h2>
        <DataTable
          rows={heatmap}
          columns={[
            { key: 'fiscal_quarter', header: 'Quarter', render: (r: HeatmapRow) => r.fiscal_quarter },
            { key: 'payer_kind', header: 'Payer Kind', render: (r: HeatmapRow) => r.payer_kind },
            { key: 'cycles_count', header: 'Cycles', render: (r: HeatmapRow) => String(r.cycles_count) },
            { key: 'avg_delay_days', header: 'Avg Delay (d)', render: (r: HeatmapRow) => String(r.avg_delay_days ?? 0) },
            { key: 'max_delay_days', header: 'Max Delay (d)', render: (r: HeatmapRow) => String(r.max_delay_days) },
            { key: 'total_claims_rupees', header: 'Total Claims (Rs)', render: (r: HeatmapRow) => inr(r.total_claims_rupees) },
            { key: 'total_amc_impact_rupees', header: 'AMC Impact (Rs)', render: (r: HeatmapRow) => inr(r.total_amc_impact_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(_r, i) => String(i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Chain Cushion &amp; AMC Collection Ledger</h2>
        <p className="text-xs text-gray-500">
          Renewal risk score &gt;= 70 = red. Payer concentration &gt;= 60 percent = single-payer fragility.
        </p>
        <DataTable
          rows={cushion}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: CushionRow) => r.chain_name },
            { key: 'fiscal_quarter', header: 'Quarter', render: (r: CushionRow) => r.fiscal_quarter },
            { key: 'amc_invoices_due_rupees', header: 'Due (Rs)', render: (r: CushionRow) => inr(r.amc_invoices_due_rupees) },
            { key: 'amc_invoices_collected_rupees', header: 'Collected (Rs)', render: (r: CushionRow) => inr(r.amc_invoices_collected_rupees) },
            { key: 'collection_pct', header: 'Collect %', render: (r: CushionRow) => `${r.collection_pct ?? 0}%` },
            { key: 'bridge_credit_extended_rupees', header: 'Bridge (Rs)', render: (r: CushionRow) => inr(r.bridge_credit_extended_rupees) },
            { key: 'dso_days', header: 'DSO (d)', render: (r: CushionRow) => String(r.dso_days) },
            { key: 'payer_concentration_top1_pct', header: 'Top Payer %', render: (r: CushionRow) => `${r.payer_concentration_top1_pct}%` },
            { key: 'cushion_strategy', header: 'Cushion Strategy', render: (r: CushionRow) => r.cushion_strategy },
            { key: 'renewal_risk_score', header: 'Renewal Risk', render: (r: CushionRow) => String(r.renewal_risk_score) },
            { key: 'recovered_in_quarter', header: 'Recovered', render: (r: CushionRow) => r.recovered_in_quarter ? 'yes' : 'no' },
          ]}
          emptyMessage="No data"
          rowKey={(_r, i) => String(i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Distressed Cycles (Strained or Distressed Outcome)</h2>
        <DataTable
          rows={distressed}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: DistressedRow) => r.chain_name },
            { key: 'payer_name', header: 'Payer', render: (r: DistressedRow) => r.payer_name },
            { key: 'fiscal_quarter', header: 'Quarter', render: (r: DistressedRow) => r.fiscal_quarter },
            { key: 'delay_days', header: 'Delay (d)', render: (r: DistressedRow) => String(r.delay_days) },
            { key: 'settlement_pct', header: 'Settle %', render: (r: DistressedRow) => `${r.settlement_pct ?? 0}%` },
            { key: 'amc_invoice_impact_rupees', header: 'AMC Impact (Rs)', render: (r: DistressedRow) => inr(r.amc_invoice_impact_rupees) },
            { key: 'our_amc_role', header: 'Our Role', render: (r: DistressedRow) => r.our_amc_role },
            { key: 'notes', header: 'Notes', render: (r: DistressedRow) => r.notes },
          ]}
          emptyMessage="No data"
          rowKey={(_r, i) => String(i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Our AMC Role Distribution</h2>
        <DataTable
          rows={roles}
          columns={[
            { key: 'our_amc_role', header: 'Role', render: (r: RoleRow) => r.our_amc_role },
            { key: 'cycle_count', header: 'Cycles', render: (r: RoleRow) => String(r.cycle_count) },
            { key: 'distinct_chains', header: 'Chains', render: (r: RoleRow) => String(r.distinct_chains) },
            { key: 'avg_delay_days', header: 'Avg Delay (d)', render: (r: RoleRow) => String(r.avg_delay_days ?? 0) },
            { key: 'total_amc_impact_rupees', header: 'Total AMC Impact (Rs)', render: (r: RoleRow) => inr(r.total_amc_impact_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(_r, i) => String(i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Chain Renewal Risk Board</h2>
        <DataTable
          rows={renewal}
          columns={[
            { key: 'chain_name', header: 'Chain', render: (r: RenewalRow) => r.chain_name },
            { key: 'total_quarters', header: 'Quarters', render: (r: RenewalRow) => String(r.total_quarters) },
            { key: 'avg_dso_days', header: 'Avg DSO (d)', render: (r: RenewalRow) => String(r.avg_dso_days ?? 0) },
            { key: 'avg_renewal_risk', header: 'Avg Risk', render: (r: RenewalRow) => String(r.avg_renewal_risk ?? 0) },
            { key: 'total_bridge_extended_rupees', header: 'Bridge (Rs)', render: (r: RenewalRow) => inr(r.total_bridge_extended_rupees) },
            { key: 'recovered_quarters', header: 'Recovered Qs', render: (r: RenewalRow) => String(r.recovered_quarters) },
            { key: 'risk_band', header: 'Band', render: (r: RenewalRow) => r.risk_band },
          ]}
          emptyMessage="No data"
          rowKey={(_r, i) => String(i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Cushion Strategy Mix</h2>
        <DataTable
          rows={strategy}
          columns={[
            { key: 'cushion_strategy', header: 'Strategy', render: (r: StrategyRow) => r.cushion_strategy },
            { key: 'quarter_count', header: 'Quarters', render: (r: StrategyRow) => String(r.quarter_count) },
            { key: 'total_due_rupees', header: 'Due (Rs)', render: (r: StrategyRow) => inr(r.total_due_rupees) },
            { key: 'total_collected_rupees', header: 'Collected (Rs)', render: (r: StrategyRow) => inr(r.total_collected_rupees) },
            { key: 'collection_pct', header: 'Collect %', render: (r: StrategyRow) => `${r.collection_pct ?? 0}%` },
            { key: 'avg_renewal_risk', header: 'Avg Renewal Risk', render: (r: StrategyRow) => String(r.avg_renewal_risk ?? 0) },
          ]}
          emptyMessage="No data"
          rowKey={(_r, i) => String(i)}
        />
      </section>
    </div>
  );
}
