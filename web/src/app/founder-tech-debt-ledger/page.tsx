import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder tech debt ledger — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_items: number;
  open_count: number;
  triaged_count: number;
  in_progress_count: number;
  paid_off_count: number;
  wont_do_count: number;
  high_severity_open: number;
  medium_severity_open: number;
  low_severity_open: number;
  total_estimated_effort_days_open: number;
  oldest_open_age_days: number;
  paid_off_last_30d: number;
  top_area: string;
  top_area_count: number;
  avg_payback_priority_open: number;
};

type Item = {
  id: string;
  title: string;
  area: string;
  severity: "high" | "medium" | "low";
  payback_kind: string | null;
  estimated_effort_days: number;
  payback_priority: number;
  status: "open" | "triaged" | "in_progress" | "paid_off" | "wont_do";
  reported_at: string;
  reported_by: string | null;
  reported_by_email: string | null;
  assigned_to: string | null;
  assigned_to_email: string | null;
  description: string | null;
  mitigation_notes: string | null;
  closed_at: string | null;
  age_days: number;
};

const AREA_LABEL: Record<string, string> = {
  backend_postgres: "Backend · Postgres",
  backend_supabase_fn: "Backend · Supabase fn",
  android: "Android",
  web_console: "Web Console",
  cron: "Cron",
  infra: "Infra",
  data: "Data",
  testing: "Testing",
  docs: "Docs",
  other: "Other",
};

const PAYBACK_LABEL: Record<string, string> = {
  refactor: "Refactor",
  rewrite: "Rewrite",
  test_coverage: "Test coverage",
  perf_optimize: "Perf optimize",
  schema_migration: "Schema migration",
  security_hardening: "Security hardening",
  observability: "Observability",
  dependency_upgrade: "Dependency upgrade",
  documentation: "Documentation",
};

const SEV_TONE: Record<string, string> = {
  high: "text-[var(--color-danger)] border-[var(--color-danger)]",
  medium: "text-[var(--color-warn)] border-[var(--color-warn)]",
  low: "text-[var(--color-muted)] border-[var(--color-border)]",
};

const STATUS_TONE: Record<string, string> = {
  open: "text-[var(--color-danger)]",
  triaged: "text-[var(--color-warn)]",
  in_progress: "text-[var(--color-info)]",
  paid_off: "text-[var(--color-ok)]",
  wont_do: "text-[var(--color-muted)]",
};

const ALLOWED_STATUS = new Set(["open", "triaged", "in_progress", "paid_off", "wont_do", "all"]);

function priorityBand(p: number): { label: string; tone: string } {
  if (p >= 80) return { label: "P0", tone: "text-[var(--color-danger)] border-[var(--color-danger)]" };
  if (p >= 60) return { label: "P1", tone: "text-[var(--color-warn)] border-[var(--color-warn)]" };
  if (p >= 40) return { label: "P2", tone: "text-[var(--color-info)] border-[var(--color-info)]" };
  return { label: "P3", tone: "text-[var(--color-muted)] border-[var(--color-border)]" };
}

