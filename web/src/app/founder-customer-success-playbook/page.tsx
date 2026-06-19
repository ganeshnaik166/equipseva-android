import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder customer success playbook — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_active_contracts: number | null;
  total_active_steps: number | null;
  runs_due_this_week: number | null;
  runs_due_today: number | null;
  runs_completed_this_month: number | null;
  runs_overdue: number | null;
  runs_overdue_30d: number | null;
  runs_overdue_90d: number | null;
  contracts_with_zero_runs: number | null;
  completion_pct_30d: number | null;
  completion_pct_90d: number | null;
  top_overdue_tier: string | null;
};

type DueRow = {
  run_id: string;
  amc_contract_id: string;
  hospital_name: string;
  amc_tier: string;
  step_kind: string;
  step_title: string;
  due_at: string | null;
  overdue_days: number;
  monthly_fee_rupees: number | null;
};

type StepRow = {
  id: string;
  amc_tier: string;
  step_kind: string;
  step_order: number;
  step_title: string;
  step_description: string | null;
  default_due_days_after_activation: number | null;
  is_active: boolean;
};

function fmtNum(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return formatNumber(Number(n));
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return Number(n).toFixed(1) + "%";
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return "₹" + formatNumber(Math.round(Number(n)));
}

function fmtDate(d: string | null): string {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata", year: "numeric", month: "short", day: "2-digit" });
}

function tierTone(tier: string): string {
  if (tier === "enterprise") return "text-[var(--color-ok)]";
  if (tier === "growth") return "text-[var(--color-accent)]";
  return "text-[var(--color-muted)]";
}

export default async function FounderCustomerSuccessPlaybookPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, dueRes, stepsRes] = await Promise.all([
    supabase.rpc("founder_cs_playbook_summary"),
    supabase.rpc("founder_cs_playbook_runs_due", { p_limit: 50 }),
    supabase
      .from("founder_cs_playbook_steps")
      .select("id, amc_tier, step_kind, step_order, step_title, step_description, default_due_days_after_activation, is_active")
      .eq("is_active", true)
      .order("amc_tier", { ascending: true })
      .order("step_order", { ascending: true }),
  ]);
  if (sumRes.error) throw new Error(`founder_cs_playbook_summary: ${sumRes.error.message}`);
  if (dueRes.error) throw new Error(`founder_cs_playbook_runs_due: ${dueRes.error.message}`);
  if (stepsRes.error) throw new Error(`founder_cs_playbook_steps: ${stepsRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const due = (dueRes.data ?? []) as DueRow[];
  const steps = (stepsRes.data ?? []) as StepRow[];

  const tiers: Array<"starter" | "growth" | "enterprise"> = ["starter", "growth", "enterprise"];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder customer success playbook ★★★ r1344</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Per-AMC-tier playbook steps · seeded on activation · overdue runs gate renewal · top overdue tier surfaces where to staff up CS.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Active contracts</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{fmtNum(s?.total_active_contracts ?? 0)}</div>
          <div className="text-xs text-[var(--color-muted)]">status = active</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Active steps</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{fmtNum(s?.total_active_steps ?? 0)}</div>
          <div className="text-xs text-[var(--color-muted)]">template catalog</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Due this week</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{fmtNum(s?.runs_due_this_week ?? 0)}</div>
          <div className="text-xs text-[var(--color-muted)]">next 7d window</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Due today</div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{fmtNum(s?.runs_due_today ?? 0)}</div>
          <div className="text-xs text-[var(--color-muted)]">action today</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Completed this month</div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{fmtNum(s?.runs_completed_this_month ?? 0)}</div>
          <div className="text-xs text-[var(--color-muted)]">since month start</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Overdue (all)</div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{fmtNum(s?.runs_overdue ?? 0)}</div>
          <div className="text-xs text-[var(--color-muted)]">due_at {"<"} today</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Overdue 30d+</div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{fmtNum(s?.runs_overdue_30d ?? 0)}</div>
          <div className="text-xs text-[var(--color-muted)]">stale 30d+</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Overdue 90d+</div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{fmtNum(s?.runs_overdue_90d ?? 0)}</div>
          <div className="text-xs text-[var(--color-muted)]">renewal risk</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Contracts w/ zero runs</div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{fmtNum(s?.contracts_with_zero_runs ?? 0)}</div>
          <div className="text-xs text-[var(--color-muted)]">never seeded</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Completion % 30d</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{fmtPct(s?.completion_pct_30d)}</div>
          <div className="text-xs text-[var(--color-muted)]">target ≥ 80%</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Completion % 90d</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{fmtPct(s?.completion_pct_90d)}</div>
          <div className="text-xs text-[var(--color-muted)]">trailing quarter</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Top overdue tier</div>
          <div className={`mt-1 text-2xl font-bold uppercase ${tierTone(s?.top_overdue_tier ?? "")}`}>{s?.top_overdue_tier ?? "—"}</div>
          <div className="text-xs text-[var(--color-muted)]">staff up here</div>
        </div>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Top 50 due/overdue runs</h2>
        {due.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No due or overdue runs.</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
            <table className="min-w-full text-xs">
              <thead className="bg-[var(--color-surface-2)]">
                <tr className="text-left text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="px-3 py-2 font-medium">Hospital</th>
                  <th className="px-3 py-2 font-medium">Tier</th>
                  <th className="px-3 py-2 font-medium">Step</th>
                  <th className="px-3 py-2 font-medium">Kind</th>
                  <th className="px-3 py-2 font-medium">Due</th>
                  <th className="px-3 py-2 font-medium text-right">Overdue (d)</th>
                  <th className="px-3 py-2 font-medium text-right">Fee/mo</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--color-border)]">
                {due.map((r) => {
                  const overdue = r.overdue_days > 0;
                  const dueToday = r.overdue_days === 0;
                  const rowCls = overdue
                    ? "bg-[color:color-mix(in_srgb,var(--color-danger)_12%,transparent)]"
                    : dueToday
                    ? "bg-[color:color-mix(in_srgb,var(--color-warn)_12%,transparent)]"
                    : "";
                  return (
                    <tr key={r.run_id} className={`hover:bg-[var(--color-surface-2)] ${rowCls}`}>
                      <td className="px-3 py-2 font-semibold">{r.hospital_name}</td>
                      <td className={`px-3 py-2 uppercase font-mono ${tierTone(r.amc_tier)}`}>{r.amc_tier}</td>
                      <td className="px-3 py-2">{r.step_title}</td>
                      <td className="px-3 py-2 font-mono text-[var(--color-muted)]">{r.step_kind}</td>
                      <td className="px-3 py-2 font-mono">{fmtDate(r.due_at)}</td>
                      <td className="px-3 py-2 text-right tabular-nums font-bold">{r.overdue_days > 0 ? r.overdue_days : "—"}</td>
                      <td className="px-3 py-2 text-right tabular-nums">{fmtRupees(r.monthly_fee_rupees)}</td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Playbook steps catalog (by tier)</h2>
        <div className="grid gap-4 lg:grid-cols-3">
          {tiers.map((tier) => {
            const rows = steps.filter((x) => x.amc_tier === tier);
            return (
              <div key={tier} className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] overflow-hidden">
                <div className={`px-3 py-2 text-xs font-semibold uppercase tracking-wider bg-[var(--color-surface-2)] ${tierTone(tier)}`}>
                  {tier} · {rows.length} steps
                </div>
                <table className="min-w-full text-xs">
                  <thead className="bg-[var(--color-surface-2)]">
                    <tr className="text-left text-[var(--color-muted)] uppercase tracking-wider">
                      <th className="px-2 py-1 font-medium">#</th>
                      <th className="px-2 py-1 font-medium">Title</th>
                      <th className="px-2 py-1 font-medium text-right">Day</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-[var(--color-border)]">
                    {rows.map((r) => (
                      <tr key={r.id} className="hover:bg-[var(--color-surface-2)]">
                        <td className="px-2 py-1 font-mono tabular-nums">{r.step_order}</td>
                        <td className="px-2 py-1">
                          <div className="font-semibold">{r.step_title}</div>
                          <div className="text-[10px] text-[var(--color-muted)] font-mono">{r.step_kind}</div>
                        </td>
                        <td className="px-2 py-1 text-right tabular-nums">+{r.default_due_days_after_activation ?? 0}d</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            );
          })}
        </div>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
        <p><strong className="text-[var(--color-text)]">Seeding workflow:</strong> After a new AMC contract activates, call <code>log_founder_cs_playbook_seed_for_contract(contract_id)</code>. It looks up the contract's <code>amc_tier</code> and creates one run row per active step, due_at = <code>activated_at + default_due_days_after_activation</code>. The unique <code>(amc_contract_id, step_id)</code> guard makes this idempotent.</p>
        <p><strong className="text-[var(--color-text)]">Completion cadence:</strong> CS or founder calls <code>log_founder_cs_playbook_complete_run(run_id, outcome_note)</code> after each step. Target completion ≥ 80% on the 30d window. Anything overdue 90d+ is a renewal-risk red flag — pull into a churn-risk save play immediately.</p>
        <p><strong className="text-[var(--color-text)]">Tier escalation:</strong> Enterprise gets 8 touches/year (1 onsite/quarter + custom SLA report). Growth gets 6 (semi-annual deep-dive). Starter gets 5 (just monthly checkins + quarterly). Top overdue tier above tells you where CS staffing is under-water.</p>
      </section>
    </div>
  );
}
