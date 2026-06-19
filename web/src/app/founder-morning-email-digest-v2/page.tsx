import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder morning email digest v2 · EquipSeva" };
export const dynamic = "force-dynamic";

type ActionRow = {
  action_type: string;
  ref_id: string;
  title: string;
  metric: number | null;
  priority_score: number;
};

type AlertRow = { kind: string; count: number; severity: string };
type MilestoneRow = { kind: string; count: number };

type DigestRow = {
  top_actions: ActionRow[] | null;
  mrr_today: number | null;
  mrr_yesterday: number | null;
  mrr_7d_ago: number | null;
  mrr_30d_ago: number | null;
  mrr_delta_pct_dod: number | null;
  mrr_delta_pct_wow: number | null;
  active_alerts: AlertRow[] | null;
  milestones_24h: MilestoneRow[] | null;
  cron_health: { runs_24h: number; failures_24h: number; failure_rate: number } | null;
  generated_at: string;
};

type LogRow = {
  id: string;
  sent_at: string;
  recipient_email: string;
  delivery_status: string;
  failure_reason: string | null;
  payload_summary: { mrr_today: number | null; top_action_n: number } | null;
};

function fmtPct(n: number | null | undefined) {
  if (n === null || n === undefined) return "—";
  const sign = n > 0 ? "+" : "";
  return `${sign}${n.toFixed(2)}%`;
}

function deltaColor(n: number | null | undefined) {
  if (n === null || n === undefined || n === 0) return "text-[var(--color-muted)]";
  return n > 0 ? "text-[var(--color-ok)]" : "text-[var(--color-danger)]";
}

function severityColor(sev: string) {
  if (sev === "critical") return "text-[var(--color-danger)]";
  if (sev === "high") return "text-[var(--color-warn)]";
  return "text-[var(--color-info)]";
}

