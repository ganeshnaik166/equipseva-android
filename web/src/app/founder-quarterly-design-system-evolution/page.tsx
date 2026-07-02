import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type TokenOverview = {
  total_tokens: number;
  retuned_count: number;
  introduced_count: number;
  deprecated_count: number;
  avg_adoption: number;
  avg_stability: number;
  override_total: number;
};

type ComponentOverview = {
  total_components: number;
  adoption_total: number;
  override_total: number;
  refactor_backlog_total: number;
  avg_stability: number;
  avg_a11y: number;
};

type TokenRow = {
  id: string;
  quarter: string;
  token_name: string;
  token_category: string;
  change_kind: string;
  prior_value: string | null;
  current_value: string;
  adoption_pct: number;
  override_count: number;
  refactor_required: boolean;
  stability_score: number;
  verdict: string;
};

type ComponentRow = {
  id: string;
  quarter: string;
  component_name: string;
  surface_area: string;
  adoption_count: number;
  override_count: number;
  refactor_backlog: number;
  stability_score: number;
  a11y_score: number;
  verdict: string;
  notes: string | null;
};

type HotspotRow = {
  source: string;
  name: string;
  category_or_surface: string;
  override_count: number;
  stability_score: number;
};

type RefactorRow = {
  source: string;
  name: string;
  bucket: string;
  workload: number;
  verdict: string;
};

type SurfaceRow = {
  surface_area: string;
  components: number;
  avg_stability: number;
  avg_a11y: number;
  overrides: number;
  backlog: number;
};

function fmtPct(value: number | null | undefined): string {
  if (value === null || value === undefined) return '—';
  return `${Number(value).toFixed(1)}%`;
}

