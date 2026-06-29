import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type PortfolioRow = { id?: string; quarter: string; items: number; completed: number; slipping: number; blocked: number; total_planned_pts: number; total_actual_pts: number; pct_overrun: number };
type PillarRow = { id?: string; pillar: string; items: number; avg_strategic_weight: number; planned_pts: number; actual_pts: number; point_variance: number; red_count: number };
type SlippageRow = { id?: string; initiative_code: string; initiative_name: string; owner_squad: string; days_slipped: number; points_over: number; rag: string };
type SeverityRow = { id?: string; severity: string; open_count: number; total_count: number; avg_variance_days: number };
type KindRow = { id?: string; finding_kind: string; total: number; open_count: number; resolved_count: number; avg_points_var: number };
type SquadRow = { id?: string; owner_squad: string; items: number; completed: number; open_findings: number; planned_pts: number; actual_pts: number; overrun_pct: number };
type BlockedRow = { id?: string; initiative_code: string; initiative_name: string; pillar: string; owner_squad: string; strategic_weight: number; blocker_count: number; top_remediation: string };
type RiskRow = { id?: string; pillar: string; weighted_risk: number; red_initiatives: number; p0_p1_findings: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [portfolio, pillar, slippage, severity, kind, squad, blocked, risk] = await Promise.all([
    supabase.rpc('founder_r2985_portfolio_summary'),
    supabase.rpc('founder_r2985_pillar_variance'),
    supabase.rpc('founder_r2985_top_slippages'),
    supabase.rpc('founder_r2985_open_findings_by_severity'),
    supabase.rpc('founder_r2985_finding_kind_breakdown'),
    supabase.rpc('founder_r2985_squad_scorecard'),
    supabase.rpc('founder_r2985_blocked_initiatives'),
    supabase.rpc('founder_r2985_strategic_risk_index'),
  ]);

  const portfolioRows: PortfolioRow[] = portfolio.data ?? [];
  const pillarRows: PillarRow[] = pillar.data ?? [];
  const slippageRows: SlippageRow[] = slippage.data ?? [];
  const severityRows: SeverityRow[] = severity.data ?? [];
  const kindRows: KindRow[] = kind.data ?? [];
  const squadRows: SquadRow[] = squad.data ?? [];
  const blockedRows: BlockedRow[] = blocked.data ?? [];
  const riskRows: RiskRow[] = risk.data ?? [];

  const portfolioCols: Column<PortfolioRow>[] = [
    { key: 'quarter', header: 'Quarter', render: (r) => r.quarter },
    { key: 'items', header: 'Items', render: (r) => r.items },
    { key: 'completed', header: 'Completed', render: (r) => r.completed },
    { key: 'slipping', header: 'Slipping', render: (r) => r.slipping },
    { key: 'blocked', header: 'Blocked', render: (r) => r.blocked },
    { key: 'planned', header: 'Planned pts', render: (r) => r.total_planned_pts },
    { key: 'actual', header: 'Actual pts', render: (r) => r.total_actual_pts },
    { key: 'overrun', header: 'Overrun %', render: (r) => `${r.pct_overrun}%` },
  ];

  const pillarCols: Column<PillarRow>[] = [
    { key: 'pillar', header: 'Pillar', render: (r) => r.pillar },
    { key: 'items', header: 'Items', render: (r) => r.items },
    { key: 'weight', header: 'Avg weight', render: (r) => r.avg_strategic_weight },
    { key: 'planned', header: 'Planned', render: (r) => r.planned_pts },
    { key: 'actual', header: 'Actual', render: (r) => r.actual_pts },
    { key: 'var', header: 'Point variance', render: (r) => r.point_variance },
    { key: 'red', header: 'Red items', render: (r) => r.red_count },
  ];

  const slippageCols: Column<SlippageRow>[] = [
    { key: 'code', header: 'Code', render: (r) => r.initiative_code },
    { key: 'name', header: 'Initiative', render: (r) => r.initiative_name },
    { key: 'squad', header: 'Squad', render: (r) => r.owner_squad },
    { key: 'days', header: 'Days slipped', render: (r) => r.days_slipped },
    { key: 'pts', header: 'Points over', render: (r) => r.points_over },
    { key: 'rag', header: 'RAG', render: (r) => r.rag.toUpperCase() },
  ];

  const severityCols: Column<SeverityRow>[] = [
    { key: 'sev', header: 'Severity', render: (r) => r.severity.toUpperCase() },
    { key: 'open', header: 'Open', render: (r) => r.open_count },
    { key: 'total', header: 'Total', render: (r) => r.total_count },
    { key: 'avgvar', header: 'Avg variance (d)', render: (r) => r.avg_variance_days },
  ];

  const kindCols: Column<KindRow>[] = [
    { key: 'kind', header: 'Finding kind', render: (r) => r.finding_kind },
    { key: 'total', header: 'Total', render: (r) => r.total },
    { key: 'open', header: 'Open', render: (r) => r.open_count },
    { key: 'res', header: 'Resolved', render: (r) => r.resolved_count },
    { key: 'avg', header: 'Avg pts var', render: (r) => r.avg_points_var },
  ];

  const squadCols: Column<SquadRow>[] = [
    { key: 'squad', header: 'Squad', render: (r) => r.owner_squad },
    { key: 'items', header: 'Items', render: (r) => r.items },
    { key: 'comp', header: 'Completed', render: (r) => r.completed },
    { key: 'open', header: 'Open findings', render: (r) => r.open_findings },
    { key: 'planned', header: 'Planned', render: (r) => r.planned_pts },
    { key: 'actual', header: 'Actual', render: (r) => r.actual_pts },
    { key: 'over', header: 'Overrun %', render: (r) => `${r.overrun_pct}%` },
  ];

  const blockedCols: Column<BlockedRow>[] = [
    { key: 'code', header: 'Code', render: (r) => r.initiative_code },
    { key: 'name', header: 'Initiative', render: (r) => r.initiative_name },
    { key: 'pillar', header: 'Pillar', render: (r) => r.pillar },
    { key: 'squad', header: 'Squad', render: (r) => r.owner_squad },
    { key: 'weight', header: 'Weight', render: (r) => r.strategic_weight },
    { key: 'count', header: 'Blockers', render: (r) => r.blocker_count },
    { key: 'remed', header: 'Top remediation', render: (r) => r.top_remediation },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'pillar', header: 'Pillar', render: (r) => r.pillar },
    { key: 'risk', header: 'Weighted risk', render: (r) => r.weighted_risk },
    { key: 'red', header: 'Red items', render: (r) => r.red_initiatives },
    { key: 'p01', header: 'Open P0/P1', render: (r) => r.p0_p1_findings },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-semibold">Quarterly Strategic Mid-Year Engineering Roadmap Variance Audit</h1>
        <p className="text-sm text-gray-600 mt-1">Round 2985 — Founder review of H1 planned vs actual delivery, pillar & squad scorecards, and open variance findings.</p>
      </header>

      <section>
        <h2 className="text-lg font-medium mb-2">Portfolio summary by quarter</h2>
        <DataTable rows={portfolioRows} columns={portfolioCols} emptyMessage="No portfolio data" rowKey={(r, i) => String(r.id ?? r.quarter ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Pillar variance</h2>
        <DataTable rows={pillarRows} columns={pillarCols} emptyMessage="No pillar data" rowKey={(r, i) => String(r.id ?? r.pillar ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top slippages (&gt;= planned end)</h2>
        <DataTable rows={slippageRows} columns={slippageCols} emptyMessage="No slippages" rowKey={(r, i) => String(r.id ?? r.initiative_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Open findings by severity</h2>
        <DataTable rows={severityRows} columns={severityCols} emptyMessage="No findings" rowKey={(r, i) => String(r.id ?? r.severity ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Finding kind breakdown</h2>
        <DataTable rows={kindRows} columns={kindCols} emptyMessage="No finding kinds" rowKey={(r, i) => String(r.id ?? r.finding_kind ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Squad scorecard</h2>
        <DataTable rows={squadRows} columns={squadCols} emptyMessage="No squads" rowKey={(r, i) => String(r.id ?? r.owner_squad ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Blocked & at-risk initiatives</h2>
        <DataTable rows={blockedRows} columns={blockedCols} emptyMessage="No blocked initiatives" rowKey={(r, i) => String(r.id ?? r.initiative_code ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Strategic risk index</h2>
        <DataTable rows={riskRows} columns={riskCols} emptyMessage="No risk rows" rowKey={(r, i) => String(r.id ?? r.pillar ?? i)} />
      </section>
    </div>
  );
}
