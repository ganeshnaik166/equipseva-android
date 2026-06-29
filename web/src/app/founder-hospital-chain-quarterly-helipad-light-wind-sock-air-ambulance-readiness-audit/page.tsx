import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type ChainRow = { chain: string; sites: number; avg_drill_score: number; a_or_b: number; failing: number };
type GroundedRow = { site_code: string; chain: string; city: string; grade: string; blockers: number; owner: string };
type WindsockRow = { condition: string; sites: number; with_backup: number; pct_backup: number };
type LightingRow = { perimeter: string; flood: string; sites: number; avg_blockers: number };
type BacklogRow = { severity: string; open_cnt: number; scheduled_cnt: number; in_rem_cnt: number; verified_cnt: number; total_cost_rupees: number };
type HotspotRow = { category: string; findings: number; p0_p1: number; est_cost_rupees: number };
type ScorecardRow = { site_code: string; chain: string; city: string; helipad_class: string; grade: string; drill: number; gen_min: number; lift_age_days: number; blockers: number };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [chains, grounded, windsock, lighting, backlog, hotspots, scorecard] = await Promise.all([
    sb.rpc('r3007_chain_readiness_overview'),
    sb.rpc('r3007_grounded_sites'),
    sb.rpc('r3007_windsock_compliance'),
    sb.rpc('r3007_lighting_failures'),
    sb.rpc('r3007_remediation_backlog'),
    sb.rpc('r3007_category_hotspots'),
    sb.rpc('r3007_quarterly_scorecard'),
  ]);

  const chainCols: Column<ChainRow>[] = [
    { header: 'Chain', accessor: (r) => r.chain },
    { header: 'Sites', accessor: (r) => r.sites },
    { header: 'Avg Drill', accessor: (r) => r.avg_drill_score },
    { header: 'A/B grade', accessor: (r) => r.a_or_b },
    { header: 'Failing (D/F)', accessor: (r) => r.failing },
  ];

  const groundedCols: Column<GroundedRow>[] = [
    { header: 'Site', accessor: (r) => r.site_code },
    { header: 'Chain', accessor: (r) => r.chain },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Grade', accessor: (r) => r.grade },
    { header: 'Blockers', accessor: (r) => r.blockers },
    { header: 'Owner', accessor: (r) => r.owner },
  ];

  const windsockCols: Column<WindsockRow>[] = [
    { header: 'Condition', accessor: (r) => r.condition },
    { header: 'Sites', accessor: (r) => r.sites },
    { header: 'With backup', accessor: (r) => r.with_backup },
    { header: '% backup', accessor: (r) => r.pct_backup },
  ];

  const lightingCols: Column<LightingRow>[] = [
    { header: 'Perimeter', accessor: (r) => r.perimeter },
    { header: 'Flood', accessor: (r) => r.flood },
    { header: 'Sites', accessor: (r) => r.sites },
    { header: 'Avg blockers', accessor: (r) => r.avg_blockers },
  ];

  const backlogCols: Column<BacklogRow>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Open', accessor: (r) => r.open_cnt },
    { header: 'Scheduled', accessor: (r) => r.scheduled_cnt },
    { header: 'In remediation', accessor: (r) => r.in_rem_cnt },
    { header: 'Verified', accessor: (r) => r.verified_cnt },
    { header: 'Est cost (INR)', accessor: (r) => r.total_cost_rupees },
  ];

  const hotspotCols: Column<HotspotRow>[] = [
    { header: 'Category', accessor: (r) => r.category },
    { header: 'Findings', accessor: (r) => r.findings },
    { header: 'P0/P1', accessor: (r) => r.p0_p1 },
    { header: 'Est cost (INR)', accessor: (r) => r.est_cost_rupees },
  ];

  const scoreCols: Column<ScorecardRow>[] = [
    { header: 'Site', accessor: (r) => r.site_code },
    { header: 'Chain', accessor: (r) => r.chain },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Class', accessor: (r) => r.helipad_class },
    { header: 'Grade', accessor: (r) => r.grade },
    { header: 'Drill', accessor: (r) => r.drill },
    { header: 'Gen min', accessor: (r) => r.gen_min },
    { header: 'Lift age (d)', accessor: (r) => r.lift_age_days },
    { header: 'Blockers', accessor: (r) => r.blockers },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Chain Quarterly Helipad-Light &amp; Wind-Sock Air-Ambulance Readiness Audit</h1>
        <p className="text-sm text-gray-600 mt-1">Round r3007 — quarterly readiness of rooftop helipads, perimeter &amp; flood lighting, primary/backup wind-socks, generator backup &gt;= 360 min, and drill scores across hospital chains.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chain readiness overview</h2>
        <DataTable<ChainRow>
          rows={(chains.data ?? []) as ChainRow[]}
          columns={chainCols}
          emptyMessage="No chain rows"
          rowKey={(r, i) => String((r as { chain?: string }).chain ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Grounded & failing sites (grade D/F)</h2>
        <DataTable<GroundedRow>
          rows={(grounded.data ?? []) as GroundedRow[]}
          columns={groundedCols}
          emptyMessage="No grounded sites"
          rowKey={(r, i) => String((r as { site_code?: string }).site_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Wind-sock compliance</h2>
        <DataTable<WindsockRow>
          rows={(windsock.data ?? []) as WindsockRow[]}
          columns={windsockCols}
          emptyMessage="No wind-sock data"
          rowKey={(r, i) => String((r as { condition?: string }).condition ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Lighting failure cross-tab</h2>
        <DataTable<LightingRow>
          rows={(lighting.data ?? []) as LightingRow[]}
          columns={lightingCols}
          emptyMessage="No lighting data"
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Remediation backlog by severity</h2>
        <DataTable<BacklogRow>
          rows={(backlog.data ?? []) as BacklogRow[]}
          columns={backlogCols}
          emptyMessage="No backlog"
          rowKey={(r, i) => String((r as { severity?: string }).severity ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Category hotspots</h2>
        <DataTable<HotspotRow>
          rows={(hotspots.data ?? []) as HotspotRow[]}
          columns={hotspotCols}
          emptyMessage="No hotspots"
          rowKey={(r, i) => String((r as { category?: string }).category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly site scorecard</h2>
        <DataTable<ScorecardRow>
          rows={(scorecard.data ?? []) as ScorecardRow[]}
          columns={scoreCols}
          emptyMessage="No scorecard rows"
          rowKey={(r, i) => String((r as { site_code?: string }).site_code ?? i)}
        />
      </section>
    </div>
  );
}
