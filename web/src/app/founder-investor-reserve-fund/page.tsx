import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type SummaryRow = {
  investor_count: number;
  total_commitment_rupees: number;
  total_reserve_rupees: number;
  total_deployed_rupees: number;
  total_available_rupees: number;
  eager_count: number;
  warm_count: number;
  cool_count: number;
  done_count: number;
};

type InvestorRow = {
  id: string;
  investor_name: string;
  investor_firm: string | null;
  fund_vintage_year: number | null;
  total_commitment_rupees: number;
  initial_check_rupees: number;
  reserve_set_aside_rupees: number;
  reserve_deployed_rupees: number;
  reserve_available_rupees: number;
  follow_on_appetite: string;
  next_trigger_at: string | null;
  last_check_in_at: string | null;
};

type AppetiteRow = {
  appetite: string;
  investor_count: number;
  reserve_available_rupees: number;
};

type TriggerRow = {
  id: string;
  investor_name: string;
  investor_firm: string | null;
  next_trigger_at: string;
  days_until: number;
  reserve_available_rupees: number;
  trigger_thesis: string | null;
};

type EventRow = {
  id: string;
  investor_id: string;
  investor_name: string;
  event_type: string;
  amount_rupees: number;
  signal_strength: number | null;
  note: string | null;
  occurred_at: string;
};

type StaleRow = {
  id: string;
  investor_name: string;
  investor_firm: string | null;
  last_check_in_at: string | null;
  days_stale: number;
  reserve_available_rupees: number;
};

type TopRow = {
  id: string;
  investor_name: string;
  investor_firm: string | null;
  reserve_available_rupees: number;
  follow_on_appetite: string;
  signal_avg: number | null;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  if (n >= 10000000) return "₹" + (n / 10000000).toFixed(2) + " Cr";
  if (n >= 100000) return "₹" + (n / 100000).toFixed(2) + " L";
  return "₹" + n.toLocaleString("en-IN");
}

