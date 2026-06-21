import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type PairRow = {
  id: string;
  mentor_user_id: string;
  mentor_email: string | null;
  mentee_user_id: string;
  mentee_email: string | null;
  started_on: string;
  status: string;
  ended_on: string | null;
  ended_reason: string | null;
  checkin_count: number;
  last_checkin_on: string | null;
  avg_rating: number | null;
};

type CheckinRow = {
  id: string;
  pair_id: string;
  mentor_email: string | null;
  mentee_email: string | null;
  checkin_date: string;
  mentor_notes_md: string | null;
  mentee_notes_md: string | null;
  next_topic: string | null;
  rating: number | null;
  created_at: string;
};

type WorkloadRow = {
  mentor_user_id: string;
  mentor_email: string | null;
  active_mentees: number;
  total_mentees: number;
  total_checkins: number;
  avg_rating: number | null;
  last_checkin_on: string | null;
};

type SummaryRow = {
  total_pairs: number;
  active_pairs: number;
  paused_pairs: number;
  ended_pairs: number;
  total_checkins: number;
  checkins_last_30d: number;
  avg_rating_overall: number | null;
  pairs_no_checkin_30d: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [pairsRes, checkinsRes, workloadRes, summaryRes] = await Promise.all([
    sb.rpc("list_mentorship_pairs_r1672"),
    sb.rpc("list_mentorship_checkins_r1672", { p_pair_id: null }),
    sb.rpc("mentor_workload_r1672"),
    sb.rpc("active_mentorship_pairs_summary_r1672"),
  ]);

  const pairs: PairRow[] = (pairsRes.data ?? []) as PairRow[];
  const checkins: CheckinRow[] = (checkinsRes.data ?? []) as CheckinRow[];
  const workload: WorkloadRow[] = (workloadRes.data ?? []) as WorkloadRow[];
  const summaryArr: SummaryRow[] = (summaryRes.data ?? []) as SummaryRow[];
  const summary: SummaryRow = summaryArr[0] ?? {
    total_pairs: 0,
    active_pairs: 0,
    paused_pairs: 0,
    ended_pairs: 0,
    total_checkins: 0,
    checkins_last_30d: 0,
    avg_rating_overall: null,
    pairs_no_checkin_30d: 0,
  };

  const stalePairs = pairs.filter(
    (p) =>
      p.status === "active" &&
      (!p.last_checkin_on ||
        new Date(p.last_checkin_on) <
          new Date(Date.now() - 30 * 24 * 60 * 60 * 1000))
  );

  const pairCols: Column<PairRow>[] = [
    { key: "mentor_email", header: "Mentor", render: (r) => <span>{r.mentor_email ?? r.mentor_user_id.slice(0, 8)}</span> },
    { key: "mentee_email", header: "Mentee", render: (r) => <span>{r.mentee_email ?? r.mentee_user_id.slice(0, 8)}</span> },
    { key: "started_on", header: "Started", render: (r) => <span>{r.started_on}</span> },
    {
      key: "status",
      header: "Status",
      render: (r) => (
        <span
          style={{
            padding: "2px 8px",
            borderRadius: 12,
            fontSize: 12,
            background:
              r.status === "active"
                ? "#dcfce7"
                : r.status === "paused"
                ? "#fef3c7"
                : "#e5e7eb",
            color:
              r.status === "active"
                ? "#166534"
                : r.status === "paused"
                ? "#92400e"
                : "#374151",
          }}
        >
          {r.status}
        </span>
      ),
    },
    { key: "checkin_count", header: "Check-ins", render: (r) => <span>{r.checkin_count}</span> },
    { key: "last_checkin_on", header: "Last check-in", render: (r) => <span>{r.last_checkin_on ?? "—"}</span> },
    {
      key: "avg_rating",
      header: "Avg rating",
      render: (r) => <span>{r.avg_rating != null ? r.avg_rating.toFixed(2) : "—"}</span>,
    },
    { key: "ended_reason", header: "Ended reason", render: (r) => <span>{r.ended_reason ?? "—"}</span> },
  ];

  const checkinCols: Column<CheckinRow>[] = [
    { key: "checkin_date", header: "Date", render: (r) => <span>{r.checkin_date}</span> },
    { key: "mentor_email", header: "Mentor", render: (r) => <span>{r.mentor_email ?? "—"}</span> },
    { key: "mentee_email", header: "Mentee", render: (r) => <span>{r.mentee_email ?? "—"}</span> },
    {
      key: "rating",
      header: "Rating",
      render: (r) => (
        <span style={{ fontWeight: r.rating && r.rating <= 2 ? 700 : 400, color: r.rating && r.rating <= 2 ? "#b91c1c" : "#111827" }}>
          {r.rating != null ? `${r.rating}/5` : "—"}
        </span>
      ),
    },
    {
      key: "next_topic",
      header: "Next topic",
      render: (r) => <span>{r.next_topic ?? "—"}</span>,
    },
    {
      key: "mentor_notes_md",
      header: "Mentor notes",
      render: (r) => (
        <span style={{ display: "inline-block", maxWidth: 280, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
          {r.mentor_notes_md ?? "—"}
        </span>
      ),
    },
  ];

  const workloadCols: Column<WorkloadRow>[] = [
    { key: "mentor_email", header: "Mentor", render: (r) => <span>{r.mentor_email ?? r.mentor_user_id.slice(0, 8)}</span> },
    { key: "active_mentees", header: "Active mentees", render: (r) => <span>{r.active_mentees}</span> },
    { key: "total_mentees", header: "Lifetime mentees", render: (r) => <span>{r.total_mentees}</span> },
    { key: "total_checkins", header: "Check-ins", render: (r) => <span>{r.total_checkins}</span> },
    {
      key: "avg_rating",
      header: "Avg rating",
      render: (r) => <span>{r.avg_rating != null ? r.avg_rating.toFixed(2) : "—"}</span>,
    },
    { key: "last_checkin_on", header: "Last check-in", render: (r) => <span>{r.last_checkin_on ?? "—"}</span> },
  ];

  const staleCols: Column<PairRow>[] = [
    { key: "mentor_email", header: "Mentor", render: (r) => <span>{r.mentor_email ?? "—"}</span> },
    { key: "mentee_email", header: "Mentee", render: (r) => <span>{r.mentee_email ?? "—"}</span> },
    { key: "started_on", header: "Started", render: (r) => <span>{r.started_on}</span> },
    {
      key: "last_checkin_on",
      header: "Last check-in",
      render: (r) => (
        <span style={{ color: "#b91c1c", fontWeight: 600 }}>{r.last_checkin_on ?? "never"}</span>
      ),
    },
    { key: "checkin_count", header: "Check-ins", render: (r) => <span>{r.checkin_count}</span> },
  ];

  const kpiBox = {
    padding: 16,
    border: "1px solid #e5e7eb",
    borderRadius: 8,
    background: "#fff",
    minWidth: 140,
  } as const;

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: "0 auto", fontFamily: "system-ui, sans-serif" }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 4 }}>Engineer Mentorship Pairings</h1>
        <p style={{ color: "#6b7280" }}>Senior-junior pairings + check-in registry · r1672</p>
      </header>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div style={{ display: "flex", gap: 12, flexWrap: "wrap" }}>
          <div style={kpiBox}>
            <div style={{ fontSize: 12, color: "#6b7280" }}>Total pairs</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.total_pairs}</div>
          </div>
          <div style={kpiBox}>
            <div style={{ fontSize: 12, color: "#6b7280" }}>Active</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: "#166534" }}>{summary.active_pairs}</div>
          </div>
          <div style={kpiBox}>
            <div style={{ fontSize: 12, color: "#6b7280" }}>Paused</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: "#92400e" }}>{summary.paused_pairs}</div>
          </div>
          <div style={kpiBox}>
            <div style={{ fontSize: 12, color: "#6b7280" }}>Ended</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: "#6b7280" }}>{summary.ended_pairs}</div>
          </div>
          <div style={kpiBox}>
            <div style={{ fontSize: 12, color: "#6b7280" }}>Total check-ins</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.total_checkins}</div>
          </div>
          <div style={kpiBox}>
            <div style={{ fontSize: 12, color: "#6b7280" }}>Check-ins (30d)</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>{summary.checkins_last_30d}</div>
          </div>
          <div style={kpiBox}>
            <div style={{ fontSize: 12, color: "#6b7280" }}>Avg rating</div>
            <div style={{ fontSize: 24, fontWeight: 700 }}>
              {summary.avg_rating_overall != null ? summary.avg_rating_overall.toFixed(2) : "—"}
            </div>
          </div>
          <div style={{ ...kpiBox, background: summary.pairs_no_checkin_30d > 0 ? "#fef2f2" : "#fff" }}>
            <div style={{ fontSize: 12, color: "#6b7280" }}>Stale (no 30d check-in)</div>
            <div style={{ fontSize: 24, fontWeight: 700, color: summary.pairs_no_checkin_30d > 0 ? "#b91c1c" : "#111827" }}>
              {summary.pairs_no_checkin_30d}
            </div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Action queue · Stale active pairs ({stalePairs.length})
        </h2>
        {stalePairs.length === 0 ? (
          <p style={{ color: "#6b7280", fontStyle: "italic" }}>All active pairs have recent check-ins.</p>
        ) : (
          <DataTable<PairRow> rows={stalePairs} columns={staleCols} rowKey={(r, i) => String(r.id ?? i)} />
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All pairs ({pairs.length})</h2>
        <DataTable<PairRow> rows={pairs} columns={pairCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Mentor workload ({workload.length})</h2>
        <DataTable<WorkloadRow>
          rows={workload}
          columns={workloadCols}
          rowKey={(r, i) => String(r.mentor_user_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent check-ins ({checkins.length})</h2>
        <DataTable<CheckinRow> rows={checkins} columns={checkinCols} rowKey={(r, i) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
