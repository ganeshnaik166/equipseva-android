import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";
import {
  dryRunPayroll,
  createDraftBatch,
  authorizeBatch,
  setBatchStatus,
} from "./actions";

export const metadata = { title: "Founder payroll bulk authorize — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type DryRow = {
  candidate_payout_count: number;
  total_amount_rupees: number;
  engineer_count: number;
  median_payout_rupees: number;
  largest_payout_rupees: number;
  smallest_payout_rupees: number;
  payouts_blocked_missing_kyc: number;
  payouts_blocked_missing_upi_or_bank: number;
  payouts_blocked_disputed: number;
  payouts_ok_to_authorize: number;
  sample_top_5_amounts: { payout_id: string; amount_rupees: number }[] | null;
};

type BatchRow = {
  id: string;
  batch_label: string;
  period_start: string;
  period_end: string;
  total_payouts_count: number;
  total_amount_rupees: number;
  status: string;
  authorized_at: string | null;
  completed_at: string | null;
  created_at: string;
};

const STATUS_TONE: Record<string, string> = {
  draft:                  "text-[var(--color-muted)]",
  authorized:             "text-[var(--color-info)]",
  submitted_to_cashfree:  "text-[var(--color-info)]",
  partial_complete:       "text-[var(--color-warn)]",
  complete:               "text-[var(--color-ok)]",
  reverted:               "text-[var(--color-danger)]",
};

function isoFirstOfMonth(): string {
  const d = new Date();
  return new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), 1)).toISOString().slice(0, 10);
}
function isoToday(): string {
  return new Date().toISOString().slice(0, 10);
}

export default async function FounderPayrollBulkAuthorizePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const p_start = isoFirstOfMonth();
  const p_end   = isoToday();

  const [dryRes, batchesRes] = await Promise.all([
    supabase.rpc("founder_payroll_batch_dryrun", { p_period_start: p_start, p_period_end: p_end }),
    supabase.rpc("founder_payroll_batches_recent", { p_limit: 20 }),
  ]);
  if (dryRes.error)     throw new Error(`founder_payroll_batch_dryrun: ${dryRes.error.message}`);
  if (batchesRes.error) throw new Error(`founder_payroll_batches_recent: ${batchesRes.error.message}`);

  const d = (dryRes.data?.[0] ?? null) as DryRow | null;
  const batches = (batchesRes.data ?? []) as BatchRow[];

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Founder payroll bulk authorize ★ r1325</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Dry-run reconciliation for the current month, then materialize a draft batch and bulk-authorize.
          Cashfree integration is gated on KYC activation; until then, authorized batches stay in
          {" "}<span className="text-[var(--color-info)]">authorized</span>{" "}
          state and the existing per-payout cron consumes them.
        </p>
        <p className="text-[10px] text-[var(--color-muted)] mt-1">Period shown: {p_start} → {p_end} (IST)</p>
      </header>

      {d ? (
        <section className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Candidate payouts</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(d.candidate_payout_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Total amount (rupees)</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(d.total_amount_rupees)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Distinct engineers</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(d.engineer_count)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-ok)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">OK to authorize</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-ok)]">{formatNumber(d.payouts_ok_to_authorize)}</div>
          </div>

          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Median payout (rupees)</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(d.median_payout_rupees)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Largest payout (rupees)</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(d.largest_payout_rupees)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Smallest payout (rupees)</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums">{formatNumber(d.smallest_payout_rupees)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-warn)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Blocked: KYC missing</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-warn)]">{formatNumber(d.payouts_blocked_missing_kyc)}</div>
          </div>

          <div className="rounded-lg border border-[var(--color-warn)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Blocked: UPI/bank missing</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-warn)]">{formatNumber(d.payouts_blocked_missing_upi_or_bank)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-danger)] bg-[var(--color-surface)] p-4">
            <div className="text-xs text-[var(--color-muted)]">Blocked: disputed job</div>
            <div className="mt-1 text-2xl font-semibold tabular-nums text-[var(--color-danger)]">{formatNumber(d.payouts_blocked_disputed)}</div>
          </div>
          <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 sm:col-span-2">
            <div className="text-xs text-[var(--color-muted)]">Top 5 amounts in window</div>
            <ul className="mt-2 space-y-1 text-xs">
              {(d.sample_top_5_amounts ?? []).map((s) => (
                <li key={s.payout_id} className="flex justify-between font-mono tabular-nums">
                  <span className="truncate text-[var(--color-muted)]">{s.payout_id.slice(0, 8)}…</span>
                  <span>{formatNumber(s.amount_rupees)}</span>
                </li>
              ))}
              {(!d.sample_top_5_amounts || d.sample_top_5_amounts.length === 0) ? (
                <li className="text-[var(--color-muted)]">No queued payouts in window</li>
              ) : null}
            </ul>
          </div>
        </section>
      ) : (
        <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-sm text-[var(--color-muted)]">
          No dry-run data.
        </section>
      )}

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <h2 className="text-sm font-semibold">Run dry-run for a different window</h2>
        <form action={dryRunPayroll} className="mt-3 flex flex-wrap items-end gap-3">
          <label className="flex flex-col text-xs text-[var(--color-muted)]">
            Period start
            <input name="period_start" type="date" defaultValue={p_start} required
              className="mt-1 rounded border border-[var(--color-border)] bg-transparent px-2 py-1 text-sm" />
          </label>
          <label className="flex flex-col text-xs text-[var(--color-muted)]">
            Period end
            <input name="period_end" type="date" defaultValue={p_end} required
              className="mt-1 rounded border border-[var(--color-border)] bg-transparent px-2 py-1 text-sm" />
          </label>
          <button type="submit"
            className="rounded border border-[var(--color-info)] px-3 py-1 text-xs text-[var(--color-info)]">
            Dry run
          </button>
        </form>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <h2 className="text-sm font-semibold">Create a draft batch</h2>
        <p className="mt-1 text-xs text-[var(--color-muted)]">
          Materializes the candidate payout list into founder_payroll_batches as status=draft. No money moves yet.
        </p>
        <form action={createDraftBatch} className="mt-3 flex flex-wrap items-end gap-3">
          <label className="flex flex-col text-xs text-[var(--color-muted)]">
            Period start
            <input name="period_start" type="date" defaultValue={p_start} required
              className="mt-1 rounded border border-[var(--color-border)] bg-transparent px-2 py-1 text-sm" />
          </label>
          <label className="flex flex-col text-xs text-[var(--color-muted)]">
            Period end
            <input name="period_end" type="date" defaultValue={p_end} required
              className="mt-1 rounded border border-[var(--color-border)] bg-transparent px-2 py-1 text-sm" />
          </label>
          <button type="submit"
            className="rounded border border-[var(--color-accent)] px-3 py-1 text-xs text-[var(--color-accent)]">
            Create draft batch
          </button>
        </form>
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
        <h2 className="text-sm font-semibold">Recent batches</h2>
        <div className="mt-3 overflow-x-auto">
          <table className="min-w-full text-xs">
            <thead>
              <tr className="text-left text-[var(--color-muted)]">
                <th className="px-2 py-1">Label</th>
                <th className="px-2 py-1">Period</th>
                <th className="px-2 py-1 text-right">Payouts</th>
                <th className="px-2 py-1 text-right">Amount</th>
                <th className="px-2 py-1">Status</th>
                <th className="px-2 py-1">Created</th>
                <th className="px-2 py-1">Actions</th>
              </tr>
            </thead>
            <tbody>
              {batches.length === 0 ? (
                <tr><td colSpan={7} className="px-2 py-3 text-[var(--color-muted)]">No batches yet.</td></tr>
              ) : batches.map((b) => (
                <tr key={b.id} className="border-t border-[var(--color-border)]">
                  <td className="px-2 py-1 font-mono">{b.batch_label}</td>
                  <td className="px-2 py-1 text-[var(--color-muted)]">{b.period_start} → {b.period_end}</td>
                  <td className="px-2 py-1 text-right tabular-nums">{formatNumber(b.total_payouts_count)}</td>
                  <td className="px-2 py-1 text-right tabular-nums">{formatNumber(b.total_amount_rupees)}</td>
                  <td className={`px-2 py-1 ${STATUS_TONE[b.status] ?? ""}`}>{b.status}</td>
                  <td className="px-2 py-1 text-[var(--color-muted)]">{new Date(b.created_at).toLocaleString("en-IN")}</td>
                  <td className="px-2 py-1">
                    {b.status === "draft" ? (
                      <form action={authorizeBatch}>
                        <input type="hidden" name="batch_id" value={b.id} />
                        <button type="submit"
                          className="rounded border border-[var(--color-ok)] px-2 py-0.5 text-[var(--color-ok)]">
                          Authorize
                        </button>
                      </form>
                    ) : b.status === "authorized" ? (
                      <form action={setBatchStatus}>
                        <input type="hidden" name="batch_id" value={b.id} />
                        <input type="hidden" name="new_status" value="reverted" />
                        <button type="submit"
                          className="rounded border border-[var(--color-danger)] px-2 py-0.5 text-[var(--color-danger)]">
                          Revert
                        </button>
                      </form>
                    ) : <span className="text-[var(--color-muted)]">—</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}

