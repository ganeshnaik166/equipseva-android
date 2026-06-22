import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Journey = {
  id: string;
  customer_label: string;
  customer_tier: string;
  region: string;
  city: string | null;
  contract_signed_on: string;
  kickoff_on: string | null;
  first_engineer_assigned_on: string | null;
  first_service_attempted_on: string | null;
  first_service_success_on: string | null;
  status: string;
  target_latency_days: number;
  actual_latency_days: number | null;
  effective_days_so_far: number;
  health_band: string;
  notes: string | null;
  created_at: string;
};

type Blocker = {
  id: string;
  journey_id: string;
  customer_label: string;
  blocker_category: string;
  blocker_severity: string;
  detected_on: string;
  resolved_on: string | null;
  days_stalled: number;
  owner_role: string;
  root_cause: string | null;
  remediation_action: string | null;
  prevented_future_count: number;
  created_at: string;
};

type Summary = {
  total_journeys: number;
  succeeded: number;
  in_progress: number;
  stalled: number;
  at_risk: number;
  aborted: number;
  on_target_count: number;
  breached_count: number;
  avg_actual_latency_days: number;
  median_actual_latency_days: number;
  p90_actual_latency_days: number;
  avg_target_latency_days: number;
  total_blockers: number;
  open_blockers: number;
  critical_blockers: number;
  avg_days_stalled: number;
  top_blocker_category: string;
  worst_tier: string;
  worst_region: string;
};

function days(n: number | null | undefined) {
  if (n === null || n === undefined) return '—';
  const v = Number(n);
  return `${v.toFixed(1)} d`;
}

function bandTone(band: string) {
  switch (band) {
    case 'on_target': return 'text-emerald-700 bg-emerald-50';
    case 'slight_delay': return 'text-amber-700 bg-amber-50';
    case 'at_risk': return 'text-orange-700 bg-orange-50';
    case 'breached': return 'text-rose-700 bg-rose-50';
    case 'severely_breached': return 'text-rose-900 bg-rose-100';
    default: return 'text-gray-700 bg-gray-50';
  }
}

