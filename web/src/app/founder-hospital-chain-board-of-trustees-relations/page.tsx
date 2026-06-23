import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Hospital chain board of trustees relations — r2579" };
export const dynamic = "force-dynamic";

type TrusteeRow = {
  id: string;
  chain_name: string;
  hospital_user_id: string | null;
  trustee_name: string;
  trustee_email: string | null;
  trustee_role: string;
  relationship_strength: string;
  influence_score: number;
  deal_accelerator_kind: string;
  tension_flags_md: string | null;
  owner_email: string | null;
  status: string;
  notes: string | null;
  created_at: string;
};

type TouchRow = {
  id: string;
  trustee_id: string;
  trustee_name: string;
  chain_name: string;
  touch_at: string;
  touch_kind: string;
  outcome: string;
  follow_up_at: string | null;
  owner_email: string | null;
  status: string;
  notes: string | null;
};

type TopInfluenceRow = {
  trustee_name: string;
  chain_name: string;
  trustee_role: string;
  relationship_strength: string;
  influence_score: number;
  deal_accelerator_kind: string;
  status: string;
};

type RoleDistRow = {
  trustee_role: string;
  total_count: number;
  champion_count: number;
  strong_count: number;
  developing_count: number;
  weak_count: number;
  avg_influence: number;
};

type StrainedRow = {
  trustee_name: string;
  chain_name: string;
  trustee_role: string;
  relationship_strength: string;
  influence_score: number;
  deal_accelerator_kind: string;
  tension_flags_md: string | null;
  owner_email: string | null;
  status: string;
};

type TouchTrendRow = {
  month_label: string;
  total_touches: number;
  positive_count: number;
  neutral_count: number;
  negative_count: number;
  pending_count: number;
  unique_trustees: number;
};

