import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder customer quarterly equipment utilization bench — r2580" };
export const dynamic = "force-dynamic";

type UtilRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  quarter_label: string;
  equipment_kind: string;
  our_utilization_pct: number;
  peer_benchmark_pct: number;
  top_quartile_pct: number;
  gap_to_top_pct: number;
  growth_lever_kind: string;
  owner_email: string | null;
  status: string;
  notes: string | null;
  created_at: string;
};

type ActionRow = {
  id: string;
  utilization_id: string;
  quarter_label: string | null;
  equipment_kind: string | null;
  hospital_email: string | null;
  action_at: string | null;
  owner_email: string | null;
  status: string;
  expected_uplift_rupees: number;
  outcome: string;
  notes: string | null;
  created_at: string;
};

type FocusRow = {
  id: string;
  hospital_email: string | null;
  quarter_label: string;
  equipment_kind: string;
  our_utilization_pct: number;
  top_quartile_pct: number;
  gap_to_top_pct: number;
  growth_lever_kind: string;
  status: string;
  owner_email: string | null;
};

type KindRow = {
  equipment_kind: string;
  row_count: number;
  avg_our_pct: number | null;
  avg_peer_pct: number | null;
  avg_top_pct: number | null;
  avg_gap_pct: number | null;
};

type LeverRow = {
  growth_lever_kind: string;
  row_count: number;
  won_count: number;
  lost_count: number;
  avg_gap_pct: number | null;
  pct: number;
};

type TrendRow = {
  quarter_label: string;
  row_count: number;
  avg_our_pct: number | null;
  avg_peer_pct: number | null;
  avg_top_pct: number | null;
  avg_gap_pct: number | null;
  won_count: number;
};

type OwnerRow = {
  owner_email: string;
  utilization_count: number;
  open_action_count: number;
  done_action_count: number;
  expected_uplift_rupees: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return `₹${n.toLocaleString("en-IN")}`;
}

function statusBadge(status: string): string {
  if (status === "won" || status === "done") return "text-emerald-700";
  if (status === "monitoring" || status === "in_discussion" || status === "open" || status === "in_progress") return "text-amber-700";
  if (status === "lost" || status === "dropped") return "text-red-700";
  return "text-gray-500";
}

function outcomeBadge(outcome: string): string {
  if (outcome === "positive") return "text-emerald-700";
  if (outcome === "neutral") return "text-amber-700";
  if (outcome === "negative") return "text-red-700";
  return "text-gray-500";
}

function gapBadge(gap: number | null): string {
  if (gap === null || gap === undefined) return "";
  if (gap >= 25) return "text-red-700 font-medium";
  if (gap >= 10) return "text-amber-700";
  return "text-emerald-700";
}

