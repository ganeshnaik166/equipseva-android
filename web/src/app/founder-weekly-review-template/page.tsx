import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = {
  title: "Founder Weekly Review Template · EquipSeva",
  description: "Written weekly review template + log — wins, misses, blockers, priorities, self-ratings.",
};

export const dynamic = "force-dynamic";

type Summary = {
  total_reviews_written: number | null;
  reviews_last_4w: number | null;
  reviews_last_12w: number | null;
  days_since_last_review: number | null;
  latest_week_label: string | null;
  latest_mood: number | null;
  latest_confidence: number | null;
  latest_energy: number | null;
  avg_mood_last_4w: number | null;
  avg_confidence_last_4w: number | null;
  mood_trend_4w: string | null;
  final_status_count: number | null;
  shared_status_count: number | null;
  generated_at: string | null;
};

type Review = {
  id: string;
  week_label: string;
  week_start_date: string;
  week_end_date: string;
  status: string;
  top_3_wins: string | null;
  top_3_misses: string | null;
  biggest_blocker: string | null;
  next_week_priority_1: string | null;
  next_week_priority_2: string | null;
  next_week_priority_3: string | null;
  mood_self_rating: number | null;
  confidence_self_rating: number | null;
  energy_self_rating: number | null;
  one_decision_committed: string | null;
  written_at: string | null;
  shared_at: string | null;
  notes: string | null;
};

function fmtRating(v: number | null | undefined): string {
  if (v === null || v === undefined) return "—";
  return `${v} / 10`;
}

function fmtNum(v: number | null | undefined, digits = 0): string {
  if (v === null || v === undefined) return "—";
  const n = Number(v);
  if (digits > 0) return n.toFixed(digits);
  return formatNumber(Math.round(n));
}