export default async function FounderMorningEmailDigestV2Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [{ data: digestData, error: digestErr }, { data: logData }] = await Promise.all([
    supabase.rpc("founder_morning_digest_v2"),
    supabase.rpc("founder_morning_digest_recent", { p_limit: 30 }),
  ]);

  const d: DigestRow | null =
    digestData && Array.isArray(digestData) ? (digestData[0] as DigestRow) : null;
  const logs: LogRow[] = Array.isArray(logData) ? (logData as LogRow[]) : [];

  const today = new Date().toISOString().slice(0, 10);
  const subject = `EquipSeva morning · ${today}`;

  return (
    <main className="mx-auto max-w-5xl space-y-6 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Founder morning email digest v2</h1>
        <p className="text-sm text-[var(--color-muted)]">
          Renders the digest payload as it would be emailed at 07:30 IST. Cron + email delivery
          wiring is the next step (founder_morning_digest_send edge fn).
        </p>
      </header>

      {digestErr ? (
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-[var(--color-danger)]">
          Failed to load digest: {digestErr.message}
        </div>
      ) : null}

      {/* Email preview card */}
      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <div className="border-b border-[var(--color-border)] pb-3">
          <div className="text-xs text-[var(--color-muted)]">Subject</div>
          <div className="text-lg font-medium">{subject}</div>
          <div className="mt-1 text-xs text-[var(--color-muted)]">
            Generated {d?.generated_at ? new Date(d.generated_at).toLocaleString() : "—"}
          </div>
        </div>

        {/* MRR card */}
        <div className="mt-4 grid grid-cols-2 gap-3 md:grid-cols-4">
          <div className="rounded-lg border border-[var(--color-border)] p-3">
            <div className="text-xs text-[var(--color-muted)]">MRR today</div>
            <div className="text-xl font-semibold">
              ₹{formatNumber(Number(d?.mrr_today ?? 0))}
            </div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] p-3">
            <div className="text-xs text-[var(--color-muted)]">vs yesterday</div>
            <div className={`text-xl font-semibold ${deltaColor(d?.mrr_delta_pct_dod)}`}>
              {fmtPct(d?.mrr_delta_pct_dod)}
            </div>
            <div className="text-xs text-[var(--color-muted)]">
              ₹{formatNumber(Number(d?.mrr_yesterday ?? 0))}
            </div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] p-3">
            <div className="text-xs text-[var(--color-muted)]">vs 7d ago</div>
            <div className={`text-xl font-semibold ${deltaColor(d?.mrr_delta_pct_wow)}`}>
              {fmtPct(d?.mrr_delta_pct_wow)}
            </div>
            <div className="text-xs text-[var(--color-muted)]">
              ₹{formatNumber(Number(d?.mrr_7d_ago ?? 0))}
            </div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] p-3">
            <div className="text-xs text-[var(--color-muted)]">30d ago</div>
            <div className="text-xl font-semibold">
              ₹{formatNumber(Number(d?.mrr_30d_ago ?? 0))}
            </div>
          </div>
        </div>

        {/* Top 10 actions */}
        <div className="mt-5">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">
            Top 10 priority actions
          </h2>
          <div className="mt-2 overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)]">
                  <th className="py-2 pr-2">#</th>
                  <th className="py-2 pr-2">Type</th>
                  <th className="py-2 pr-2">Title</th>
                  <th className="py-2 pr-2">Metric</th>
                  <th className="py-2 pr-2">Score</th>
                </tr>
              </thead>
              <tbody>
                {(d?.top_actions ?? []).map((a, i) => (
                  <tr key={`${a.action_type}-${a.ref_id}`} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-2 text-[var(--color-muted)]">{i + 1}</td>
                    <td className="py-2 pr-2">
                      <span className="text-[var(--color-accent)]">{a.action_type}</span>
                    </td>
                    <td className="py-2 pr-2">{a.title}</td>
                    <td className="py-2 pr-2 text-[var(--color-muted)]">
                      {a.metric === null ? "—" : formatNumber(Number(a.metric))}
                    </td>
                    <td className="py-2 pr-2">{Number(a.priority_score).toFixed(0)}</td>
                  </tr>
                ))}
                {(!d?.top_actions || d.top_actions.length === 0) && (
                  <tr>
                    <td colSpan={5} className="py-3 text-center text-[var(--color-muted)]">
                      No priority actions right now.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>

        {/* Alerts + milestones */}
        <div className="mt-5 grid gap-4 md:grid-cols-2">
          <div>
            <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">
              Active alerts
            </h2>
            <ul className="mt-2 space-y-1 text-sm">
              {(d?.active_alerts ?? []).map((a) => (
                <li key={a.kind} className="flex justify-between border-b border-[var(--color-border)] py-1">
                  <span>
                    <span className={severityColor(a.severity)}>●</span> {a.kind}
                  </span>
                  <span className="font-mono">{formatNumber(a.count)}</span>
                </li>
              ))}
            </ul>
          </div>
          <div>
            <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">
              Milestones (last 24h)
            </h2>
            <ul className="mt-2 space-y-1 text-sm">
              {(d?.milestones_24h ?? []).map((m) => (
                <li key={m.kind} className="flex justify-between border-b border-[var(--color-border)] py-1">
                  <span>{m.kind}</span>
                  <span className="font-mono text-[var(--color-ok)]">
                    {formatNumber(m.count)}
                  </span>
                </li>
              ))}
            </ul>
          </div>
        </div>

        {/* Cron health */}
        <div className="mt-5 rounded-lg border border-[var(--color-border)] p-3">
          <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">
            Cron health (24h)
          </h2>
          <div className="mt-2 grid grid-cols-3 gap-3 text-sm">
            <div>
              <div className="text-xs text-[var(--color-muted)]">Runs</div>
              <div className="font-mono">{formatNumber(d?.cron_health?.runs_24h ?? 0)}</div>
            </div>
            <div>
              <div className="text-xs text-[var(--color-muted)]">Failures</div>
              <div className="font-mono text-[var(--color-danger)]">
                {formatNumber(d?.cron_health?.failures_24h ?? 0)}
              </div>
            </div>
            <div>
              <div className="text-xs text-[var(--color-muted)]">Failure rate</div>
              <div className="font-mono">
                {(d?.cron_health?.failure_rate ?? 0).toFixed(2)}%
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* Delivery log */}
      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">
          Recent delivery log (last 30)
        </h2>
        <div className="mt-2 overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs text-[var(--color-muted)]">
                <th className="py-2 pr-2">Sent at</th>
                <th className="py-2 pr-2">Recipient</th>
                <th className="py-2 pr-2">Status</th>
                <th className="py-2 pr-2">MRR snapshot</th>
                <th className="py-2 pr-2">Actions</th>
                <th className="py-2 pr-2">Failure reason</th>
              </tr>
            </thead>
            <tbody>
              {logs.map((l) => (
                <tr key={l.id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-2 font-mono text-xs">
                    {new Date(l.sent_at).toLocaleString()}
                  </td>
                  <td className="py-2 pr-2">{l.recipient_email}</td>
                  <td className="py-2 pr-2">
                    <span
                      className={
                        l.delivery_status === "sent"
                          ? "text-[var(--color-ok)]"
                          : l.delivery_status === "failed"
                          ? "text-[var(--color-danger)]"
                          : "text-[var(--color-muted)]"
                      }
                    >
                      {l.delivery_status}
                    </span>
                  </td>
                  <td className="py-2 pr-2 font-mono">
                    ₹{formatNumber(Number(l.payload_summary?.mrr_today ?? 0))}
                  </td>
                  <td className="py-2 pr-2 font-mono">
                    {formatNumber(l.payload_summary?.top_action_n ?? 0)}
                  </td>
                  <td className="py-2 pr-2 text-[var(--color-danger)]">
                    {l.failure_reason ?? ""}
                  </td>
                </tr>
              ))}
              {logs.length === 0 && (
                <tr>
                  <td colSpan={6} className="py-3 text-center text-[var(--color-muted)]">
                    No deliveries logged yet. Wire founder_morning_digest_send edge fn to populate.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