function fmtDate(iso: string | null | undefined): string {
  if (!iso) return "—";
  try {
    return new Date(iso).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
  } catch {
    return iso;
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  let summary: SummaryRow | null = null;
  let investors: InvestorRow[] = [];
  let appetite: AppetiteRow[] = [];
  let triggers: TriggerRow[] = [];
  let events: EventRow[] = [];
  let stale: StaleRow[] = [];
  let top: TopRow[] = [];
  let errMsg: string | null = null;

  try {
    const r1 = await sb.rpc("rpc_founder_reserve_portfolio_summary");
    if (r1.error) throw r1.error;
    summary = (r1.data && r1.data[0]) || null;
  } catch (e: any) {
    errMsg = e?.message || "summary load failed";
  }

  try {
    const r2 = await sb.rpc("rpc_founder_reserve_investor_list");
    if (!r2.error && r2.data) investors = r2.data as InvestorRow[];
  } catch {}

  try {
    const r3 = await sb.rpc("rpc_founder_reserve_appetite_breakdown");
    if (!r3.error && r3.data) appetite = r3.data as AppetiteRow[];
  } catch {}

  try {
    const r4 = await sb.rpc("rpc_founder_reserve_upcoming_triggers");
    if (!r4.error && r4.data) triggers = r4.data as TriggerRow[];
  } catch {}

  try {
    const r5 = await sb.rpc("rpc_founder_reserve_recent_events", { p_limit: 30 });
    if (!r5.error && r5.data) events = r5.data as EventRow[];
  } catch {}

  try {
    const r6 = await sb.rpc("rpc_founder_reserve_stale_check_ins");
    if (!r6.error && r6.data) stale = r6.data as StaleRow[];
  } catch {}

  try {
    const r7 = await sb.rpc("rpc_founder_reserve_top_available");
    if (!r7.error && r7.data) top = r7.data as TopRow[];
  } catch {}

  const investorCols: Column<InvestorRow>[] = [
    { key: "investor_name", header: "Investor", render: (r: InvestorRow) => (
      <div>
        <div className="font-medium">{r.investor_name ?? "—"}</div>
        <div className="text-xs text-zinc-500">{r.investor_firm ?? "—"}</div>
      </div>
    )},
    { key: "fund_vintage_year", header: "Vintage", render: (r: InvestorRow) => <span>{r.fund_vintage_year ?? "—"}</span> },
    { key: "total_commitment_rupees", header: "Commitment", render: (r: InvestorRow) => <span>{fmtRupees(r.total_commitment_rupees)}</span> },
    { key: "reserve_set_aside_rupees", header: "Reserve", render: (r: InvestorRow) => <span>{fmtRupees(r.reserve_set_aside_rupees)}</span> },
    { key: "reserve_deployed_rupees", header: "Deployed", render: (r: InvestorRow) => <span>{fmtRupees(r.reserve_deployed_rupees)}</span> },
    { key: "reserve_available_rupees", header: "Available", render: (r: InvestorRow) => <span className="font-medium">{fmtRupees(r.reserve_available_rupees)}</span> },
    { key: "follow_on_appetite", header: "Appetite", render: (r: InvestorRow) => <span className="capitalize">{r.follow_on_appetite ?? "—"}</span> },
    { key: "next_trigger_at", header: "Next Trigger", render: (r: InvestorRow) => <span>{fmtDate(r.next_trigger_at)}</span> },
    { key: "last_check_in_at", header: "Last Check-in", render: (r: InvestorRow) => <span>{fmtDate(r.last_check_in_at)}</span> },
  ];

  const appetiteCols: Column<AppetiteRow>[] = [
    { key: "appetite", header: "Appetite", render: (r: AppetiteRow) => <span className="capitalize">{r.appetite ?? "—"}</span> },
    { key: "investor_count", header: "Investors", render: (r: AppetiteRow) => <span>{r.investor_count ?? 0}</span> },
    { key: "reserve_available_rupees", header: "Available Reserve", render: (r: AppetiteRow) => <span>{fmtRupees(r.reserve_available_rupees)}</span> },
  ];

  const triggerCols: Column<TriggerRow>[] = [
    { key: "investor_name", header: "Investor", render: (r: TriggerRow) => (
      <div>
        <div className="font-medium">{r.investor_name ?? "—"}</div>
        <div className="text-xs text-zinc-500">{r.investor_firm ?? "—"}</div>
      </div>
    )},
    { key: "next_trigger_at", header: "Trigger Date", render: (r: TriggerRow) => <span>{fmtDate(r.next_trigger_at)}</span> },
    { key: "days_until", header: "Days", render: (r: TriggerRow) => <span>{r.days_until ?? "—"}</span> },
    { key: "reserve_available_rupees", header: "Available", render: (r: TriggerRow) => <span>{fmtRupees(r.reserve_available_rupees)}</span> },
    { key: "trigger_thesis", header: "Thesis", render: (r: TriggerRow) => <span className="text-sm">{r.trigger_thesis ?? "—"}</span> },
  ];

  const eventCols: Column<EventRow>[] = [
    { key: "occurred_at", header: "When", render: (r: EventRow) => <span>{fmtDate(r.occurred_at)}</span> },
    { key: "investor_name", header: "Investor", render: (r: EventRow) => <span className="font-medium">{r.investor_name ?? "—"}</span> },
    { key: "event_type", header: "Type", render: (r: EventRow) => <span className="capitalize">{r.event_type ?? "—"}</span> },
    { key: "amount_rupees", header: "Amount", render: (r: EventRow) => <span>{r.amount_rupees ? fmtRupees(r.amount_rupees) : "—"}</span> },
    { key: "signal_strength", header: "Signal", render: (r: EventRow) => <span>{r.signal_strength ? "★".repeat(r.signal_strength) : "—"}</span> },
    { key: "note", header: "Note", render: (r: EventRow) => <span className="text-sm">{r.note ?? "—"}</span> },
  ];

  const staleCols: Column<StaleRow>[] = [
    { key: "investor_name", header: "Investor", render: (r: StaleRow) => (
      <div>
        <div className="font-medium">{r.investor_name ?? "—"}</div>
        <div className="text-xs text-zinc-500">{r.investor_firm ?? "—"}</div>
      </div>
    )},
    { key: "last_check_in_at", header: "Last Check-in", render: (r: StaleRow) => <span>{fmtDate(r.last_check_in_at)}</span> },
    { key: "days_stale", header: "Days Stale", render: (r: StaleRow) => <span className="font-medium">{r.days_stale ?? "—"}</span> },
    { key: "reserve_available_rupees", header: "Available", render: (r: StaleRow) => <span>{fmtRupees(r.reserve_available_rupees)}</span> },
  ];

  const topCols: Column<TopRow>[] = [
    { key: "investor_name", header: "Investor", render: (r: TopRow) => (
      <div>
        <div className="font-medium">{r.investor_name ?? "—"}</div>
        <div className="text-xs text-zinc-500">{r.investor_firm ?? "—"}</div>
      </div>
    )},
    { key: "reserve_available_rupees", header: "Available", render: (r: TopRow) => <span className="font-medium">{fmtRupees(r.reserve_available_rupees)}</span> },
    { key: "follow_on_appetite", header: "Appetite", render: (r: TopRow) => <span className="capitalize">{r.follow_on_appetite ?? "—"}</span> },
    { key: "signal_avg", header: "Avg Signal", render: (r: TopRow) => <span>{r.signal_avg ? Number(r.signal_avg).toFixed(2) : "—"}</span> },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-semibold">Investor Reserve Fund Tracker</h1>
        <p className="text-sm text-zinc-500 mt-1">Per-investor reserve (follow-on) commitments vs available dry powder. Timing triggers and check-in cadence.</p>
      </header>

      {errMsg ? (
        <div className="rounded border border-red-300 bg-red-50 p-3 text-sm text-red-800">{errMsg}</div>
      ) : null}

      <section className="grid grid-cols-2 md:grid-cols-5 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-zinc-500">Investors</div>
          <div className="text-xl font-semibold">{summary?.investor_count ?? 0}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-zinc-500">Total Commitment</div>
          <div className="text-xl font-semibold">{fmtRupees(summary?.total_commitment_rupees ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-zinc-500">Reserve Set Aside</div>
          <div className="text-xl font-semibold">{fmtRupees(summary?.total_reserve_rupees ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-zinc-500">Deployed</div>
          <div className="text-xl font-semibold">{fmtRupees(summary?.total_deployed_rupees ?? 0)}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-zinc-500">Available</div>
          <div className="text-xl font-semibold">{fmtRupees(summary?.total_available_rupees ?? 0)}</div>
        </div>
      </section>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3"><div className="text-xs text-zinc-500">Eager</div><div className="text-lg font-semibold">{summary?.eager_count ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-zinc-500">Warm</div><div className="text-lg font-semibold">{summary?.warm_count ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-zinc-500">Cool</div><div className="text-lg font-semibold">{summary?.cool_count ?? 0}</div></div>
        <div className="rounded border p-3"><div className="text-xs text-zinc-500">Done</div><div className="text-lg font-semibold">{summary?.done_count ?? 0}</div></div>
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Upcoming Timing Triggers</h2>
        <DataTable<TriggerRow> rows={triggers} columns={triggerCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Top Available Dry Powder</h2>
        <DataTable<TopRow> rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Stale Check-ins (warm/eager, 45+ days)</h2>
        <DataTable<StaleRow> rows={stale} columns={staleCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Appetite Breakdown</h2>
        <DataTable<AppetiteRow> rows={appetite} columns={appetiteCols} rowKey={(r: any, i: number) => String(r.appetite ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">All Investors</h2>
        <DataTable<InvestorRow> rows={investors} columns={investorCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-medium mb-2">Recent Events</h2>
        <DataTable<EventRow> rows={events} columns={eventCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
