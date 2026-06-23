import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder hospital chain executive-event hosted log — r2399" };
export const dynamic = "force-dynamic";

type EventRow = {
  id: string;
  chain_user_id: string;
  event_name: string;
  event_type: string;
  event_date: string;
  venue: string | null;
  city: string | null;
  attendees_count: number | null;
  our_attendees: string | null;
  our_role: string;
  agenda_summary: string | null;
  key_learnings: string | null;
  status: string;
  reviewed_at: string | null;
  closed_at: string | null;
  created_at: string;
};

type RollupRow = {
  chain_user_id: string;
  events_count: number;
  last_event_date: string | null;
  open_followups: number;
  done_followups: number;
  reviewed_count: number;
  closed_count: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function statusBadge(status: string): string {
  if (status === "logged") return "text-slate-700";
  if (status === "reviewed") return "text-sky-700";
  if (status === "followups_open") return "text-amber-700";
  if (status === "closed") return "text-emerald-700";
  if (status === "archived") return "text-gray-500";
  return "";
}

function roleBadge(role: string): string {
  if (role === "speaker" || role === "sponsor") return "text-indigo-700 font-medium";
  if (role === "organizer_partner") return "text-emerald-700 font-medium";
  if (role === "exhibitor") return "text-sky-700";
  if (role === "observer") return "text-gray-500";
  return "";
}

export default async function FounderHospitalChainExecutiveEventHostedLogPage() {
  const sb = await getSupabaseServerClient();
  const [eventsRes, rollupRes] = await Promise.all([
    sb.rpc("list_chain_exec_events_r2399"),
    sb.rpc("chain_exec_event_rollup_r2399"),
  ]);

  if (eventsRes.error) throw new Error(`list_chain_exec_events_r2399: ${eventsRes.error.message}`);
  if (rollupRes.error) throw new Error(`chain_exec_event_rollup_r2399: ${rollupRes.error.message}`);

  const events = (eventsRes.data ?? []) as EventRow[];
  const rollup = (rollupRes.data ?? []) as RollupRow[];

  const totalCount = events.length;
  const loggedCount = events.filter((e) => e.status === "logged").length;
  const reviewedCount = events.filter((e) => e.status === "reviewed").length;
  const followupsOpenCount = events.filter((e) => e.status === "followups_open").length;
  const closedCount = events.filter((e) => e.status === "closed").length;
  const speakerCount = events.filter((e) => e.our_role === "speaker").length;
  const sponsorCount = events.filter((e) => e.our_role === "sponsor").length;
  const last30Count = events.filter((e) => {
    const d = new Date(e.event_date).getTime();
    return Date.now() - d <= 30 * 24 * 3600 * 1000;
  }).length;

  const eventColumns: Column<EventRow>[] = [
    { key: "event_date", header: "Date", render: (r: any) => fmtDate(r.event_date) },
    { key: "event_name", header: "Event", render: (r: any) => <span className="font-medium">{r.event_name}</span> },
    { key: "event_type", header: "Type", render: (r: any) => r.event_type },
    { key: "our_role", header: "Our role", render: (r: any) => <span className={roleBadge(r.our_role)}>{r.our_role}</span> },
    { key: "city", header: "City", render: (r: any) => r.city ?? "—" },
    { key: "venue", header: "Venue", render: (r: any) => r.venue ?? "—" },
    { key: "attendees_count", header: "Attendees", render: (r: any) => (r.attendees_count != null ? String(r.attendees_count) : "—") },
    { key: "our_attendees", header: "Our team", render: (r: any) => r.our_attendees ?? "—" },
    { key: "status", header: "Status", render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span> },
    { key: "key_learnings", header: "Learnings", render: (r: any) => (r.key_learnings ? (r.key_learnings.length > 60 ? r.key_learnings.slice(0, 60) + "…" : r.key_learnings) : "—") },
    { key: "reviewed_at", header: "Reviewed", render: (r: any) => fmtDate(r.reviewed_at) },
    { key: "closed_at", header: "Closed", render: (r: any) => fmtDate(r.closed_at) },
  ];

  const rollupColumns: Column<RollupRow>[] = [
    { key: "chain_user_id", header: "Chain user", render: (r: any) => <span className="font-mono text-[11px]">{String(r.chain_user_id).slice(0, 8)}</span> },
    { key: "events_count", header: "Events", render: (r: any) => String(r.events_count) },
    { key: "last_event_date", header: "Last event", render: (r: any) => fmtDate(r.last_event_date) },
    { key: "open_followups", header: "Open follow-ups", render: (r: any) => <span className={(r.open_followups > 0 ? "text-amber-700 font-medium" : "")}>{String(r.open_followups)}</span> },
    { key: "done_followups", header: "Done", render: (r: any) => String(r.done_followups) },
    { key: "reviewed_count", header: "Reviewed", render: (r: any) => String(r.reviewed_count) },
    { key: "closed_count", header: "Closed", render: (r: any) => String(r.closed_count) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder hospital chain executive-event hosted log — r2399</h1>
        <p className="mt-1 text-xs text-gray-500">
          When chain hosts events (conferences, training days, exec retreats &amp; board meetings), record our presence,
          role, key learnings &amp; follow-ups. Higher attendance =&gt; deeper account intimacy.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-8">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total events</div>
          <div className="mt-1 text-lg font-semibold">{totalCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Last 30d</div>
          <div className="mt-1 text-lg font-semibold">{last30Count}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Logged</div>
          <div className="mt-1 text-lg font-semibold text-slate-700">{loggedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Reviewed</div>
          <div className="mt-1 text-lg font-semibold text-sky-700">{reviewedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Follow-ups open</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{followupsOpenCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Closed</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{closedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Speaker</div>
          <div className="mt-1 text-lg font-semibold text-indigo-700">{speakerCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Sponsor</div>
          <div className="mt-1 text-lg font-semibold text-indigo-700">{sponsorCount}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All hosted events</h2>
        <p className="text-xs text-gray-500">
          Log when chain hosts an exec event & we attend. Capture role, learnings, then mark reviewed when debriefed.
          Open follow-ups (intro requests, proposals, demos, quotes & site visits) drop the event into the
          follow-ups-open state.
        </p>
        <DataTable
          rows={events}
          columns={eventColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No chain executive events logged yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Per-chain rollup</h2>
        <p className="text-xs text-gray-500">
          Per-chain footprint: events attended &amp; follow-up hygiene. Open follow-ups &gt; 0 =&gt; revisit owner &amp; due
          date.
        </p>
        <DataTable
          rows={rollup}
          columns={rollupColumns}
          rowKey={(r: any, i: number) => String(r.chain_user_id ?? i)}
          emptyMessage="No chain rollup yet."
        />
      </section>
    </div>
  );
}
