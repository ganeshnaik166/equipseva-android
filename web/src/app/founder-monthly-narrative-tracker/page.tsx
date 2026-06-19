import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder monthly narrative tracker — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  latest_month_label: string | null;
  latest_status: string | null;
  latest_headline: string | null;
  total_narratives: number;
  draft_count: number;
  reviewed_count: number;
  sent_count: number;
  published_count: number;
  latest_mrr_eom: number | null;
  latest_mrr_delta_mom_pct: number | null;
  last_sent_at: string | null;
  days_since_last_sent: number;
  narratives_ytd: number;
  avg_send_delay_days: number;
};

type NarrativeRow = {
  id: string;
  month_label: string;
  status: string;
  headline: string | null;
  win_summary: string | null;
  loss_summary: string | null;
  ask_summary: string | null;
  kpis_snapshot: Record<string, unknown> | null;
  mrr_eom_rupees: number | null;
  mrr_delta_mom_pct: number | null;
  active_amcs_eom: number | null;
  active_engineers_eom: number | null;
  total_gmv_month_rupees: number | null;
  total_payouts_month_rupees: number | null;
  code_red_count_month: number;
  dispute_count_month: number;
  drafted_at: string | null;
  reviewed_at: string | null;
  sent_at: string | null;
  sent_to: string[] | null;
  notes: string | null;
  created_at: string;
};

const STATUS_LABEL: Record<string, string> = {
  draft: "Draft",
  reviewed: "Reviewed",
  sent: "Sent",
  published: "Published",
};

const STATUS_TONE: Record<string, string> = {
  draft: "text-[var(--color-warn)] border-[var(--color-warn)]",
  reviewed: "text-[var(--color-info)] border-[var(--color-info)]",
  sent: "text-[var(--color-ok)] border-[var(--color-ok)]",
  published: "text-[var(--color-ok)] border-[var(--color-ok)]",
};

function formatLakh(n: number | null): string {
  if (n === null || n === undefined || Number.isNaN(Number(n))) return "—";
  const v = Number(n);
  if (v >= 10000000) return `${(v / 10000000).toFixed(2)}Cr`;
  if (v >= 100000) return `${(v / 100000).toFixed(1)}L`;
  return formatNumber(v);
}

function formatPct(n: number | null): string {
  if (n === null || n === undefined || Number.isNaN(Number(n))) return "—";
  const v = Number(n);
  return `${v >= 0 ? "+" : ""}${v.toFixed(1)}%`;
}

export default async function FounderMonthlyNarrativeTrackerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, recRes] = await Promise.all([
    supabase.rpc("founder_monthly_narrative_summary"),
    supabase.rpc("founder_monthly_narratives_recent", { p_limit: 12 }),
  ]);
  if (sumRes.error) throw new Error(`founder_monthly_narrative_summary: ${sumRes.error.message}`);
  if (recRes.error) throw new Error(`founder_monthly_narratives_recent: ${recRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const rows = (recRes.data ?? []) as NarrativeRow[];
  const latest = rows[0] ?? null;
  const kpiEntries: Array<[string, unknown]> = latest && latest.kpis_snapshot
    ? Object.entries(latest.kpis_snapshot)
    : [];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder monthly narrative tracker ★ r1359</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Monthly investor narrative log · draft → reviewed → sent → published · cadence telemetry · the forcing function against IR silence · 14 KPIs
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-4 lg:grid-cols-5">
          <div className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Latest month</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-accent)]">{s.latest_month_label ?? "—"}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Latest status</div>
            <div className="mt-1 text-lg font-bold">
              {s.latest_status ? (
                <span className={`px-1.5 py-0.5 rounded border text-[11px] uppercase ${STATUS_TONE[s.latest_status] ?? ""}`}>{STATUS_LABEL[s.latest_status] ?? s.latest_status}</span>
              ) : <span className="text-[var(--color-muted)]">—</span>}
            </div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 col-span-2 sm:col-span-2 lg:col-span-3">
            <div className="text-xs text-[var(--color-muted)]">Latest headline</div>
            <div className="mt-1 text-sm font-semibold line-clamp-2">{s.latest_headline ?? <span className="text-[var(--color-muted)]">No narrative yet</span>}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total narratives</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.total_narratives)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Drafts</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${s.draft_count > 0 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]"}`}>{formatNumber(s.draft_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Reviewed</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-info)]">{formatNumber(s.reviewed_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Sent</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.sent_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Published</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.published_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Latest MRR (EoM)</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">₹{formatLakh(s.latest_mrr_eom)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">MRR MoM</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${Number(s.latest_mrr_delta_mom_pct) > 0 ? "text-[var(--color-ok)]" : Number(s.latest_mrr_delta_mom_pct) < 0 ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>{formatPct(s.latest_mrr_delta_mom_pct)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Last sent at</div>
            <div className="mt-1 text-sm font-semibold tabular-nums text-[var(--color-muted)]">{s.last_sent_at ? new Date(s.last_sent_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" }) : "—"}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Days since last sent</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${s.days_since_last_sent > 45 ? "text-[var(--color-danger)]" : s.days_since_last_sent > 35 ? "text-[var(--color-warn)]" : "text-[var(--color-ok)]"}`}>{formatNumber(s.days_since_last_sent)}<span className="text-xs text-[var(--color-muted)]">d</span></div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Narratives YTD</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.narratives_ytd)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg send delay</div>
            <div className={`mt-1 text-2xl font-bold tabular-nums ${Number(s.avg_send_delay_days) > 7 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]"}`}>{Number(s.avg_send_delay_days).toFixed(1)}<span className="text-xs text-[var(--color-muted)]">d</span></div>
          </div>
        </section>
      ) : null}

      {latest ? (
        <section>
          <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Latest narrative · {latest.month_label}</h2>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-5 space-y-4">
            <div className="flex flex-wrap items-center gap-2">
              <span className={`px-1.5 py-0.5 rounded border text-[10px] uppercase ${STATUS_TONE[latest.status] ?? ""}`}>{STATUS_LABEL[latest.status] ?? latest.status}</span>
              <span className="text-xs text-[var(--color-muted)]">Drafted: {latest.drafted_at ? new Date(latest.drafted_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" }) : "—"}</span>
              <span className="text-xs text-[var(--color-muted)]">· Reviewed: {latest.reviewed_at ? new Date(latest.reviewed_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" }) : "—"}</span>
              <span className="text-xs text-[var(--color-muted)]">· Sent: {latest.sent_at ? new Date(latest.sent_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" }) : "—"}</span>
            </div>
            {latest.headline ? <h3 className="text-base font-bold leading-snug">{latest.headline}</h3> : null}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
              <div>
                <h4 className="text-xs font-semibold uppercase tracking-wider text-[var(--color-ok)] mb-1">Wins</h4>
                <p className="text-xs whitespace-pre-wrap leading-relaxed">{latest.win_summary ?? <span className="text-[var(--color-muted)]">—</span>}</p>
              </div>
              <div>
                <h4 className="text-xs font-semibold uppercase tracking-wider text-[var(--color-danger)] mb-1">Losses / lessons</h4>
                <p className="text-xs whitespace-pre-wrap leading-relaxed">{latest.loss_summary ?? <span className="text-[var(--color-muted)]">—</span>}</p>
              </div>
              <div>
                <h4 className="text-xs font-semibold uppercase tracking-wider text-[var(--color-warn)] mb-1">Asks</h4>
                <p className="text-xs whitespace-pre-wrap leading-relaxed">{latest.ask_summary ?? <span className="text-[var(--color-muted)]">—</span>}</p>
              </div>
            </div>
            <div className="grid grid-cols-2 md:grid-cols-4 gap-3 pt-3 border-t border-[var(--color-border)]">
              <div><div className="text-[10px] uppercase text-[var(--color-muted)]">MRR EoM</div><div className="text-sm font-semibold tabular-nums">₹{formatLakh(latest.mrr_eom_rupees)}</div></div>
              <div><div className="text-[10px] uppercase text-[var(--color-muted)]">Active AMCs</div><div className="text-sm font-semibold tabular-nums">{formatNumber(latest.active_amcs_eom ?? 0)}</div></div>
              <div><div className="text-[10px] uppercase text-[var(--color-muted)]">Active engineers</div><div className="text-sm font-semibold tabular-nums">{formatNumber(latest.active_engineers_eom ?? 0)}</div></div>
              <div><div className="text-[10px] uppercase text-[var(--color-muted)]">GMV (month)</div><div className="text-sm font-semibold tabular-nums">₹{formatLakh(latest.total_gmv_month_rupees)}</div></div>
              <div><div className="text-[10px] uppercase text-[var(--color-muted)]">Payouts (month)</div><div className="text-sm font-semibold tabular-nums">₹{formatLakh(latest.total_payouts_month_rupees)}</div></div>
              <div><div className="text-[10px] uppercase text-[var(--color-muted)]">Code Reds</div><div className={`text-sm font-semibold tabular-nums ${latest.code_red_count_month > 0 ? "text-[var(--color-danger)]" : ""}`}>{formatNumber(latest.code_red_count_month)}</div></div>
              <div><div className="text-[10px] uppercase text-[var(--color-muted)]">Disputes</div><div className={`text-sm font-semibold tabular-nums ${latest.dispute_count_month > 0 ? "text-[var(--color-warn)]" : ""}`}>{formatNumber(latest.dispute_count_month)}</div></div>
              <div><div className="text-[10px] uppercase text-[var(--color-muted)]">Sent to</div><div className="text-xs font-semibold truncate" title={latest.sent_to?.join(", ") ?? ""}>{latest.sent_to && latest.sent_to.length > 0 ? `${latest.sent_to.length} recipients` : "—"}</div></div>
            </div>
            {kpiEntries.length > 0 ? (
              <div className="pt-3 border-t border-[var(--color-border)]">
                <h4 className="text-xs font-semibold uppercase tracking-wider text-[var(--color-muted)] mb-2">KPI snapshot (jsonb)</h4>
                <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-2 text-xs">
                  {kpiEntries.map(([k, v]) => (
                    <div key={k} className="rounded border border-[var(--color-border)] px-2 py-1">
                      <div className="text-[10px] uppercase text-[var(--color-muted)]">{k}</div>
                      <div className="font-mono tabular-nums truncate" title={String(v)}>{String(v)}</div>
                    </div>
                  ))}
                </div>
              </div>
            ) : null}
          </div>
        </section>
      ) : (
        <section className="rounded-lg border border-dashed border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-center text-sm text-[var(--color-muted)]">
          No narratives logged yet. Call <code className="font-mono text-xs">log_founder_monthly_narrative_create(p_month_label, p_headline, p_win_summary, p_loss_summary, p_ask_summary)</code> to start the monthly cadence.
        </section>
      )}

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">12-month history</h2>
        {rows.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No history.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-left text-[var(--color-muted)] border-b border-[var(--color-border)]">
                <tr>
                  <th className="py-2 pr-3">Month</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3">Headline</th>
                  <th className="py-2 pr-3 text-right">MRR EoM</th>
                  <th className="py-2 pr-3 text-right">MoM</th>
                  <th className="py-2 pr-3 text-right">AMCs</th>
                  <th className="py-2 pr-3 text-right">Engs</th>
                  <th className="py-2 pr-3 text-right">GMV</th>
                  <th className="py-2 pr-3 text-right">CR</th>
                  <th className="py-2 pr-3 text-right">Disp</th>
                  <th className="py-2 pr-3">Sent at</th>
                </tr>
              </thead>
              <tbody>
                {rows.map(r => (
                  <tr key={r.id} className="border-b border-[var(--color-border)]">
                    <td className="py-2 pr-3 font-semibold tabular-nums">{r.month_label}</td>
                    <td className="py-2 pr-3"><span className={`px-1.5 py-0.5 rounded border text-[10px] uppercase ${STATUS_TONE[r.status] ?? ""}`}>{STATUS_LABEL[r.status] ?? r.status}</span></td>
                    <td className="py-2 pr-3 max-w-[280px] truncate" title={r.headline ?? ""}>{r.headline ?? <span className="text-[var(--color-muted)]">—</span>}</td>
                    <td className="py-2 pr-3 text-right tabular-nums">₹{formatLakh(r.mrr_eom_rupees)}</td>
                    <td className={`py-2 pr-3 text-right tabular-nums ${Number(r.mrr_delta_mom_pct) > 0 ? "text-[var(--color-ok)]" : Number(r.mrr_delta_mom_pct) < 0 ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>{formatPct(r.mrr_delta_mom_pct)}</td>
                    <td className="py-2 pr-3 text-right tabular-nums">{r.active_amcs_eom ?? "—"}</td>
                    <td className="py-2 pr-3 text-right tabular-nums">{r.active_engineers_eom ?? "—"}</td>
                    <td className="py-2 pr-3 text-right tabular-nums">₹{formatLakh(r.total_gmv_month_rupees)}</td>
                    <td className={`py-2 pr-3 text-right tabular-nums ${r.code_red_count_month > 0 ? "text-[var(--color-danger)]" : "text-[var(--color-muted)]"}`}>{r.code_red_count_month}</td>
                    <td className={`py-2 pr-3 text-right tabular-nums ${r.dispute_count_month > 0 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]"}`}>{r.dispute_count_month}</td>
                    <td className="py-2 pr-3 tabular-nums text-[var(--color-muted)]">{r.sent_at ? new Date(r.sent_at).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata" }) : "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
          <h3 className="text-sm font-semibold text-[var(--color-fg)]">Monthly cadence discipline</h3>
          <ul className="list-disc list-inside space-y-1">
            <li>Draft within 3 calendar days of month-end. Reviewed within 5. Sent within 7. Beyond 10d = trust erosion.</li>
            <li>Days-since-last-sent {">"} 35d is amber. {">"} 45d is red — investors will assume the worst before they ask.</li>
            <li>Every month gets a narrative — even down months. Especially down months. Silence implies hiding.</li>
            <li>Headline must compress the month to one line a third-party reader gets in 8 seconds. If it can't, the month was unfocused.</li>
            <li>Wins / Losses / Asks is non-negotiable. No asks = founder pretending not to need help = signal of weakness, not strength.</li>
          </ul>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
          <h3 className="text-sm font-semibold text-[var(--color-fg)]">KPI snapshot rules</h3>
          <ul className="list-disc list-inside space-y-1">
            <li>Same KPIs every month. Changing the metric set mid-fundraise destroys comparability and reads as cherry-picking.</li>
            <li>Required: MRR EoM, MoM%, active AMCs, active engineers, GMV, payouts, Code Reds, disputes. Optional jsonb slot for extras.</li>
            <li>MoM {"<"} 0 demands explanation in the loss_summary — never hide it; investors model retention from your numbers.</li>
            <li>Code Reds {">="} 1 in a month is a board-level discussion item in the next narrative — name the root cause.</li>
            <li>State machine: draft → reviewed → sent → published. "Published" = investor-facing portal version. Use <code className="font-mono">log_founder_monthly_narrative_status()</code>.</li>
          </ul>
        </div>
      </section>
    </div>
  );
}
