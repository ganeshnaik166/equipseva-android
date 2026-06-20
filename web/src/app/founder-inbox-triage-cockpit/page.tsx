import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder inbox triage cockpit — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_items: number;
  unread_count: number;
  p0_count: number;
  p1_count: number;
  medium_count: number;
  low_count: number;
  snoozed_count: number;
  replied_30d: number;
  escalated_30d: number;
  archived_30d: number;
  closed_30d: number;
  items_30d: number;
  items_7d: number;
  overdue_count: number;
  avg_response_lag_hours: number;
  top_source_kind: string;
  top_category: string;
};

type RecentRow = {
  id: string;
  source_kind: string;
  sender_label: string | null;
  subject: string | null;
  snippet: string | null;
  urgency_band: string;
  category: string;
  triage_status: string;
  response_due_at: string | null;
  received_at: string;
  age_hours: number;
};

function Card({ label, value, tone, sub }: { label: string; value: string | number; tone?: string; sub?: string }) {
  return (
    <div className={`rounded-lg border ${tone ?? "border-[var(--color-border)]"} bg-[var(--color-surface)] p-4`}>
      <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-2xl font-bold tabular-nums">{value}</div>
      {sub ? <div className="mt-1 text-[10px] text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

const URGENCY_TONE: Record<string, string> = {
  p0_critical: "text-[var(--color-danger)] border-[var(--color-danger)]",
  p1_high:     "text-[var(--color-warn)] border-[var(--color-warn)]",
  medium:      "text-[var(--color-info)] border-[var(--color-info)]",
  low:         "text-[var(--color-muted)] border-[var(--color-border)]",
};

const STATUS_TONE: Record<string, string> = {
  unread:    "text-[var(--color-warn)]",
  triaged:   "text-[var(--color-info)]",
  snoozed:   "text-[var(--color-muted)]",
  replied:   "text-[var(--color-ok)]",
  escalated: "text-[var(--color-danger)]",
  archived:  "text-[var(--color-muted)]",
  closed:    "text-[var(--color-ok)]",
};

const SOURCE_LABEL: Record<string, string> = {
  email:           "Email",
  slack:           "Slack",
  sms:             "SMS",
  whatsapp:        "WhatsApp",
  phone_voicemail: "Voicemail",
  escalation:      "Escalation",
  priority_action: "Priority",
  dunning:         "Dunning",
  dispute:         "Dispute",
  code_red:        "Code Red",
};

export default async function FounderInboxTriageCockpitPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, recentRes] = await Promise.all([
    supabase.rpc("founder_inbox_triage_summary"),
    supabase.rpc("founder_inbox_items_recent", { p_limit: 100 }),
  ]);
  if (summaryRes.error) throw new Error(`founder_inbox_triage_summary: ${summaryRes.error.message}`);
  if (recentRes.error) throw new Error(`founder_inbox_items_recent: ${recentRes.error.message}`);

  const s = ((summaryRes.data ?? [])[0] ?? {}) as SummaryRow;
  const rows = (recentRes.data ?? []) as RecentRow[];

  const unreadBannerTone =
    (s.p0_count ?? 0) > 0
      ? "border-[var(--color-danger)] bg-[var(--color-danger)]/10"
      : (s.unread_count ?? 0) > 10
      ? "border-[var(--color-warn)] bg-[var(--color-warn)]/10"
      : "border-[var(--color-border)] bg-[var(--color-surface)]";

  return (
    <main className="mx-auto max-w-7xl px-6 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">Founder inbox triage cockpit</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          Unified founder inbox across email, Slack, SMS, WhatsApp, voicemail, escalations, priority actions, dunning,
          disputes, and code-red events. Triage, snooze, reply, escalate.
        </p>
      </header>

      <section className={`mb-6 rounded-lg border p-4 ${unreadBannerTone}`}>
        <div className="flex flex-wrap items-baseline gap-4">
          <div>
            <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">Unread</div>
            <div className="text-3xl font-bold tabular-nums">{formatNumber(s.unread_count ?? 0)}</div>
          </div>
          <div>
            <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">P0 critical open</div>
            <div className="text-3xl font-bold tabular-nums text-[var(--color-danger)]">
              {formatNumber(s.p0_count ?? 0)}
            </div>
          </div>
          <div>
            <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">P1 high open</div>
            <div className="text-3xl font-bold tabular-nums text-[var(--color-warn)]">
              {formatNumber(s.p1_count ?? 0)}
            </div>
          </div>
          <div>
            <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">Overdue</div>
            <div className="text-3xl font-bold tabular-nums text-[var(--color-danger)]">
              {formatNumber(s.overdue_count ?? 0)}
            </div>
          </div>
        </div>
      </section>

      <section className="mb-8 grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-4">
        <Card label="Total items" value={formatNumber(s.total_items ?? 0)} />
        <Card label="Unread" value={formatNumber(s.unread_count ?? 0)} tone="border-[var(--color-warn)]" />
        <Card label="P0 critical" value={formatNumber(s.p0_count ?? 0)} tone="border-[var(--color-danger)]" />
        <Card label="P1 high" value={formatNumber(s.p1_count ?? 0)} tone="border-[var(--color-warn)]" />
        <Card label="Medium open" value={formatNumber(s.medium_count ?? 0)} />
        <Card label="Low open" value={formatNumber(s.low_count ?? 0)} />
        <Card label="Snoozed" value={formatNumber(s.snoozed_count ?? 0)} />
        <Card label="Overdue" value={formatNumber(s.overdue_count ?? 0)} tone="border-[var(--color-danger)]" />
        <Card label="Replied 30d" value={formatNumber(s.replied_30d ?? 0)} tone="border-[var(--color-ok)]" />
        <Card label="Escalated 30d" value={formatNumber(s.escalated_30d ?? 0)} />
        <Card label="Archived 30d" value={formatNumber(s.archived_30d ?? 0)} />
        <Card label="Closed 30d" value={formatNumber(s.closed_30d ?? 0)} />
        <Card label="Items 30d" value={formatNumber(s.items_30d ?? 0)} />
        <Card label="Items 7d" value={formatNumber(s.items_7d ?? 0)} />
        <Card label="Avg response lag" value={`${formatNumber(s.avg_response_lag_hours ?? 0)} h`} />
        <Card label="Top source" value={SOURCE_LABEL[s.top_source_kind] ?? s.top_source_kind ?? "none"} sub={`Top category: ${s.top_category ?? "none"}`} />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Inbox feed (latest 100)</h2>
        {rows.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-sm text-[var(--color-muted)]">
            No inbox items yet. Connect email/slack/sms ingestion to populate.
          </div>
        ) : (
          <div className="overflow-x-auto rounded-lg border border-[var(--color-border)]">
            <table className="w-full min-w-[960px] text-sm">
              <thead className="bg-[var(--color-surface)] text-left text-[11px] uppercase tracking-wider text-[var(--color-muted)]">
                <tr>
                  <th className="px-3 py-2">Source</th>
                  <th className="px-3 py-2">Sender</th>
                  <th className="px-3 py-2">Subject</th>
                  <th className="px-3 py-2">Urgency</th>
                  <th className="px-3 py-2">Category</th>
                  <th className="px-3 py-2">Status</th>
                  <th className="px-3 py-2 text-right">Age (h)</th>
                  <th className="px-3 py-2">Due</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((r) => {
                  const overdue =
                    r.response_due_at !== null &&
                    new Date(r.response_due_at).getTime() < Date.now() &&
                    !["replied", "closed", "archived"].includes(r.triage_status);
                  return (
                    <tr key={r.id} className="border-t border-[var(--color-border)]">
                      <td className="px-3 py-2">
                        <span className="rounded border border-[var(--color-border)] px-1.5 py-0.5 text-[10px]">
                          {SOURCE_LABEL[r.source_kind] ?? r.source_kind}
                        </span>
                      </td>
                      <td className="px-3 py-2">{r.sender_label ?? "—"}</td>
                      <td className="px-3 py-2">
                        <div className="font-medium">{r.subject ?? "(no subject)"}</div>
                        {r.snippet ? (
                          <div className="mt-0.5 line-clamp-1 text-[11px] text-[var(--color-muted)]">{r.snippet}</div>
                        ) : null}
                      </td>
                      <td className="px-3 py-2">
                        <span
                          className={`rounded border px-1.5 py-0.5 text-[10px] uppercase ${
                            URGENCY_TONE[r.urgency_band] ?? "border-[var(--color-border)]"
                          }`}
                        >
                          {r.urgency_band}
                        </span>
                      </td>
                      <td className="px-3 py-2 text-[var(--color-muted)]">{r.category}</td>
                      <td className={`px-3 py-2 ${STATUS_TONE[r.triage_status] ?? ""}`}>{r.triage_status}</td>
                      <td className="px-3 py-2 text-right tabular-nums">{formatNumber(r.age_hours ?? 0)}</td>
                      <td className={`px-3 py-2 ${overdue ? "text-[var(--color-danger)] font-semibold" : "text-[var(--color-muted)]"}`}>
                        {r.response_due_at ? new Date(r.response_due_at).toLocaleString() : "—"}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>
    </main>
  );
}