function fmtTrend(t: string | null | undefined): string {
  if (!t) return "—";
  if (t === "improving") return "Improving ↑";
  if (t === "declining") return "Declining ↓";
  return "Stable ·";
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return "—";
  return new Date(s).toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

function statusBadge(s: string): { bg: string; color: string; label: string } {
  if (s === "shared") return { bg: "#dcfce7", color: "#166534", label: "shared" };
  if (s === "final") return { bg: "#dbeafe", color: "#1e40af", label: "final" };
  return { bg: "#fef3c7", color: "#92400e", label: "draft" };
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: summaryRows, error: sErr }, { data: reviewRows, error: rErr }] = await Promise.all([
    supabase.rpc("founder_weekly_review_template_summary"),
    supabase.rpc("founder_weekly_reviews_recent", { p_limit: 12 }),
  ]);

  if (sErr) {
    return <div style={{ padding: 24, color: "#b91c1c" }}>Summary error: {sErr.message}</div>;
  }
  if (rErr) {
    return <div style={{ padding: 24, color: "#b91c1c" }}>Recent error: {rErr.message}</div>;
  }

  const summary: Summary = (Array.isArray(summaryRows) ? summaryRows[0] : summaryRows) ?? ({} as Summary);
  const reviews: Review[] = Array.isArray(reviewRows) ? (reviewRows as Review[]) : [];
  const latest: Review | null = reviews.length > 0 ? reviews[0] : null;

  const cards: { label: string; value: string; hint?: string }[] = [
    { label: "Total reviews written", value: fmtNum(summary.total_reviews_written), hint: "All-time count" },
    { label: "Reviews last 4w", value: fmtNum(summary.reviews_last_4w), hint: "Target ≥ 4" },
    { label: "Reviews last 12w", value: fmtNum(summary.reviews_last_12w), hint: "Target ≥ 12" },
    { label: "Days since last review", value: fmtNum(summary.days_since_last_review), hint: "Lower is better" },
    { label: "Latest week", value: summary.latest_week_label ?? "—", hint: "Most recent log" },
    { label: "Latest mood", value: fmtRating(summary.latest_mood) },
    { label: "Latest confidence", value: fmtRating(summary.latest_confidence) },
    { label: "Latest energy", value: fmtRating(summary.latest_energy) },
    { label: "Avg mood 4w", value: fmtNum(summary.avg_mood_last_4w, 1), hint: "Out of 10" },
    { label: "Avg confidence 4w", value: fmtNum(summary.avg_confidence_last_4w, 1), hint: "Out of 10" },
    { label: "Mood trend 4w", value: fmtTrend(summary.mood_trend_4w) },
    { label: "Final reviews", value: fmtNum(summary.final_status_count) },
    { label: "Shared reviews", value: fmtNum(summary.shared_status_count) },
    { label: "Generated at", value: summary.generated_at ? new Date(summary.generated_at).toLocaleString("en-IN") : "—" },
  ];

  return (
    <main style={{ padding: "24px 32px", maxWidth: 1280, margin: "0 auto", fontFamily: "system-ui, -apple-system, sans-serif" }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 28, fontWeight: 700, margin: 0, color: "#0f172a" }}>Founder Weekly Review Template</h1>
        <p style={{ marginTop: 6, color: "#475569", fontSize: 14 }}>
          Written weekly review template + log. Capture top 3 wins, misses, biggest blocker, next-week priorities, and self-ratings (mood · confidence · energy).
        </p>
      </header>

      <section aria-label="KPIs" style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(180px, 1fr))", gap: 12, marginBottom: 32 }}>
        {cards.map((c) => (
          <div key={c.label} style={{ border: "1px solid #e2e8f0", borderRadius: 10, padding: 14, background: "#ffffff" }}>
            <div style={{ fontSize: 11, textTransform: "uppercase", letterSpacing: 0.4, color: "#64748b", fontWeight: 600 }}>{c.label}</div>
            <div style={{ fontSize: 22, fontWeight: 700, color: "#0f172a", marginTop: 4 }}>{c.value}</div>
            {c.hint ? <div style={{ fontSize: 11, color: "#94a3b8", marginTop: 2 }}>{c.hint}</div> : null}
          </div>
        ))}
      </section>

      <section aria-label="Latest review" style={{ marginBottom: 36 }}>
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12, color: "#0f172a" }}>Latest review</h2>
        {latest ? (
          <article style={{ border: "1px solid #e2e8f0", borderRadius: 12, padding: 20, background: "#f8fafc" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 12, marginBottom: 16, flexWrap: "wrap" }}>
              <span style={{ fontSize: 18, fontWeight: 700, color: "#0f172a" }}>{latest.week_label}</span>
              <span style={{ fontSize: 12, color: "#64748b" }}>{fmtDate(latest.week_start_date)} → {fmtDate(latest.week_end_date)}</span>
              {(() => {
                const b = statusBadge(latest.status);
                return <span style={{ background: b.bg, color: b.color, padding: "3px 10px", borderRadius: 999, fontSize: 11, fontWeight: 600, textTransform: "uppercase", letterSpacing: 0.4 }}>{b.label}</span>;
              })()}
              <span style={{ fontSize: 12, color: "#64748b" }}>Mood {fmtRating(latest.mood_self_rating)} · Confidence {fmtRating(latest.confidence_self_rating)} · Energy {fmtRating(latest.energy_self_rating)}</span>
            </div>

            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(280px, 1fr))", gap: 16 }}>
              <div>
                <div style={{ fontSize: 12, fontWeight: 600, color: "#16a34a", textTransform: "uppercase", letterSpacing: 0.4, marginBottom: 4 }}>Top 3 wins</div>
                <div style={{ whiteSpace: "pre-wrap", color: "#0f172a", fontSize: 14 }}>{latest.top_3_wins ?? "—"}</div>
              </div>
              <div>
                <div style={{ fontSize: 12, fontWeight: 600, color: "#dc2626", textTransform: "uppercase", letterSpacing: 0.4, marginBottom: 4 }}>Top 3 misses</div>
                <div style={{ whiteSpace: "pre-wrap", color: "#0f172a", fontSize: 14 }}>{latest.top_3_misses ?? "—"}</div>
              </div>
              <div>
                <div style={{ fontSize: 12, fontWeight: 600, color: "#b45309", textTransform: "uppercase", letterSpacing: 0.4, marginBottom: 4 }}>Biggest blocker</div>
                <div style={{ whiteSpace: "pre-wrap", color: "#0f172a", fontSize: 14 }}>{latest.biggest_blocker ?? "—"}</div>
              </div>
              <div>
                <div style={{ fontSize: 12, fontWeight: 600, color: "#1e40af", textTransform: "uppercase", letterSpacing: 0.4, marginBottom: 4 }}>Next-week priorities</div>
                <ol style={{ margin: 0, paddingLeft: 18, color: "#0f172a", fontSize: 14 }}>
                  <li>{latest.next_week_priority_1 ?? "—"}</li>
                  <li>{latest.next_week_priority_2 ?? "—"}</li>
                  <li>{latest.next_week_priority_3 ?? "—"}</li>
                </ol>
              </div>
              <div style={{ gridColumn: "1 / -1" }}>
                <div style={{ fontSize: 12, fontWeight: 600, color: "#7c3aed", textTransform: "uppercase", letterSpacing: 0.4, marginBottom: 4 }}>One decision committed</div>
                <div style={{ whiteSpace: "pre-wrap", color: "#0f172a", fontSize: 14 }}>{latest.one_decision_committed ?? "—"}</div>
              </div>
              {latest.notes ? (
                <div style={{ gridColumn: "1 / -1" }}>
                  <div style={{ fontSize: 12, fontWeight: 600, color: "#64748b", textTransform: "uppercase", letterSpacing: 0.4, marginBottom: 4 }}>Notes</div>
                  <div style={{ whiteSpace: "pre-wrap", color: "#334155", fontSize: 13 }}>{latest.notes}</div>
                </div>
              ) : null}
            </div>

            <div style={{ marginTop: 16, fontSize: 11, color: "#94a3b8" }}>
              Written {latest.written_at ? new Date(latest.written_at).toLocaleString("en-IN") : "—"}
              {latest.shared_at ? ` · Shared ${new Date(latest.shared_at).toLocaleString("en-IN")}` : ""}
            </div>
          </article>
        ) : (
          <div style={{ border: "1px dashed #cbd5e1", borderRadius: 12, padding: 24, color: "#64748b", fontSize: 14, textAlign: "center" }}>
            No review written yet. Call log_founder_weekly_review_record(...) to start your first weekly journal entry.
          </div>
        )}
      </section>

      <section aria-label="12-week history">
        <h2 style={{ fontSize: 18, fontWeight: 700, marginBottom: 12, color: "#0f172a" }}>12-week history</h2>
        <div style={{ overflowX: "auto", border: "1px solid #e2e8f0", borderRadius: 10 }}>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13, minWidth: 920 }}>
            <thead style={{ background: "#f1f5f9" }}>
              <tr>
                <th style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#475569" }}>Week</th>
                <th style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#475569" }}>Range</th>
                <th style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#475569" }}>Status</th>
                <th style={{ textAlign: "right", padding: "10px 12px", fontWeight: 600, color: "#475569" }}>Mood</th>
                <th style={{ textAlign: "right", padding: "10px 12px", fontWeight: 600, color: "#475569" }}>Confidence</th>
                <th style={{ textAlign: "right", padding: "10px 12px", fontWeight: 600, color: "#475569" }}>Energy</th>
                <th style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#475569" }}>Blocker</th>
                <th style={{ textAlign: "left", padding: "10px 12px", fontWeight: 600, color: "#475569" }}>Decision committed</th>
              </tr>
            </thead>
            <tbody>
              {reviews.length === 0 ? (
                <tr>
                  <td colSpan={8} style={{ padding: 24, textAlign: "center", color: "#94a3b8" }}>No reviews logged yet.</td>
                </tr>
              ) : (
                reviews.map((r) => {
                  const b = statusBadge(r.status);
                  return (
                    <tr key={r.id} style={{ borderTop: "1px solid #e2e8f0" }}>
                      <td style={{ padding: "10px 12px", fontWeight: 600, color: "#0f172a" }}>{r.week_label}</td>
                      <td style={{ padding: "10px 12px", color: "#475569", whiteSpace: "nowrap" }}>{fmtDate(r.week_start_date)} → {fmtDate(r.week_end_date)}</td>
                      <td style={{ padding: "10px 12px" }}>
                        <span style={{ background: b.bg, color: b.color, padding: "2px 8px", borderRadius: 999, fontSize: 11, fontWeight: 600, textTransform: "uppercase", letterSpacing: 0.4 }}>{b.label}</span>
                      </td>
                      <td style={{ padding: "10px 12px", textAlign: "right", color: "#0f172a" }}>{fmtRating(r.mood_self_rating)}</td>
                      <td style={{ padding: "10px 12px", textAlign: "right", color: "#0f172a" }}>{fmtRating(r.confidence_self_rating)}</td>
                      <td style={{ padding: "10px 12px", textAlign: "right", color: "#0f172a" }}>{fmtRating(r.energy_self_rating)}</td>
                      <td style={{ padding: "10px 12px", color: "#334155", maxWidth: 240, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{r.biggest_blocker ?? "—"}</td>
                      <td style={{ padding: "10px 12px", color: "#334155", maxWidth: 260, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{r.one_decision_committed ?? "—"}</td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
        <p style={{ marginTop: 10, fontSize: 11, color: "#94a3b8" }}>
          Showing latest {reviews.length} of last 12 reviews · RPC founder_weekly_reviews_recent(12)
        </p>
      </section>
    </main>
  );
}