export default async function FounderCustomerQuarterlyEquipmentUtilizationBenchPage() {
  const sb = await getSupabaseServerClient();
  const [utilRes, actionsRes, focusRes, kindRes, leverRes, trendRes, ownerRes] = await Promise.all([
    sb.rpc("list_utilization_r2580"),
    sb.rpc("list_growth_lever_actions_r2580"),
    sb.rpc("top_gap_focus_r2580"),
    sb.rpc("equipment_kind_summary_r2580"),
    sb.rpc("growth_lever_distribution_r2580"),
    sb.rpc("quarterly_utilization_trend_r2580"),
    sb.rpc("owner_load_r2580"),
  ]);

  if (utilRes.error) throw new Error(`list_utilization_r2580: ${utilRes.error.message}`);
  if (actionsRes.error) throw new Error(`list_growth_lever_actions_r2580: ${actionsRes.error.message}`);
  if (focusRes.error) throw new Error(`top_gap_focus_r2580: ${focusRes.error.message}`);
  if (kindRes.error) throw new Error(`equipment_kind_summary_r2580: ${kindRes.error.message}`);
  if (leverRes.error) throw new Error(`growth_lever_distribution_r2580: ${leverRes.error.message}`);
  if (trendRes.error) throw new Error(`quarterly_utilization_trend_r2580: ${trendRes.error.message}`);
  if (ownerRes.error) throw new Error(`owner_load_r2580: ${ownerRes.error.message}`);

  const utils = (utilRes.data ?? []) as UtilRow[];
  const actions = (actionsRes.data ?? []) as ActionRow[];
  const focus = (focusRes.data ?? []) as FocusRow[];
  const kinds = (kindRes.data ?? []) as KindRow[];
  const levers = (leverRes.data ?? []) as LeverRow[];
  const trend = (trendRes.data ?? []) as TrendRow[];
  const owners = (ownerRes.data ?? []) as OwnerRow[];

  const totalUtil = utils.length;
  const monitoring = utils.filter((u) => u.status === "monitoring").length;
  const inDiscussion = utils.filter((u) => u.status === "in_discussion").length;
  const wonCount = utils.filter((u) => u.status === "won").length;
  const lostCount = utils.filter((u) => u.status === "lost").length;
  const avgGap = utils.length
    ? (utils.reduce((a, u) => a + Number(u.gap_to_top_pct ?? 0), 0) / utils.length).toFixed(1)
    : "—";
  const openActions = actions.filter((a) => a.status === "open" || a.status === "in_progress").length;
  const totalUplift = actions.reduce((a, x) => a + Number(x.expected_uplift_rupees ?? 0), 0);

  const utilColumns: Column<UtilRow>[] = [
    { key: "quarter_label", header: "Quarter", render: (r: any) => <span className="font-medium">{r.quarter_label}</span> },
    { key: "hospital_email", header: "Hospital", render: (r: any) => r.hospital_email ?? "—" },
    { key: "equipment_kind", header: "Equipment", render: (r: any) => r.equipment_kind },
    { key: "our_utilization_pct", header: "Ours %", render: (r: any) => `${r.our_utilization_pct}%` },
    { key: "peer_benchmark_pct", header: "Peer %", render: (r: any) => `${r.peer_benchmark_pct}%` },
    { key: "top_quartile_pct", header: "Top %", render: (r: any) => `${r.top_quartile_pct}%` },
    { key: "gap_to_top_pct", header: "Gap %", render: (r: any) => <span className={gapBadge(r.gap_to_top_pct)}>{r.gap_to_top_pct}%</span> },
    { key: "growth_lever_kind", header: "Lever", render: (r: any) => r.growth_lever_kind },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const actionColumns: Column<ActionRow>[] = [
    { key: "quarter_label", header: "Quarter", render: (r: any) => r.quarter_label ?? "—" },
    { key: "hospital_email", header: "Hospital", render: (r: any) => r.hospital_email ?? "—" },
    { key: "equipment_kind", header: "Equipment", render: (r: any) => r.equipment_kind ?? "—" },
    { key: "action_at", header: "Action at", render: (r: any) => fmtDate(r.action_at) },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "outcome", header: "Outcome", render: (r: any) => <span className={outcomeBadge(r.outcome)}>{r.outcome}</span> },
    { key: "expected_uplift_rupees", header: "Uplift", render: (r: any) => fmtRupees(r.expected_uplift_rupees) },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
    { key: "notes", header: "Notes", render: (r: any) => r.notes ?? "—" },
  ];

  const focusColumns: Column<FocusRow>[] = [
    { key: "hospital_email", header: "Hospital", render: (r: any) => <span className="font-medium">{r.hospital_email ?? "—"}</span> },
    { key: "quarter_label", header: "Quarter", render: (r: any) => r.quarter_label },
    { key: "equipment_kind", header: "Equipment", render: (r: any) => r.equipment_kind },
    { key: "our_utilization_pct", header: "Ours %", render: (r: any) => `${r.our_utilization_pct}%` },
    { key: "top_quartile_pct", header: "Top %", render: (r: any) => `${r.top_quartile_pct}%` },
    { key: "gap_to_top_pct", header: "Gap %", render: (r: any) => <span className={gapBadge(r.gap_to_top_pct)}>{r.gap_to_top_pct}%</span> },
    { key: "growth_lever_kind", header: "Lever", render: (r: any) => r.growth_lever_kind },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "owner_email", header: "Owner", render: (r: any) => r.owner_email ?? "—" },
  ];

  const kindColumns: Column<KindRow>[] = [
    { key: "equipment_kind", header: "Equipment", render: (r: any) => <span className="font-medium">{r.equipment_kind}</span> },
    { key: "row_count", header: "Rows", render: (r: any) => String(r.row_count) },
    { key: "avg_our_pct", header: "Avg ours %", render: (r: any) => (r.avg_our_pct ?? "—") },
    { key: "avg_peer_pct", header: "Avg peer %", render: (r: any) => (r.avg_peer_pct ?? "—") },
    { key: "avg_top_pct", header: "Avg top %", render: (r: any) => (r.avg_top_pct ?? "—") },
    { key: "avg_gap_pct", header: "Avg gap %", render: (r: any) => <span className={gapBadge(r.avg_gap_pct)}>{r.avg_gap_pct ?? "—"}</span> },
  ];

  const leverColumns: Column<LeverRow>[] = [
    { key: "growth_lever_kind", header: "Lever", render: (r: any) => <span className="font-medium">{r.growth_lever_kind}</span> },
    { key: "row_count", header: "Rows", render: (r: any) => String(r.row_count) },
    { key: "won_count", header: "Won", render: (r: any) => <span className="text-emerald-700">{r.won_count}</span> },
    { key: "lost_count", header: "Lost", render: (r: any) => <span className="text-red-700">{r.lost_count}</span> },
    { key: "avg_gap_pct", header: "Avg gap %", render: (r: any) => (r.avg_gap_pct ?? "—") },
    { key: "pct", header: "%", render: (r: any) => `${r.pct}%` },
  ];

  const trendColumns: Column<TrendRow>[] = [
    { key: "quarter_label", header: "Quarter", render: (r: any) => <span className="font-medium">{r.quarter_label}</span> },
    { key: "row_count", header: "Rows", render: (r: any) => String(r.row_count) },
    { key: "avg_our_pct", header: "Avg ours %", render: (r: any) => (r.avg_our_pct ?? "—") },
    { key: "avg_peer_pct", header: "Avg peer %", render: (r: any) => (r.avg_peer_pct ?? "—") },
    { key: "avg_top_pct", header: "Avg top %", render: (r: any) => (r.avg_top_pct ?? "—") },
    { key: "avg_gap_pct", header: "Avg gap %", render: (r: any) => <span className={gapBadge(r.avg_gap_pct)}>{r.avg_gap_pct ?? "—"}</span> },
    { key: "won_count", header: "Won", render: (r: any) => String(r.won_count) },
  ];

  const ownerColumns: Column<OwnerRow>[] = [
    { key: "owner_email", header: "Owner", render: (r: any) => <span className="font-medium">{r.owner_email}</span> },
    { key: "utilization_count", header: "Rows", render: (r: any) => String(r.utilization_count) },
    { key: "open_action_count", header: "Open actions", render: (r: any) => <span className="text-amber-700">{r.open_action_count}</span> },
    { key: "done_action_count", header: "Done actions", render: (r: any) => <span className="text-emerald-700">{r.done_action_count}</span> },
    { key: "expected_uplift_rupees", header: "Expected uplift", render: (r: any) => fmtRupees(r.expected_uplift_rupees) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder customer quarterly equipment utilization bench — r2580</h1>
        <p className="mt-1 text-xs text-gray-500">
          Per-hospital quarterly equipment utilization vs peer benchmark & top-quartile. Gap-to-top &gt; 10% =&gt; growth-lever conversation.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-7">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total rows</div>
          <div className="mt-1 text-lg font-semibold">{totalUtil}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Monitoring</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{monitoring}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">In discussion</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{inDiscussion}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Won</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{wonCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Lost</div>
          <div className="mt-1 text-lg font-semibold text-red-700">{lostCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Avg gap %</div>
          <div className="mt-1 text-lg font-semibold">{avgGap}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Open actions / uplift</div>
          <div className="mt-1 text-lg font-semibold">{openActions} / {fmtRupees(totalUplift)}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top gap focus list</h2>
        <p className="text-xs text-gray-500">
          Monitoring + in-discussion rows ordered by gap-to-top %. Biggest deltas =&gt; biggest revenue unlock.
        </p>
        <DataTable
          rows={focus}
          columns={focusColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No focus rows yet."
        />
      </section>

      <section className="grid grid-cols-1 gap-6 md:grid-cols-2">
        <div className="space-y-3">
          <h2 className="text-base font-semibold">Equipment-kind summary</h2>
          <p className="text-xs text-gray-500">
            Average utilization vs peer & top-quartile per equipment kind. Highest avg-gap =&gt; biggest segment opportunity.
          </p>
          <DataTable
            rows={kinds}
            columns={kindColumns}
            rowKey={(r: any, i: number) => String(r.equipment_kind ?? i)}
            emptyMessage="No equipment rows yet."
          />
        </div>
        <div className="space-y-3">
          <h2 className="text-base font-semibold">Growth-lever distribution</h2>
          <p className="text-xs text-gray-500">
            extended_hours, cross_dept, marketing, training, second_shift, replacement. Win-rate per lever guides playbook.
          </p>
          <DataTable
            rows={levers}
            columns={leverColumns}
            rowKey={(r: any, i: number) => String(r.growth_lever_kind ?? i)}
            emptyMessage="No levers yet."
          />
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Quarterly utilization trend</h2>
        <p className="text-xs text-gray-500">
          Quarter-over-quarter movement on ours vs peer vs top. Trend up =&gt; bench actions working.
        </p>
        <DataTable
          rows={trend}
          columns={trendColumns}
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
          emptyMessage="No quarters yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Owner load</h2>
        <p className="text-xs text-gray-500">
          Per-owner row count, open vs done actions, expected uplift ₹. Imbalance =&gt; reassign.
        </p>
        <DataTable
          rows={owners}
          columns={ownerColumns}
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
          emptyMessage="No owners yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All utilization rows</h2>
        <p className="text-xs text-gray-500">
          Full quarterly bench: hospital × equipment × ours/peer/top % × gap × growth lever × status.
        </p>
        <DataTable
          rows={utils}
          columns={utilColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No utilization rows yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Growth-lever actions</h2>
        <p className="text-xs text-gray-500">
          Action log per utilization row: open =&gt; in_progress =&gt; done/dropped. Expected uplift ₹ tracks ROI.
        </p>
        <DataTable
          rows={actions}
          columns={actionColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No actions yet."
        />
      </section>
    </div>
  );
}