type OwnerLoadRow = {
  owner_email: string;
  trustee_count: number;
  champion_count: number;
  strained_count: number;
  open_touches: number;
  avg_influence: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function strengthBadge(s: string): string {
  if (s === "champion") return "text-emerald-700";
  if (s === "strong") return "text-sky-700";
  if (s === "developing") return "text-amber-700";
  if (s === "weak") return "text-rose-700";
  return "";
}

function acceleratorBadge(a: string): string {
  if (a === "strong") return "text-emerald-700";
  if (a === "marginal") return "text-sky-700";
  if (a === "none") return "text-gray-600";
  if (a === "blocker") return "text-rose-700";
  return "";
}

function outcomeBadge(o: string): string {
  if (o === "positive") return "text-emerald-700";
  if (o === "neutral") return "text-sky-700";
  if (o === "pending") return "text-amber-700";
  if (o === "negative") return "text-rose-700";
  return "";
}

function statusBadge(s: string): string {
  if (s === "active" || s === "done") return "text-emerald-700";
  if (s === "open" || s === "dormant") return "text-amber-700";
  if (s === "strained" || s === "lost" || s === "dropped") return "text-rose-700";
  return "";
}

function preview(s: string | null, n: number): string {
  if (!s) return "—";
  const t = s.replace(/\s+/g, " ").trim();
  return t.length > n ? t.slice(0, n) + "…" : t;
}

export default async function HospitalChainBoardOfTrusteesRelationsPage() {
  const sb = await getSupabaseServerClient();
  const [
    trusteesRes,
    touchesRes,
    topInfluenceRes,
    roleDistRes,
    strainedRes,
    touchTrendRes,
    ownerLoadRes,
  ] = await Promise.all([
    sb.rpc("list_trustee_relations_r2579"),
    sb.rpc("list_touch_events_r2579"),
    sb.rpc("top_influence_trustees_r2579"),
    sb.rpc("role_distribution_r2579"),
    sb.rpc("strained_focus_r2579"),
    sb.rpc("monthly_touch_trend_r2579"),
    sb.rpc("owner_load_r2579"),
  ]);

  if (trusteesRes.error) throw new Error(`list_trustee_relations_r2579: ${trusteesRes.error.message}`);
  if (touchesRes.error) throw new Error(`list_touch_events_r2579: ${touchesRes.error.message}`);
  if (topInfluenceRes.error) throw new Error(`top_influence_trustees_r2579: ${topInfluenceRes.error.message}`);
  if (roleDistRes.error) throw new Error(`role_distribution_r2579: ${roleDistRes.error.message}`);
  if (strainedRes.error) throw new Error(`strained_focus_r2579: ${strainedRes.error.message}`);
  if (touchTrendRes.error) throw new Error(`monthly_touch_trend_r2579: ${touchTrendRes.error.message}`);
  if (ownerLoadRes.error) throw new Error(`owner_load_r2579: ${ownerLoadRes.error.message}`);

  const trustees = (trusteesRes.data ?? []) as TrusteeRow[];
  const touches = (touchesRes.data ?? []) as TouchRow[];
  const topInfluence = (topInfluenceRes.data ?? []) as TopInfluenceRow[];
  const roleDist = (roleDistRes.data ?? []) as RoleDistRow[];
  const strained = (strainedRes.data ?? []) as StrainedRow[];
  const touchTrend = (touchTrendRes.data ?? []) as TouchTrendRow[];
  const ownerLoad = (ownerLoadRes.data ?? []) as OwnerLoadRow[];

  const totalTrustees = trustees.length;
  const championCount = trustees.filter((t) => t.relationship_strength === "champion").length;
  const blockerCount = trustees.filter((t) => t.deal_accelerator_kind === "blocker").length;
  const strainedCount = trustees.filter((t) => t.status === "strained" || t.status === "lost").length;
  const totalTouches = touches.length;
  const openTouches = touches.filter((t) => t.status === "open").length;

  const trusteeColumns: Column<TrusteeRow>[] = [
    { key: "chain_name", header: "Chain", render: (r: any) => r.chain_name },
    { key: "trustee_name", header: "Trustee", render: (r: any) => r.trustee_name },
    { key: "trustee_role", header: "Role", render: (r: any) => r.trustee_role },
    {
      key: "relationship_strength",
      header: "Strength",
      render: (r: any) => <span className={strengthBadge(r.relationship_strength)}>{r.relationship_strength}</span>,
    },
    { key: "influence_score", header: "Influence", render: (r: any) => `${r.influence_score}/100` },
    {
      key: "deal_accelerator_kind",
      header: "Deal lever",
      render: (r: any) => <span className={acceleratorBadge(r.deal_accelerator_kind)}>{r.deal_accelerator_kind}</span>,
    },
    { key: "tension_flags_md", header: "Tension", render: (r: any) => preview(r.tension_flags_md, 60) },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    {
      key: "status",
      header: "Status",
      render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span>,
    },
  ];

  const touchColumns: Column<TouchRow>[] = [
    { key: "touch_at", header: "Touch", render: (r: any) => fmtDate(r.touch_at) },
    { key: "trustee_name", header: "Trustee", render: (r: any) => r.trustee_name },
    { key: "chain_name", header: "Chain", render: (r: any) => r.chain_name },
    { key: "touch_kind", header: "Kind", render: (r: any) => r.touch_kind },
    {
      key: "outcome",
      header: "Outcome",
      render: (r: any) => <span className={outcomeBadge(r.outcome)}>{r.outcome}</span>,
    },
    { key: "follow_up_at", header: "Follow-up", render: (r: any) => fmtDate(r.follow_up_at) },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    {
      key: "status",
      header: "Status",
      render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span>,
    },
    { key: "notes", header: "Notes", render: (r: any) => preview(r.notes, 60) },
  ];

  const topInfluenceColumns: Column<TopInfluenceRow>[] = [
    { key: "trustee_name", header: "Trustee", render: (r: any) => r.trustee_name },
    { key: "chain_name", header: "Chain", render: (r: any) => r.chain_name },
    { key: "trustee_role", header: "Role", render: (r: any) => r.trustee_role },
    {
      key: "relationship_strength",
      header: "Strength",
      render: (r: any) => <span className={strengthBadge(r.relationship_strength)}>{r.relationship_strength}</span>,
    },
    { key: "influence_score", header: "Influence", render: (r: any) => `${r.influence_score}/100` },
    {
      key: "deal_accelerator_kind",
      header: "Deal lever",
      render: (r: any) => <span className={acceleratorBadge(r.deal_accelerator_kind)}>{r.deal_accelerator_kind}</span>,
    },
    {
      key: "status",
      header: "Status",
      render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span>,
    },
  ];

  const roleDistColumns: Column<RoleDistRow>[] = [
    { key: "trustee_role", header: "Role", render: (r: any) => r.trustee_role },
    { key: "total_count", header: "Total", render: (r: any) => String(r.total_count) },
    { key: "champion_count", header: "Champion", render: (r: any) => String(r.champion_count) },
    { key: "strong_count", header: "Strong", render: (r: any) => String(r.strong_count) },
    { key: "developing_count", header: "Developing", render: (r: any) => String(r.developing_count) },
    { key: "weak_count", header: "Weak", render: (r: any) => String(r.weak_count) },
    { key: "avg_influence", header: "Avg influence", render: (r: any) => Number(r.avg_influence ?? 0).toFixed(1) },
  ];

  const strainedColumns: Column<StrainedRow>[] = [
    { key: "trustee_name", header: "Trustee", render: (r: any) => r.trustee_name },
    { key: "chain_name", header: "Chain", render: (r: any) => r.chain_name },
    { key: "trustee_role", header: "Role", render: (r: any) => r.trustee_role },
    {
      key: "relationship_strength",
      header: "Strength",
      render: (r: any) => <span className={strengthBadge(r.relationship_strength)}>{r.relationship_strength}</span>,
    },
    { key: "influence_score", header: "Influence", render: (r: any) => `${r.influence_score}/100` },
    {
      key: "deal_accelerator_kind",
      header: "Deal lever",
      render: (r: any) => <span className={acceleratorBadge(r.deal_accelerator_kind)}>{r.deal_accelerator_kind}</span>,
    },
    { key: "tension_flags_md", header: "Tension", render: (r: any) => preview(r.tension_flags_md, 80) },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    {
      key: "status",
      header: "Status",
      render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span>,
    },
  ];

  const touchTrendColumns: Column<TouchTrendRow>[] = [
    { key: "month_label", header: "Month", render: (r: any) => r.month_label },
    { key: "total_touches", header: "Total touches", render: (r: any) => String(r.total_touches) },
    { key: "positive_count", header: "Positive", render: (r: any) => String(r.positive_count) },
    { key: "neutral_count", header: "Neutral", render: (r: any) => String(r.neutral_count) },
    { key: "negative_count", header: "Negative", render: (r: any) => String(r.negative_count) },
    { key: "pending_count", header: "Pending", render: (r: any) => String(r.pending_count) },
    { key: "unique_trustees", header: "Unique trustees", render: (r: any) => String(r.unique_trustees) },
  ];

  const ownerLoadColumns: Column<OwnerLoadRow>[] = [
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email },
    { key: "trustee_count", header: "Trustees", render: (r: any) => String(r.trustee_count) },
    { key: "champion_count", header: "Champions", render: (r: any) => String(r.champion_count) },
    { key: "strained_count", header: "Strained/Blocker", render: (r: any) => String(r.strained_count) },
    { key: "open_touches", header: "Open touches", render: (r: any) => String(r.open_touches) },
    { key: "avg_influence", header: "Avg influence", render: (r: any) => Number(r.avg_influence ?? 0).toFixed(1) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Hospital chain board of trustees relations — r2579</h1>
        <p className="mt-1 text-xs text-gray-500">
          Map of chain boards: trustee role, relationship strength, influence score, deal-accelerator kind &
          tension flags. Touch events log every board meeting / dinner / call so champions get nurtured and
          blockers get founder time.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-6">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total trustees</div>
          <div className="mt-1 text-lg font-semibold">{totalTrustees}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Champions</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{championCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Blockers</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{blockerCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Strained/Lost</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{strainedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total touches</div>
          <div className="mt-1 text-lg font-semibold">{totalTouches}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Open touches</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{openTouches}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All trustee relations</h2>
        <p className="text-xs text-gray-500">
          One row per board trustee per chain. Strength + influence + accelerator kind = where to spend founder
          time.
        </p>
        <DataTable
          rows={trustees}
          columns={trusteeColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No trustee relations logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Touch events</h2>
        <p className="text-xs text-gray-500">
          Every board meeting / dinner / call / conference / intro logged with outcome & follow-up. Negative
          outcomes & open status need same-week founder attention.
        </p>
        <DataTable
          rows={touches}
          columns={touchColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No touch events logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top influence trustees</h2>
        <p className="text-xs text-gray-500">
          Highest 25 influence scores across all chains. These trustees decide whether bulk POs land or stall.
        </p>
        <DataTable
          rows={topInfluence}
          columns={topInfluenceColumns}
          rowKey={(r: any, i: number) => String(`${r.chain_name}-${r.trustee_name}-${i}`)}
          emptyMessage="No top-influence data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Role distribution</h2>
        <p className="text-xs text-gray-500">
          For each board role: how many trustees overall & the strength split. Chair / vice-chair concentration
          of champions is the strongest deal signal.
        </p>
        <DataTable
          rows={roleDist}
          columns={roleDistColumns}
          rowKey={(r: any, i: number) => String(r.trustee_role ?? i)}
          emptyMessage="No role distribution data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Strained focus list</h2>
        <p className="text-xs text-gray-500">
          Trustees flagged strained / lost / blocker / weak / with tension notes. Founder must engage directly
          before next board cycle.
        </p>
        <DataTable
          rows={strained}
          columns={strainedColumns}
          rowKey={(r: any, i: number) => String(`${r.chain_name}-${r.trustee_name}-${i}`)}
          emptyMessage="No strained relationships flagged."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Monthly touch trend</h2>
        <p className="text-xs text-gray-500">
          Touches per month with positive/neutral/negative/pending split & unique trustees touched. Drop in
          unique trustees = relationship coverage shrinking.
        </p>
        <DataTable
          rows={touchTrend}
          columns={touchTrendColumns}
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
          emptyMessage="No monthly touch trend data yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Owner load</h2>
        <p className="text-xs text-gray-500">
          Per owner (founder / co-founder / CSM): trustee count, champion count, strained/blocker count & open
          touches. Surface overload before relationships rot.
        </p>
        <DataTable
          rows={ownerLoad}
          columns={ownerLoadColumns}
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
          emptyMessage="No owner load data yet."
        />
      </section>
    </div>
  );
}