export default async function FounderTechDebtLedgerPage({
  searchParams,
}: { searchParams: Promise<{ status?: string }> }) {
  await requireFounder();
  const sp = await searchParams;
  const rawStatus = (sp.status ?? "open").toLowerCase();
  const status = ALLOWED_STATUS.has(rawStatus) ? rawStatus : "open";
  const rpcStatus = status === "all" ? null : status;

  const supabase = await getSupabaseServerClient();
  const [sumRes, recRes] = await Promise.all([
    supabase.rpc("founder_tech_debt_summary"),
    supabase.rpc("founder_tech_debt_recent", { p_status: rpcStatus, p_limit: 100 }),
  ]);
  if (sumRes.error) throw new Error(`founder_tech_debt_summary: ${sumRes.error.message}`);
  if (recRes.error) throw new Error(`founder_tech_debt_recent: ${recRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const items = (recRes.data ?? []) as Item[];

  const filters: { key: string; label: string }[] = [
    { key: "open", label: "Open" },
    { key: "triaged", label: "Triaged" },
    { key: "in_progress", label: "In progress" },
    { key: "paid_off", label: "Paid off" },
    { key: "wont_do", label: "Won't do" },
    { key: "all", label: "All" },
  ];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder tech debt ledger ★★ r1352</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Known debt + payback priority · 10-area taxonomy · 9-kind payback classes · paid_off when retired · sorted priority desc
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
          <div className="rounded-lg border-2 border-[var(--color-accent)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total items</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-accent)]">{formatNumber(s.total_items)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Open</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{formatNumber(s.open_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Triaged</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{formatNumber(s.triaged_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">In progress</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-info)]">{formatNumber(s.in_progress_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Paid off</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.paid_off_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Won't do</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.wont_do_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">High sev open</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{formatNumber(s.high_severity_open)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Medium sev open</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{formatNumber(s.medium_severity_open)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Low sev open</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.low_severity_open)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Effort days open</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.total_estimated_effort_days_open)}</div>
            <div className="text-xs text-[var(--color-muted)]">sum est days</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Oldest open age</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.oldest_open_age_days)}d</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Paid off 30d</div>
            <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{formatNumber(s.paid_off_last_30d)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Top area</div>
            <div className="mt-1 text-base font-semibold truncate" title={s.top_area}>{AREA_LABEL[s.top_area] ?? s.top_area}</div>
            <div className="text-xs text-[var(--color-muted)]">{formatNumber(s.top_area_count)} items</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Top area count</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{formatNumber(s.top_area_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Avg priority open</div>
            <div className="mt-1 text-2xl font-bold tabular-nums">{Number(s.avg_payback_priority_open).toFixed(1)}</div>
            <div className="text-xs text-[var(--color-muted)]">0..100</div>
          </div>
        </section>
      ) : null}

      <section>
        <div className="flex flex-wrap items-center gap-2 mb-3">
          <span className="text-xs uppercase tracking-wider text-[var(--color-muted)] mr-2">Filter</span>
          {filters.map(f => {
            const active = f.key === status;
            return (
              <a
                key={f.key}
                href={`/founder-tech-debt-ledger?status=${f.key}`}
                className={`px-3 py-1 rounded border text-xs ${active
                  ? "border-[var(--color-accent)] text-[var(--color-accent)] bg-[color-mix(in_srgb,var(--color-accent)_10%,transparent)]"
                  : "border-[var(--color-border)] text-[var(--color-muted)] hover:text-[var(--color-fg)]"}`}
              >
                {f.label}
              </a>
            );
          })}
        </div>

        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">
          Ledger · top 100 by payback priority desc · status={status}
        </h2>

        {items.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No items match this filter. Register via <code className="font-mono">log_founder_tech_debt_register()</code>.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-left text-[var(--color-muted)] border-b border-[var(--color-border)]">
                <tr>
                  <th className="py-2 pr-3 text-right">Pri</th>
                  <th className="py-2 pr-3">Sev</th>
                  <th className="py-2 pr-3">Title</th>
                  <th className="py-2 pr-3">Area</th>
                  <th className="py-2 pr-3">Payback kind</th>
                  <th className="py-2 pr-3 text-right">Est d</th>
                  <th className="py-2 pr-3 text-right">Age</th>
                  <th className="py-2 pr-3">Assigned</th>
                  <th className="py-2 pr-3">Status</th>
                </tr>
              </thead>
              <tbody>
                {items.map(it => {
                  const band = priorityBand(it.payback_priority);
                  return (
                    <tr key={it.id} className="border-b border-[var(--color-border)] align-top">
                      <td className="py-2 pr-3 text-right tabular-nums">
                        <span className={`inline-flex items-center gap-1 px-1.5 py-0.5 rounded border text-[10px] uppercase ${band.tone}`}>
                          {band.label} {it.payback_priority}
                        </span>
                      </td>
                      <td className="py-2 pr-3">
                        <span className={`px-1.5 py-0.5 rounded border text-[10px] uppercase ${SEV_TONE[it.severity] ?? ""}`}>{it.severity}</span>
                      </td>
                      <td className="py-2 pr-3 max-w-[300px] truncate font-medium" title={it.title}>{it.title}</td>
                      <td className="py-2 pr-3 text-[var(--color-muted)] whitespace-nowrap">{AREA_LABEL[it.area] ?? it.area}</td>
                      <td className="py-2 pr-3 text-[var(--color-muted)] whitespace-nowrap">{it.payback_kind ? (PAYBACK_LABEL[it.payback_kind] ?? it.payback_kind) : <span className="italic">—</span>}</td>
                      <td className="py-2 pr-3 text-right tabular-nums">{formatNumber(it.estimated_effort_days)}</td>
                      <td className="py-2 pr-3 text-right tabular-nums text-[var(--color-muted)]">{it.age_days}d</td>
                      <td className="py-2 pr-3 text-[var(--color-muted)] max-w-[180px] truncate" title={it.assigned_to_email ?? ""}>
                        {it.assigned_to_email ?? <span className="italic">unassigned</span>}
                      </td>
                      <td className={`py-2 pr-3 uppercase text-[10px] tracking-wider ${STATUS_TONE[it.status] ?? ""}`}>{it.status}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
        <h3 className="text-sm font-semibold text-[var(--color-fg)]">Payback discipline</h3>
        <ul className="list-disc list-inside space-y-1">
          <li>Every known shortcut MUST get registered same-week — undocumented debt compounds silently.</li>
          <li>Priority 0..100: 80+ is P0 (next sprint), 60-79 P1 (this quarter), 40-59 P2 (this year), {"<"}40 P3 (watch).</li>
          <li>Severity = blast radius if it bites. Priority = when we pay it. They are not the same axis.</li>
          <li>Track {">="} 1 paid_off per week; trend in "Paid off 30d" card. Zero closes = we are only accumulating.</li>
          <li>wont_do is honest — close items we have decided to live with, do not leave them open forever.</li>
        </ul>
        <p className="pt-2">Register via <code className="font-mono">log_founder_tech_debt_register()</code> · move status via <code className="font-mono">log_founder_tech_debt_status()</code> · re-prioritize via <code className="font-mono">log_founder_tech_debt_priority()</code>.</p>
      </section>
    </div>
  );
}
