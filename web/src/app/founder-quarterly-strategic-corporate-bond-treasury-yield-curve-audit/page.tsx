import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type CurveSummary = { audit_quarter: string; points: number; avg_gsec_bps: number; avg_corp_bps: number; avg_spread_bps: number; overweight_count: number };
type SegmentSpread = { curve_segment: string; points: number; min_spread: number; max_spread: number; avg_spread: number; avg_liquidity: number };
type TenorRec = { tenor_label: string; tenor_months: number; latest_gsec_bps: number; latest_corp_bps: number; latest_spread: number; recommendation: string };
type SectorRow = { sector: string; positions: number; total_face_lakhs: number; total_mtm_lakhs: number; total_pnl_lakhs: number; avg_ytm_bps: number };
type RatingRow = { rating: string; positions: number; total_face_lakhs: number; total_pnl_lakhs: number; avg_duration: number };
type ActionRow = { action: string; positions: number; total_mtm_lakhs: number; total_pnl_lakhs: number };
type MoverRow = { issuer_name: string; rating: string; sector: string; face_lakhs: number; mtm_lakhs: number; pnl_lakhs: number; action: string };
type LadderRow = { maturity_bucket: string; positions: number; total_face_lakhs: number; avg_ytm_bps: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [curve, segment, tenor, sector, rating, action, movers, ladder] = await Promise.all([
    sb.rpc('rpc_r2961_curve_summary_by_quarter'),
    sb.rpc('rpc_r2961_spread_by_segment'),
    sb.rpc('rpc_r2961_tenor_recommendations'),
    sb.rpc('rpc_r2961_holdings_by_sector'),
    sb.rpc('rpc_r2961_holdings_by_rating'),
    sb.rpc('rpc_r2961_action_breakdown'),
    sb.rpc('rpc_r2961_top_pnl_movers'),
    sb.rpc('rpc_r2961_maturity_ladder'),
  ]);

  const curveRows: CurveSummary[] = (curve.data ?? []) as CurveSummary[];
  const segmentRows: SegmentSpread[] = (segment.data ?? []) as SegmentSpread[];
  const tenorRows: TenorRec[] = (tenor.data ?? []) as TenorRec[];
  const sectorRows: SectorRow[] = (sector.data ?? []) as SectorRow[];
  const ratingRows: RatingRow[] = (rating.data ?? []) as RatingRow[];
  const actionRows: ActionRow[] = (action.data ?? []) as ActionRow[];
  const moverRows: MoverRow[] = (movers.data ?? []) as MoverRow[];
  const ladderRows: LadderRow[] = (ladder.data ?? []) as LadderRow[];

  const curveCols: Column<CurveSummary>[] = [
    { header: 'Quarter', accessor: (r) => r.audit_quarter },
    { header: 'Points', accessor: (r) => r.points },
    { header: 'Avg G-Sec (bps)', accessor: (r) => r.avg_gsec_bps },
    { header: 'Avg Corp (bps)', accessor: (r) => r.avg_corp_bps },
    { header: 'Avg Spread (bps)', accessor: (r) => r.avg_spread_bps },
    { header: 'Overweight', accessor: (r) => r.overweight_count },
  ];

  const segmentCols: Column<SegmentSpread>[] = [
    { header: 'Segment', accessor: (r) => r.curve_segment },
    { header: 'Points', accessor: (r) => r.points },
    { header: 'Min Spread', accessor: (r) => r.min_spread },
    { header: 'Max Spread', accessor: (r) => r.max_spread },
    { header: 'Avg Spread', accessor: (r) => r.avg_spread },
    { header: 'Avg Liquidity', accessor: (r) => r.avg_liquidity },
  ];

  const tenorCols: Column<TenorRec>[] = [
    { header: 'Tenor', accessor: (r) => r.tenor_label },
    { header: 'Months', accessor: (r) => r.tenor_months },
    { header: 'G-Sec bps', accessor: (r) => r.latest_gsec_bps },
    { header: 'Corp bps', accessor: (r) => r.latest_corp_bps },
    { header: 'Spread bps', accessor: (r) => r.latest_spread },
    { header: 'Recommendation', accessor: (r) => r.recommendation },
  ];

  const sectorCols: Column<SectorRow>[] = [
    { header: 'Sector', accessor: (r) => r.sector },
    { header: 'Positions', accessor: (r) => r.positions },
    { header: 'Face (lakhs)', accessor: (r) => r.total_face_lakhs },
    { header: 'MTM (lakhs)', accessor: (r) => r.total_mtm_lakhs },
    { header: 'PnL (lakhs)', accessor: (r) => r.total_pnl_lakhs },
    { header: 'Avg YTM bps', accessor: (r) => r.avg_ytm_bps },
  ];

  const ratingCols: Column<RatingRow>[] = [
    { header: 'Rating', accessor: (r) => r.rating },
    { header: 'Positions', accessor: (r) => r.positions },
    { header: 'Face (lakhs)', accessor: (r) => r.total_face_lakhs },
    { header: 'PnL (lakhs)', accessor: (r) => r.total_pnl_lakhs },
    { header: 'Avg Duration', accessor: (r) => r.avg_duration },
  ];

  const actionCols: Column<ActionRow>[] = [
    { header: 'Action', accessor: (r) => r.action },
    { header: 'Positions', accessor: (r) => r.positions },
    { header: 'MTM (lakhs)', accessor: (r) => r.total_mtm_lakhs },
    { header: 'PnL (lakhs)', accessor: (r) => r.total_pnl_lakhs },
  ];

  const moverCols: Column<MoverRow>[] = [
    { header: 'Issuer', accessor: (r) => r.issuer_name },
    { header: 'Rating', accessor: (r) => r.rating },
    { header: 'Sector', accessor: (r) => r.sector },
    { header: 'Face (L)', accessor: (r) => r.face_lakhs },
    { header: 'MTM (L)', accessor: (r) => r.mtm_lakhs },
    { header: 'PnL (L)', accessor: (r) => r.pnl_lakhs },
    { header: 'Action', accessor: (r) => r.action },
  ];

  const ladderCols: Column<LadderRow>[] = [
    { header: 'Bucket', accessor: (r) => r.maturity_bucket },
    { header: 'Positions', accessor: (r) => r.positions },
    { header: 'Face (lakhs)', accessor: (r) => r.total_face_lakhs },
    { header: 'Avg YTM bps', accessor: (r) => r.avg_ytm_bps },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-8 p-6">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Quarterly Strategic Corporate-Bond Treasury Yield Curve Audit</h1>
        <p className="mt-1 text-sm text-gray-600">Round r2961 · G-Sec vs AAA corp spreads, sector & rating breakdown, top PnL movers & maturity ladder.</p>
      </header>

      <section>
        <h2 className="mb-3 text-lg font-medium">Curve summary by quarter</h2>
        <DataTable
          rows={curveRows}
          columns={curveCols}
          emptyMessage="No quarterly curve data"
          rowKey={(r, i) => String((r as { audit_quarter?: string }).audit_quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Spread by curve segment</h2>
        <DataTable
          rows={segmentRows}
          columns={segmentCols}
          emptyMessage="No segment data"
          rowKey={(r, i) => String((r as { curve_segment?: string }).curve_segment ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Latest tenor recommendations</h2>
        <DataTable
          rows={tenorRows}
          columns={tenorCols}
          emptyMessage="No tenor data"
          rowKey={(r, i) => String((r as { tenor_label?: string }).tenor_label ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Holdings by sector</h2>
        <DataTable
          rows={sectorRows}
          columns={sectorCols}
          emptyMessage="No sector exposure"
          rowKey={(r, i) => String((r as { sector?: string }).sector ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Holdings by rating</h2>
        <DataTable
          rows={ratingRows}
          columns={ratingCols}
          emptyMessage="No rating exposure"
          rowKey={(r, i) => String((r as { rating?: string }).rating ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Action breakdown</h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          emptyMessage="No action data"
          rowKey={(r, i) => String((r as { action?: string }).action ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Top PnL movers</h2>
        <DataTable
          rows={moverRows}
          columns={moverCols}
          emptyMessage="No movers"
          rowKey={(r, i) => String((r as { issuer_name?: string }).issuer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Maturity ladder</h2>
        <DataTable
          rows={ladderRows}
          columns={ladderCols}
          emptyMessage="No ladder buckets"
          rowKey={(r, i) => String((r as { maturity_bucket?: string }).maturity_bucket ?? i)}
        />
      </section>
    </main>
  );
}