function fmtNum(value: number | null | undefined): string {
  if (value === null || value === undefined) return '—';
  return Number(value).toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    tokOverviewRes,
    compOverviewRes,
    tokRowsRes,
    compRowsRes,
    hotspotsRes,
    refactorRes,
    surfaceRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2813_token_overview'),
    supabase.rpc('founder_r2813_component_overview'),
    supabase.rpc('founder_r2813_token_rows'),
    supabase.rpc('founder_r2813_component_rows'),
    supabase.rpc('founder_r2813_override_hotspots'),
    supabase.rpc('founder_r2813_refactor_queue'),
    supabase.rpc('founder_r2813_surface_stability'),
  ]);

  const tokOverview: TokenOverview | null =
    (tokOverviewRes.data as TokenOverview[] | null)?.[0] ?? null;
  const compOverview: ComponentOverview | null =
    (compOverviewRes.data as ComponentOverview[] | null)?.[0] ?? null;
  const tokRows: TokenRow[] = (tokRowsRes.data as TokenRow[] | null) ?? [];
  const compRows: ComponentRow[] = (compRowsRes.data as ComponentRow[] | null) ?? [];
  const hotspots: HotspotRow[] = (hotspotsRes.data as HotspotRow[] | null) ?? [];
  const refactor: RefactorRow[] = (refactorRes.data as RefactorRow[] | null) ?? [];
  const surfaces: SurfaceRow[] = (surfaceRes.data as SurfaceRow[] | null) ?? [];

  const kpis = [
    {
      label: 'Tokens tracked',
      value: fmtNum(tokOverview?.total_tokens),
      sub: `${fmtNum(tokOverview?.retuned_count)} retuned`,
    },
    {
      label: 'Avg token adoption',
      value: fmtPct(tokOverview?.avg_adoption),
      sub: `stability ${fmtPct(tokOverview?.avg_stability)}`,
    },
    {
      label: 'Components in DS',
      value: fmtNum(compOverview?.total_components),
      sub: `${fmtNum(compOverview?.adoption_total)} adoption pts`,
    },
    {
      label: 'Override total',
      value: fmtNum(
        (tokOverview?.override_total ?? 0) + (compOverview?.override_total ?? 0),
      ),
      sub: `${fmtNum(compOverview?.refactor_backlog_total)} backlog items`,
    },
    {
      label: 'Avg a11y score',
      value: fmtPct(compOverview?.avg_a11y),
      sub: `stability ${fmtPct(compOverview?.avg_stability)}`,
    },
  ];

  const tokenColumns = [
    { key: 'token_name', header: 'Token', render: (r: TokenRow) => r.token_name },
    {
      key: 'token_category',
      header: 'Category',
      render: (r: TokenRow) => r.token_category,
    },
    {
      key: 'change_kind',
      header: 'Change',
      render: (r: TokenRow) => r.change_kind,
    },
    {
      key: 'value',
      header: 'Prior to current',
      render: (r: TokenRow) => `${r.prior_value ?? '—'} to ${r.current_value}`,
    },
    {
      key: 'adoption_pct',
      header: 'Adoption',
      render: (r: TokenRow) => fmtPct(r.adoption_pct),
    },
    {
      key: 'override_count',
      header: 'Overrides',
      render: (r: TokenRow) => fmtNum(r.override_count),
    },
    {
      key: 'stability_score',
      header: 'Stability',
      render: (r: TokenRow) => fmtPct(r.stability_score),
    },
    {
      key: 'refactor_required',
      header: 'Refactor',
      render: (r: TokenRow) => (r.refactor_required ? 'yes' : 'no'),
    },
    { key: 'verdict', header: 'Verdict', render: (r: TokenRow) => r.verdict },
  ];

  const componentColumns = [
    {
      key: 'component_name',
      header: 'Component',
      render: (r: ComponentRow) => r.component_name,
    },
    {
      key: 'surface_area',
      header: 'Surface',
      render: (r: ComponentRow) => r.surface_area,
    },
    {
      key: 'adoption_count',
      header: 'Adoption',
      render: (r: ComponentRow) => fmtNum(r.adoption_count),
    },
    {
      key: 'override_count',
      header: 'Overrides',
      render: (r: ComponentRow) => fmtNum(r.override_count),
    },
    {
      key: 'refactor_backlog',
      header: 'Backlog',
      render: (r: ComponentRow) => fmtNum(r.refactor_backlog),
    },
    {
      key: 'stability_score',
      header: 'Stability',
      render: (r: ComponentRow) => fmtPct(r.stability_score),
    },
    {
      key: 'a11y_score',
      header: 'A11y',
      render: (r: ComponentRow) => fmtPct(r.a11y_score),
    },
    {
      key: 'verdict',
      header: 'Verdict',
      render: (r: ComponentRow) => r.verdict,
    },
    {
      key: 'notes',
      header: 'Notes',
      render: (r: ComponentRow) => r.notes ?? '—',
    },
  ];

  const hotspotColumns = [
    { key: 'source', header: 'Source', render: (r: HotspotRow) => r.source },
    { key: 'name', header: 'Name', render: (r: HotspotRow) => r.name },
    {
      key: 'category_or_surface',
      header: 'Category / surface',
      render: (r: HotspotRow) => r.category_or_surface,
    },
    {
      key: 'override_count',
      header: 'Overrides',
      render: (r: HotspotRow) => fmtNum(r.override_count),
    },
    {
      key: 'stability_score',
      header: 'Stability',
      render: (r: HotspotRow) => fmtPct(r.stability_score),
    },
  ];

  const refactorColumns = [
    { key: 'source', header: 'Source', render: (r: RefactorRow) => r.source },
    { key: 'name', header: 'Name', render: (r: RefactorRow) => r.name },
    { key: 'bucket', header: 'Bucket', render: (r: RefactorRow) => r.bucket },
    {
      key: 'workload',
      header: 'Workload',
      render: (r: RefactorRow) => fmtNum(r.workload),
    },
    { key: 'verdict', header: 'Verdict', render: (r: RefactorRow) => r.verdict },
  ];

  const surfaceColumns = [
    {
      key: 'surface_area',
      header: 'Surface',
      render: (r: SurfaceRow) => r.surface_area,
    },
    {
      key: 'components',
      header: 'Components',
      render: (r: SurfaceRow) => fmtNum(r.components),
    },
    {
      key: 'avg_stability',
      header: 'Avg stability',
      render: (r: SurfaceRow) => fmtPct(r.avg_stability),
    },
    {
      key: 'avg_a11y',
      header: 'Avg a11y',
      render: (r: SurfaceRow) => fmtPct(r.avg_a11y),
    },
    {
      key: 'overrides',
      header: 'Overrides',
      render: (r: SurfaceRow) => fmtNum(r.overrides),
    },
    {
      key: 'backlog',
      header: 'Backlog',
      render: (r: SurfaceRow) => fmtNum(r.backlog),
    },
  ];

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">
          Founder · Quarterly Design System Evolution
        </h1>
        <p className="text-sm text-gray-600">
          Token churn, component adoption, override hotspots, refactor backlog
          and surface stability across the founder, engineer, hospital and
          investor surfaces. Verdict mix shows what to keep, watch, retune,
          rollback or promote next quarter.
        </p>
      </header>

      <section
        aria-label="KPIs"
        className="grid grid-cols-2 md:grid-cols-5 gap-3"
      >
        {kpis.map((k) => (
          <div
            key={k.label}
            className="rounded-lg border border-gray-200 bg-white p-4"
          >
            <div className="text-xs uppercase tracking-wide text-gray-500">
              {k.label}
            </div>
            <div className="text-xl font-semibold mt-1">{k.value}</div>
            <div className="text-xs text-gray-500 mt-1">{k.sub}</div>
          </div>
        ))}
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Token churn (this quarter)</h2>
        <p className="text-xs text-gray-600">
          Tokens with stability &lt; 80% or overrides &gt;= 5 are flagged for
          retune review.
        </p>
        <DataTable
          rows={tokRows}
          columns={tokenColumns}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as TokenRow).id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Component scorecard</h2>
        <p className="text-xs text-gray-600">
          Adoption &amp; override mix per shared component. Backlog &gt; 0 means
          dedicated refactor ticket queued.
        </p>
        <DataTable
          rows={compRows}
          columns={componentColumns}
          emptyMessage="No data"
          rowKey={(r, i) => String((r as ComponentRow).id ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Override hotspots</h2>
        <p className="text-xs text-gray-600">
          Where override count &gt;= 1 across tokens &amp; components, sorted
          highest first.
        </p>
        <DataTable
          rows={hotspots}
          columns={hotspotColumns}
          emptyMessage="No data"
          rowKey={(r, i) =>
            `${(r as HotspotRow).source}-${(r as HotspotRow).name}-${i}`
          }
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Refactor queue (next quarter)</h2>
        <p className="text-xs text-gray-600">
          Tokens flagged refactor_required + components with backlog &gt; 0.
        </p>
        <DataTable
          rows={refactor}
          columns={refactorColumns}
          emptyMessage="No data"
          rowKey={(r, i) =>
            `${(r as RefactorRow).source}-${(r as RefactorRow).name}-${i}`
          }
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Surface stability roll-up</h2>
        <p className="text-xs text-gray-600">
          Stability & a11y per surface area. Lowest stability shows first
          so we know which surface eats the next sprint.
        </p>
        <DataTable
          rows={surfaces}
          columns={surfaceColumns}
          emptyMessage="No data"
          rowKey={(r, i) => `${(r as SurfaceRow).surface_area}-${i}`}
        />
      </section>
    </main>
  );
}
