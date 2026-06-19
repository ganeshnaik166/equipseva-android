import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder cap-table snapshot — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_shares: number | null;
  founders_pct: number | null;
  employees_pct: number | null;
  angels_pct: number | null;
  vcs_pct: number | null;
  esop_pool_pct: number | null;
  available_esop_pct: number | null;
  total_raised_rupees: number | null;
  latest_round_label: string | null;
  latest_post_money_rupees: number | null;
  fully_diluted_shares: number | null;
};

type Shareholder = {
  id: string;
  shareholder_name: string;
  shareholder_kind: string;
  shares_count: number;
  ownership_pct: number;
  investment_amount_rupees: number;
  vested_pct: number;
  cliff_months: number;
  vesting_total_months: number;
  granted_at: string | null;
  notes: string | null;
};

type Round = {
  id: string;
  round_label: string;
  round_kind: string;
  pre_money_valuation_rupees: number;
  raise_amount_rupees: number;
  post_money_rupees: number;
  dilution_pct: number;
  closed_at: string | null;
  notes: string | null;
};

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!isFinite(v)) return "—";
  return "₹" + formatNumber(Math.round(v));
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  const v = Number(n);
  if (!isFinite(v)) return "—";
  return v.toFixed(2) + "%";
}

function fmtShares(n: number | null | undefined): string {
  if (n === null || n === undefined) return "—";
  return formatNumber(Number(n));
}

function fmtDate(d: string | null): string {
  if (!d) return "—";
  return new Date(d).toLocaleDateString("en-IN", { timeZone: "Asia/Kolkata", year: "numeric", month: "short", day: "2-digit" });
}

function kindTone(kind: string): string {
  switch (kind) {
    case "founder":   return "text-[var(--color-ok)]";
    case "employee":  return "text-[var(--color-info)]";
    case "angel":     return "text-[var(--color-warn)]";
    case "vc":        return "text-[var(--color-danger)]";
    case "strategic": return "text-[var(--color-danger)]";
    case "esop_pool": return "text-[var(--color-muted)]";
    default:          return "text-[var(--color-text)]";
  }
}

function esopTone(pct: number | null): string {
  if (pct === null || pct === undefined) return "text-[var(--color-muted)]";
  if (pct < 2)  return "text-[var(--color-danger)]";
  if (pct < 5)  return "text-[var(--color-warn)]";
  return "text-[var(--color-ok)]";
}

function barWidth(pct: number | null | undefined): string {
  const v = Math.max(0, Math.min(100, Number(pct ?? 0)));
  return v.toFixed(2) + "%";
}

export default async function FounderCapTableSnapshotPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, holdersRes, roundsRes] = await Promise.all([
    supabase.rpc("founder_cap_table_summary"),
    supabase.rpc("founder_cap_table_shareholders_recent", { p_limit: 50 }),
    supabase.rpc("founder_cap_table_rounds_recent", { p_limit: 10 }),
  ]);
  if (sumRes.error)     throw new Error(`founder_cap_table_summary: ${sumRes.error.message}`);
  if (holdersRes.error) throw new Error(`founder_cap_table_shareholders_recent: ${holdersRes.error.message}`);
  if (roundsRes.error)  throw new Error(`founder_cap_table_rounds_recent: ${roundsRes.error.message}`);

  const s = (sumRes.data?.[0] ?? null) as Summary | null;
  const holders = (holdersRes.data ?? []) as Shareholder[];
  const rounds = (roundsRes.data ?? []) as Round[];

  const ownership = [
    { kind: "Founders",      pct: s?.founders_pct ?? 0,       tone: "bg-[var(--color-ok)]" },
    { kind: "Employees",     pct: s?.employees_pct ?? 0,      tone: "bg-[var(--color-info)]" },
    { kind: "Angels",        pct: s?.angels_pct ?? 0,         tone: "bg-[var(--color-warn)]" },
    { kind: "VCs/Strategic", pct: s?.vcs_pct ?? 0,            tone: "bg-[var(--color-danger)]" },
    { kind: "ESOP pool",     pct: s?.esop_pool_pct ?? 0,      tone: "bg-[var(--color-muted)]" },
  ];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder cap-table snapshot ★★ r1335</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Equity dilution model + cap-table tracker · ownership-by-kind breakdown · rounds history · ESOP pool headroom · post-money valuation
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Total shares</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{fmtShares(s?.total_shares ?? 0)}</div>
          <div className="text-xs text-[var(--color-muted)]">issued + pool</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Fully diluted shares</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{fmtShares(s?.fully_diluted_shares ?? 0)}</div>
          <div className="text-xs text-[var(--color-muted)]">incl. un-granted pool</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Founders %</div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{fmtPct(s?.founders_pct)}</div>
          <div className="text-xs text-[var(--color-muted)]">control band</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Employees %</div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-info)]">{fmtPct(s?.employees_pct)}</div>
          <div className="text-xs text-[var(--color-muted)]">vested + granted</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Angels %</div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-warn)]">{fmtPct(s?.angels_pct)}</div>
          <div className="text-xs text-[var(--color-muted)]">individual investors</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">VCs/Strategic %</div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-danger)]">{fmtPct(s?.vcs_pct)}</div>
          <div className="text-xs text-[var(--color-muted)]">institutional holders</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">ESOP pool %</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{fmtPct(s?.esop_pool_pct)}</div>
          <div className="text-xs text-[var(--color-muted)]">authorised pool</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Available ESOP %</div>
          <div className={`mt-1 text-2xl font-bold tabular-nums ${esopTone(s?.available_esop_pct ?? null)}`}>{fmtPct(s?.available_esop_pct)}</div>
          <div className="text-xs text-[var(--color-muted)]">hireable headroom</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Total raised</div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{fmtRupees(s?.total_raised_rupees)}</div>
          <div className="text-xs text-[var(--color-muted)]">cumulative across rounds</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Latest round</div>
          <div className="mt-1 text-2xl font-bold tabular-nums">{s?.latest_round_label ?? "—"}</div>
          <div className="text-xs text-[var(--color-muted)]">most recent close</div>
        </div>
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
          <div className="text-xs text-[var(--color-muted)]">Latest post-money</div>
          <div className="mt-1 text-2xl font-bold tabular-nums text-[var(--color-ok)]">{fmtRupees(s?.latest_post_money_rupees)}</div>
          <div className="text-xs text-[var(--color-muted)]">pre-money + raise</div>
        </div>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6">
        <h2 className="text-sm font-semibold mb-4 uppercase tracking-wider text-[var(--color-muted)]">Ownership by kind</h2>
        <div className="space-y-3">
          {ownership.map((o) => (
            <div key={o.kind}>
              <div className="flex justify-between text-xs">
                <span className="font-medium">{o.kind}</span>
                <span className="tabular-nums text-[var(--color-muted)]">{fmtPct(o.pct)}</span>
              </div>
              <div className="mt-1 h-3 w-full rounded bg-[var(--color-surface-2)] overflow-hidden">
                <div className={`h-full ${o.tone}`} style={{ width: barWidth(o.pct) }} />
              </div>
            </div>
          ))}
        </div>
        <p className="mt-4 text-xs text-[var(--color-muted)]">
          Bars normalized to fully-diluted share count. Sum may slightly exceed 100% rounding (each value rounded to 2dp).
        </p>
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Shareholders (top 50)</h2>
        {holders.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No shareholders registered yet — call <code>log_founder_cap_table_register_shareholder</code>.</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
            <table className="min-w-full text-xs">
              <thead className="bg-[var(--color-surface-2)]">
                <tr className="text-left text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="px-3 py-2 font-medium">Name</th>
                  <th className="px-3 py-2 font-medium">Kind</th>
                  <th className="px-3 py-2 font-medium text-right">Shares</th>
                  <th className="px-3 py-2 font-medium text-right">Owner %</th>
                  <th className="px-3 py-2 font-medium text-right">Invested</th>
                  <th className="px-3 py-2 font-medium text-right">Vested %</th>
                  <th className="px-3 py-2 font-medium text-right">Cliff</th>
                  <th className="px-3 py-2 font-medium text-right">Total mo</th>
                  <th className="px-3 py-2 font-medium">Granted</th>
                  <th className="px-3 py-2 font-medium">Notes</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--color-border)]">
                {holders.map((h) => (
                  <tr key={h.id} className="hover:bg-[var(--color-surface-2)]">
                    <td className="px-3 py-2 font-medium">{h.shareholder_name}</td>
                    <td className={`px-3 py-2 uppercase tracking-wider text-xs ${kindTone(h.shareholder_kind)}`}>{h.shareholder_kind}</td>
                    <td className="px-3 py-2 text-right tabular-nums font-semibold">{fmtShares(h.shares_count)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{fmtPct(h.ownership_pct)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{fmtRupees(h.investment_amount_rupees)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{fmtPct(h.vested_pct)}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{h.cliff_months}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{h.vesting_total_months}</td>
                    <td className="px-3 py-2 font-mono text-[var(--color-muted)]">{fmtDate(h.granted_at)}</td>
                    <td className="px-3 py-2 text-[var(--color-muted)] italic">{h.notes ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section>
        <h2 className="text-sm font-semibold mb-3 uppercase tracking-wider text-[var(--color-muted)]">Rounds history (last 10)</h2>
        {rounds.length === 0 ? (
          <p className="text-sm text-[var(--color-muted)]">No rounds registered yet — call <code>log_founder_cap_table_register_round</code>.</p>
        ) : (
          <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
            <table className="min-w-full text-xs">
              <thead className="bg-[var(--color-surface-2)]">
                <tr className="text-left text-[var(--color-muted)] uppercase tracking-wider">
                  <th className="px-3 py-2 font-medium">Label</th>
                  <th className="px-3 py-2 font-medium">Kind</th>
                  <th className="px-3 py-2 font-medium text-right">Pre-money</th>
                  <th className="px-3 py-2 font-medium text-right">Raise</th>
                  <th className="px-3 py-2 font-medium text-right">Post-money</th>
                  <th className="px-3 py-2 font-medium text-right">Dilution %</th>
                  <th className="px-3 py-2 font-medium">Closed</th>
                  <th className="px-3 py-2 font-medium">Notes</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-[var(--color-border)]">
                {rounds.map((r) => (
                  <tr key={r.id} className="hover:bg-[var(--color-surface-2)]">
                    <td className="px-3 py-2 font-medium">{r.round_label}</td>
                    <td className="px-3 py-2 uppercase tracking-wider text-xs text-[var(--color-info)]">{r.round_kind}</td>
                    <td className="px-3 py-2 text-right tabular-nums">{fmtRupees(r.pre_money_valuation_rupees)}</td>
                    <td className="px-3 py-2 text-right tabular-nums text-[var(--color-ok)]">{fmtRupees(r.raise_amount_rupees)}</td>
                    <td className="px-3 py-2 text-right tabular-nums font-semibold">{fmtRupees(r.post_money_rupees)}</td>
                    <td className="px-3 py-2 text-right tabular-nums text-[var(--color-warn)]">{fmtPct(r.dilution_pct)}</td>
                    <td className="px-3 py-2 font-mono text-[var(--color-muted)]">{fmtDate(r.closed_at)}</td>
                    <td className="px-3 py-2 text-[var(--color-muted)] italic">{r.notes ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] space-y-2">
        <p><strong className="text-[var(--color-text)]">Schema:</strong> <code>founder_cap_table_shareholders</code> (one row per beneficial owner, UNIQUE on shareholder_name) + <code>founder_cap_table_rounds</code> (one row per priced round / convertible, UNIQUE on round_label).</p>
        <p><strong className="text-[var(--color-text)]">Ownership math:</strong> ownership_pct = shares_count / SUM(shares_count) including esop_pool row. ESOP pool row holds un-granted headroom → available_esop_pct = esop_pool_pct.</p>
        <p><strong className="text-[var(--color-text)]">Round math:</strong> post_money = pre_money + raise · dilution_pct = raise / post_money. Sequenced by closed_at DESC NULLS LAST.</p>
        <p><strong className="text-[var(--color-text)]">Write API:</strong> <code>log_founder_cap_table_register_shareholder</code> (upserts on name) · <code>log_founder_cap_table_register_round</code> (upserts on label). Multi-grant founders/employees aggregate offline before insert.</p>
        <p><strong className="text-[var(--color-text)]">ESOP thresholds:</strong> {"<"}2% danger (hire freeze) · {"<"}5% warn (plan top-up) · {">="}5% healthy.</p>
        <p><strong className="text-[var(--color-text)]">Vesting:</strong> vested_pct is descriptive — founder re-stamps quarterly. cliff_months + vesting_total_months captured for board reporting only.</p>
      </section>
    </div>
  );
}
