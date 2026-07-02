import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ConcentrationRow = { holder_name: string; asset_class: string; concentration_pct: number; position_value_rupees: number; risk_flag: string };
type RiskFlagRow = { risk_flag: string; position_count: number; total_value_rupees: number };
type LiquidityRow = { liquidity_tier: string; position_count: number; total_value_rupees: number; critical_count: number };
type SeverityRow = { severity: string; open_count: number; in_progress_count: number; mitigated_count: number; total_count: number };
type TopRiskRow = { holder_name: string; asset_class: string; concentration_pct: number; position_value_rupees: number };
type OpenFindingRow = { finding_category: string; severity: string; recommendation: string; status: string; target_resolution_at: string | null };
type HeadlineRow = { quarter: string; total_positions: number; total_value_rupees: number; critical_positions: number; open_p0_p1: number };
type MitigationRow = { finding_category: string; total: number; mitigated: number; mitigation_pct: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();
  const [conc, risk, liq, sev, top, open_, head, mit] = await Promise.all([
    supabase.rpc('r3093_concentration_overview'),
    supabase.rpc('r3093_risk_flag_summary'),
    supabase.rpc('r3093_liquidity_tier_breakdown'),
    supabase.rpc('r3093_findings_by_severity'),
    supabase.rpc('r3093_top_concentration_risks'),
    supabase.rpc('r3093_open_findings'),
    supabase.rpc('r3093_quarterly_headline'),
    supabase.rpc('r3093_category_mitigation_rate'),
  ]);

  const concRows = (conc.data ?? []) as ConcentrationRow[];
  const riskRows = (risk.data ?? []) as RiskFlagRow[];
  const liqRows = (liq.data ?? []) as LiquidityRow[];
  const sevRows = (sev.data ?? []) as SeverityRow[];
  const topRows = (top.data ?? []) as TopRiskRow[];
  const openRows = (open_.data ?? []) as OpenFindingRow[];
  const headRows = (head.data ?? []) as HeadlineRow[];
  const mitRows = (mit.data ?? []) as MitigationRow[];

  const concCols: Column<ConcentrationRow>[] = [
    { header: 'Holder', accessor: (r) => r.holder_name },
    { header: 'Asset class', accessor: (r) => r.asset_class },
    { header: 'Concentration %', accessor: (r) => r.concentration_pct },
    { header: 'Value (rupees)', accessor: (r) => r.position_value_rupees },
    { header: 'Risk flag', accessor: (r) => r.risk_flag },
  ];

  const riskCols: Column<RiskFlagRow>[] = [
    { header: 'Risk flag', accessor: (r) => r.risk_flag },
    { header: 'Positions', accessor: (r) => r.position_count },
    { header: 'Total value', accessor: (r) => r.total_value_rupees },
  ];

  const liqCols: Column<LiquidityRow>[] = [
    { header: 'Liquidity tier', accessor: (r) => r.liquidity_tier },
    { header: 'Positions', accessor: (r) => r.position_count },
    { header: 'Total value', accessor: (r) => r.total_value_rupees },
    { header: 'Critical', accessor: (r) => r.critical_count },
  ];

  const sevCols: Column<SeverityRow>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'In progress', accessor: (r) => r.in_progress_count },
    { header: 'Mitigated', accessor: (r) => r.mitigated_count },
    { header: 'Total', accessor: (r) => r.total_count },
  ];

  const topCols: Column<TopRiskRow>[] = [
    { header: 'Holder', accessor: (r) => r.holder_name },
    { header: 'Asset class', accessor: (r) => r.asset_class },
    { header: 'Concentration %', accessor: (r) => r.concentration_pct },
    { header: 'Value', accessor: (r) => r.position_value_rupees },
  ];

  const openCols: Column<OpenFindingRow>[] = [
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Recommendation', accessor: (r) => r.recommendation },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Target', accessor: (r) => r.target_resolution_at ?? '—' },
  ];

  const headCols: Column<HeadlineRow>[] = [
    { header: 'Quarter', accessor: (r) => r.quarter },
    { header: 'Positions', accessor: (r) => r.total_positions },
    { header: 'Total value', accessor: (r) => r.total_value_rupees },
    { header: 'Critical positions', accessor: (r) => r.critical_positions },
    { header: 'Open P0/P1', accessor: (r) => r.open_p0_p1 },
  ];

  const mitCols: Column<MitigationRow>[] = [
    { header: 'Category', accessor: (r) => r.finding_category },
    { header: 'Total', accessor: (r) => r.total },
    { header: 'Mitigated', accessor: (r) => r.mitigated },
    { header: 'Mitigation %', accessor: (r) => r.mitigation_pct },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Quarterly Strategic Engineer-Founder Family Office Wealth-Concentration Risk Audit</h1>
        <p className="text-sm text-gray-600">Founder &amp; engineer co-founder personal balance sheet review — concentration &gt;= 50% flagged.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Quarterly headline</h2>
        <DataTable rows={headRows} columns={headCols} emptyMessage="No headline data" rowKey={(r, i) => String((r as HeadlineRow & { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Concentration overview</h2>
        <DataTable rows={concRows} columns={concCols} emptyMessage="No positions" rowKey={(r, i) => String((r as ConcentrationRow & { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Risk flag summary</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No risk data" rowKey={(r, i) => String((r as RiskFlagRow & { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Liquidity tier breakdown</h2>
        <DataTable rows={liqRows} columns={liqCols} emptyMessage="No liquidity data" rowKey={(r, i) => String((r as LiquidityRow & { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top concentration risks (&gt;= 50%)</h2>
        <DataTable rows={topRows} columns={topCols} emptyMessage="No high concentration positions" rowKey={(r, i) => String((r as TopRiskRow & { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Findings by severity</h2>
        <DataTable rows={sevRows} columns={sevCols} emptyMessage="No findings" rowKey={(r, i) => String((r as SeverityRow & { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Open findings</h2>
        <DataTable rows={openRows} columns={openCols} emptyMessage="No open findings" rowKey={(r, i) => String((r as OpenFindingRow & { id?: string }).id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Category mitigation rate</h2>
        <DataTable rows={mitRows} columns={mitCols} emptyMessage="No mitigation data" rowKey={(r, i) => String((r as MitigationRow & { id?: string }).id ?? i)} />
      </section>
    </div>
  );
}