function sevTone(sev: string) {
  switch (sev) {
    case 'critical': return 'text-rose-900 bg-rose-100';
    case 'high': return 'text-rose-700 bg-rose-50';
    case 'medium': return 'text-amber-700 bg-amber-50';
    case 'low': return 'text-emerald-700 bg-emerald-50';
    default: return 'text-gray-700 bg-gray-50';
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [journeyRes, blockerRes, summaryRes] = await Promise.all([
    sb.rpc('list_onboarding_journeys_r2304'),
    sb.rpc('list_onboarding_blockers_r2304', { p_journey_id: null }),
    sb.rpc('onboarding_latency_summary_r2304'),
  ]);

  const journeys: Journey[] = (journeyRes.data as Journey[] | null) ?? [];
  const blockers: Blocker[] = (blockerRes.data as Blocker[] | null) ?? [];
  const summary: Summary = ((summaryRes.data as Summary[] | null) ?? [])[0] ?? {
    total_journeys: 0,
    succeeded: 0,
    in_progress: 0,
    stalled: 0,
    at_risk: 0,
    aborted: 0,
    on_target_count: 0,
    breached_count: 0,
    avg_actual_latency_days: 0,
    median_actual_latency_days: 0,
    p90_actual_latency_days: 0,
    avg_target_latency_days: 0,
    total_blockers: 0,
    open_blockers: 0,
    critical_blockers: 0,
    avg_days_stalled: 0,
    top_blocker_category: '—',
    worst_tier: '—',
    worst_region: '—',
  };

  // Tier breakdown
  type TierAgg = { tier: string; count: number; succeeded: number; avgActual: number; avgTarget: number; breached: number };
  const tierMap = new Map<string, { count: number; succeeded: number; sumActual: number; nActual: number; sumTarget: number; breached: number }>();
  for (const j of journeys) {
    const cur = tierMap.get(j.customer_tier) ?? { count: 0, succeeded: 0, sumActual: 0, nActual: 0, sumTarget: 0, breached: 0 };
    cur.count += 1;
    cur.sumTarget += j.target_latency_days;
    if (j.status === 'succeeded') cur.succeeded += 1;
    if (j.actual_latency_days !== null) { cur.sumActual += j.actual_latency_days; cur.nActual += 1; }
    if (j.health_band === 'breached' || j.health_band === 'severely_breached') cur.breached += 1;
    tierMap.set(j.customer_tier, cur);
  }
  const tierRows: TierAgg[] = Array.from(tierMap.entries()).map(([tier, v]) => ({
    tier,
    count: v.count,
    succeeded: v.succeeded,
    avgActual: v.nActual > 0 ? v.sumActual / v.nActual : 0,
    avgTarget: v.count > 0 ? v.sumTarget / v.count : 0,
    breached: v.breached,
  })).sort((a, b) => b.avgActual - a.avgActual);

  // Region breakdown
  type RegionAgg = { region: string; count: number; succeeded: number; avgActual: number; breached: number };
  const regMap = new Map<string, { count: number; succeeded: number; sumActual: number; nActual: number; breached: number }>();
  for (const j of journeys) {
    const cur = regMap.get(j.region) ?? { count: 0, succeeded: 0, sumActual: 0, nActual: 0, breached: 0 };
    cur.count += 1;
    if (j.status === 'succeeded') cur.succeeded += 1;
    if (j.actual_latency_days !== null) { cur.sumActual += j.actual_latency_days; cur.nActual += 1; }
    if (j.health_band === 'breached' || j.health_band === 'severely_breached') cur.breached += 1;
    regMap.set(j.region, cur);
  }
  const regionRows: RegionAgg[] = Array.from(regMap.entries()).map(([region, v]) => ({
    region,
    count: v.count,
    succeeded: v.succeeded,
    avgActual: v.nActual > 0 ? v.sumActual / v.nActual : 0,
    breached: v.breached,
  })).sort((a, b) => b.avgActual - a.avgActual);

  // Blocker category roll-up
  type CatAgg = { category: string; count: number; openCount: number; criticalCount: number; avgStalled: number; prevented: number };
  const catMap = new Map<string, { count: number; open: number; crit: number; sumStalled: number; prevented: number }>();
  for (const b of blockers) {
    const cur = catMap.get(b.blocker_category) ?? { count: 0, open: 0, crit: 0, sumStalled: 0, prevented: 0 };
    cur.count += 1;
    if (!b.resolved_on) cur.open += 1;
    if (b.blocker_severity === 'critical') cur.crit += 1;
    cur.sumStalled += b.days_stalled ?? 0;
    cur.prevented += b.prevented_future_count ?? 0;
    catMap.set(b.blocker_category, cur);
  }
  const catRows: CatAgg[] = Array.from(catMap.entries()).map(([category, v]) => ({
    category,
    count: v.count,
    openCount: v.open,
    criticalCount: v.crit,
    avgStalled: v.count > 0 ? v.sumStalled / v.count : 0,
    prevented: v.prevented,
  })).sort((a, b) => b.count - a.count);

  const journeyCols: Column<Journey>[] = [
    { key: 'customer', header: 'Customer', render: (r) => (
      <div>
        <div className="font-medium">{r.customer_label}</div>
        <div className="text-xs text-[var(--color-muted)]">{r.customer_tier} · {r.region}{r.city ? ` · ${r.city}` : ''}</div>
      </div>
    ) },
    { key: 'signed', header: 'Signed', render: (r) => <span className="text-xs">{r.contract_signed_on}</span> },
    { key: 'milestones', header: 'Milestones', render: (r) => (
      <div className="text-xs text-[var(--color-muted)]">
        <div>kickoff: {r.kickoff_on ?? '—'}</div>
        <div>eng: {r.first_engineer_assigned_on ?? '—'}</div>
        <div>1st try: {r.first_service_attempted_on ?? '—'}</div>
        <div>success: {r.first_service_success_on ?? '—'}</div>
      </div>
    ) },
    { key: 'target', header: 'Target', render: (r) => <span className="text-xs">{r.target_latency_days} d</span> },
    { key: 'actual', header: 'Actual', render: (r) => {
      const v = r.actual_latency_days;
      if (v === null) {
        return <span className="text-xs text-[var(--color-muted)]">{r.effective_days_so_far} d so far</span>;
      }
      const tone = v <= r.target_latency_days ? 'text-emerald-700'
                 : v <= r.target_latency_days * 1.5 ? 'text-amber-700'
                 : 'text-rose-700';
      return <span className={`font-medium ${tone}`}>{v} d</span>;
    } },
    { key: 'band', header: 'Health', render: (r) => (
      <span className={`rounded px-2 py-0.5 text-xs ${bandTone(r.health_band)}`}>{r.health_band}</span>
    ) },
    { key: 'status', header: 'Status', render: (r) => (
      <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.status}</span>
    ) },
  ];

  const tierCols: Column<TierAgg>[] = [
    { key: 'tier', header: 'Tier', render: (r) => <span className="font-medium">{r.tier}</span> },
    { key: 'count', header: 'Journeys', render: (r) => <span>{r.count}</span> },
    { key: 'succeeded', header: 'Succeeded', render: (r) => <span>{r.succeeded}</span> },
    { key: 'avgTarget', header: 'Avg target', render: (r) => <span className="text-xs">{r.avgTarget.toFixed(1)} d</span> },
    { key: 'avgActual', header: 'Avg actual', render: (r) => {
      const tone = r.avgActual <= r.avgTarget ? 'text-emerald-700'
                 : r.avgActual <= r.avgTarget * 1.5 ? 'text-amber-700'
                 : 'text-rose-700';
      return <span className={`font-medium ${tone}`}>{r.avgActual.toFixed(1)} d</span>;
    } },
    { key: 'breached', header: 'Breached', render: (r) => {
      const tone = r.breached === 0 ? 'text-emerald-700' : r.breached >= 3 ? 'text-rose-700' : 'text-amber-700';
      return <span className={`font-medium ${tone}`}>{r.breached}</span>;
    } },
  ];

  const regionCols: Column<RegionAgg>[] = [
    { key: 'region', header: 'Region', render: (r) => <span className="font-medium">{r.region}</span> },
    { key: 'count', header: 'Journeys', render: (r) => <span>{r.count}</span> },
    { key: 'succeeded', header: 'Succeeded', render: (r) => <span>{r.succeeded}</span> },
    { key: 'avgActual', header: 'Avg actual', render: (r) => <span>{r.avgActual.toFixed(1)} d</span> },
    { key: 'breached', header: 'Breached', render: (r) => {
      const tone = r.breached === 0 ? 'text-emerald-700' : r.breached >= 3 ? 'text-rose-700' : 'text-amber-700';
      return <span className={`font-medium ${tone}`}>{r.breached}</span>;
    } },
  ];

  const catCols: Column<CatAgg>[] = [
    { key: 'category', header: 'Blocker category', render: (r) => <span className="font-medium">{r.category}</span> },
    { key: 'count', header: 'Total', render: (r) => <span>{r.count}</span> },
    { key: 'open', header: 'Open', render: (r) => {
      const tone = r.openCount === 0 ? 'text-emerald-700' : r.openCount >= 3 ? 'text-rose-700' : 'text-amber-700';
      return <span className={`font-medium ${tone}`}>{r.openCount}</span>;
    } },
    { key: 'crit', header: 'Critical', render: (r) => {
      const tone = r.criticalCount === 0 ? 'text-emerald-700' : 'text-rose-700';
      return <span className={`font-medium ${tone}`}>{r.criticalCount}</span>;
    } },
    { key: 'avgStalled', header: 'Avg stalled', render: (r) => <span className="text-xs">{r.avgStalled.toFixed(1)} d</span> },
    { key: 'prevented', header: 'Prevented future', render: (r) => <span>{r.prevented}</span> },
  ];

  const blockerCols: Column<Blocker>[] = [
    { key: 'customer', header: 'Customer', render: (r) => <span className="text-xs font-medium">{r.customer_label}</span> },
    { key: 'cat', header: 'Category', render: (r) => (
      <span className="rounded bg-gray-100 px-2 py-0.5 text-xs">{r.blocker_category}</span>
    ) },
    { key: 'sev', header: 'Severity', render: (r) => (
      <span className={`rounded px-2 py-0.5 text-xs ${sevTone(r.blocker_severity)}`}>{r.blocker_severity}</span>
    ) },
    { key: 'detected', header: 'Detected', render: (r) => <span className="text-xs">{r.detected_on}</span> },
    { key: 'resolved', header: 'Resolved', render: (r) => (
      <span className="text-xs">{r.resolved_on ?? <span className="text-rose-700">open</span>}</span>
    ) },
    { key: 'stalled', header: 'Days stalled', render: (r) => {
      const v = r.days_stalled ?? 0;
      const tone = v <= 3 ? 'text-emerald-700' : v <= 7 ? 'text-amber-700' : 'text-rose-700';
      return <span className={`font-medium ${tone}`}>{v} d</span>;
    } },
    { key: 'owner', header: 'Owner', render: (r) => <span className="text-xs">{r.owner_role}</span> },
    { key: 'cause', header: 'Root cause / fix', render: (r) => (
      <div className="max-w-md text-xs">
        <div>{r.root_cause ?? '—'}</div>
        {r.remediation_action ? (
          <div className="text-[var(--color-muted)]">fix: {r.remediation_action}</div>
        ) : null}
      </div>
    ) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Customer onboarding → first-success latency</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Days from contract signed to first successful service, broken down by tier and region.
          Log blockers and remediation against each journey to attack the long tail of stalled onboardings.
          Health bands: &lt;= target on-target, &lt;= 125% slight delay, &lt;= 150% at risk, &lt;= 200% breached, otherwise severely breached.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Total journeys</div>
          <div className="mt-1 text-2xl font-semibold">{summary.total_journeys}</div>
          <div className="text-xs text-[var(--color-muted)]">
            {summary.succeeded} succeeded · {summary.in_progress} in progress · {summary.stalled} stalled
          </div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Avg actual latency</div>
          <div className="mt-1 text-2xl font-semibold">{days(summary.avg_actual_latency_days)}</div>
          <div className="text-xs text-[var(--color-muted)]">
            target {days(summary.avg_target_latency_days)} · p50 {days(summary.median_actual_latency_days)} · p90 {days(summary.p90_actual_latency_days)}
          </div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Health bands</div>
          <div className="mt-1 text-2xl font-semibold">{summary.on_target_count}</div>
          <div className="text-xs text-[var(--color-muted)]">
            on-target · <span className="text-rose-700">{summary.breached_count} breached</span> · {summary.at_risk} at risk
          </div>
        </div>
        <div className="rounded border border-[var(--color-border)] bg-white p-4">
          <div className="text-xs uppercase text-[var(--color-muted)]">Blockers</div>
          <div className="mt-1 text-2xl font-semibold">{summary.total_blockers}</div>
          <div className="text-xs text-[var(--color-muted)]">
            {summary.open_blockers} open · <span className="text-rose-700">{summary.critical_blockers} critical</span> · avg stalled {days(summary.avg_days_stalled)}
          </div>
          <div className="mt-1 text-xs text-[var(--color-muted)]">
            top cat: {summary.top_blocker_category} · worst tier: {summary.worst_tier} · worst region: {summary.worst_region}
          </div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">By tier</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Mean actual vs target latency per customer tier. Sort desc by actual to spot slow tiers.
        </p>
        <DataTable<TierAgg>
          columns={tierCols}
          rows={tierRows}
          rowKey={(r: TierAgg, i: number) => String(r.tier ?? i)}
          emptyMessage="No tier rows yet."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">By region</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Average actual latency per region. Useful to plan field-engineer hiring.
        </p>
        <DataTable<RegionAgg>
          columns={regionCols}
          rows={regionRows}
          rowKey={(r: RegionAgg, i: number) => String(r.region ?? i)}
          emptyMessage="No region rows yet."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Blocker categories</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Where time leaks during onboarding. Open &gt;= 3 is red; any critical is red.
          "Prevented future" counts how many future onboardings the remediation is expected to skip.
        </p>
        <DataTable<CatAgg>
          columns={catCols}
          rows={catRows}
          rowKey={(r: CatAgg, i: number) => String(r.category ?? i)}
          emptyMessage="No blocker categories yet."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Journeys ({journeys.length})</h2>
        <p className="text-xs text-[var(--color-muted)]">
          One row per onboarding journey. Actual column shows realized days if first-success
          landed; otherwise "N d so far" against today.
        </p>
        <DataTable<Journey>
          columns={journeyCols}
          rows={journeys}
          rowKey={(r: Journey, i: number) => String(r.id ?? i)}
          emptyMessage="No onboarding journeys yet."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Blocker log ({blockers.length})</h2>
        <p className="text-xs text-[var(--color-muted)]">
          Individual blocker events across all journeys. Days stalled &gt; 7 is red. Resolve via
          <code className="ml-1 rounded bg-gray-100 px-1 text-xs">resolve_onboarding_blocker_r2304</code>.
        </p>
        <DataTable<Blocker>
          columns={blockerCols}
          rows={blockers}
          rowKey={(r: Blocker, i: number) => String(r.id ?? i)}
          emptyMessage="No blockers logged yet."
        />
      </section>
    </div>
  );
}
