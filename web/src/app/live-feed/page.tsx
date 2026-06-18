import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Live feed — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type JobRow = { id: string; hospital_name: string; status: string; contract_amount: number; created_at: string };
type PayoutRow = { payout_id: string; engineer_name: string; amount_rupees: number; status: string; queued_at: string };
type AmcCreditRow = { id: string; hospital_name: string; amount_rupees: number; created_at: string };
type DisputeRow = { id: string; submitter_name: string; status: string; submitted_at: string | null };
type CodeRedRow = { id: string; hospital_name: string; equipment_type: string; status: string; created_at: string };

async function tryRpc<T>(supabase: Awaited<ReturnType<typeof getSupabaseServerClient>>, fn: string): Promise<T[]> {
  const { data, error } = await supabase.rpc(fn);
  if (error) return [];
  return (data ?? []) as T[];
}

export default async function LiveFeedPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [jobs, payouts, credits, disputes, codeRed] = await Promise.all([
    tryRpc<JobRow>(supabase, "founder_repair_jobs_recent"),
    tryRpc<PayoutRow>(supabase, "founder_payouts_recent_list"),
    tryRpc<AmcCreditRow>(supabase, "founder_amc_pool_credits_recent"),
    tryRpc<DisputeRow>(supabase, "founder_disputes_recent"),
    tryRpc<CodeRedRow>(supabase, "founder_code_red_recent_v2"),
  ]);

  const fmt = (s: string | null) => s ? new Date(s).toLocaleString() : "—";

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Live feed ★</h1>
        <span className="text-xs text-[var(--color-muted)]">r950 milestone · raw activity stream across 5 surfaces</span>
      </header>

      <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
        {/* Repair jobs */}
        <section className="rounded border border-[var(--color-border)] bg-white p-3">
          <div className="flex items-baseline justify-between mb-2">
            <h2 className="text-sm font-semibold">Repair jobs (last 10)</h2>
            <Link href="/repair-jobs-recent" className="text-xs underline text-[var(--color-muted)]">all →</Link>
          </div>
          <ul className="space-y-1.5 text-xs">
            {jobs.slice(0, 10).map((r) => (
              <li key={r.id} className="flex justify-between gap-2 border-b border-[var(--color-border)] pb-1">
                <span className="truncate">{r.hospital_name}</span>
                <span className="tabular-nums text-[var(--color-muted)]">{r.status} · ₹{formatNumber(r.contract_amount)}</span>
              </li>
            ))}
            {jobs.length === 0 && <li className="text-[var(--color-muted)]">No jobs.</li>}
          </ul>
        </section>

        {/* Payouts */}
        <section className="rounded border border-[var(--color-border)] bg-white p-3">
          <div className="flex items-baseline justify-between mb-2">
            <h2 className="text-sm font-semibold">Payouts (last 10)</h2>
            <Link href="/payouts-recent-list" className="text-xs underline text-[var(--color-muted)]">all →</Link>
          </div>
          <ul className="space-y-1.5 text-xs">
            {payouts.slice(0, 10).map((r) => (
              <li key={r.payout_id} className="flex justify-between gap-2 border-b border-[var(--color-border)] pb-1">
                <span className="truncate">{r.engineer_name}</span>
                <span className="tabular-nums text-[var(--color-muted)]">{r.status} · ₹{formatNumber(r.amount_rupees)}</span>
              </li>
            ))}
            {payouts.length === 0 && <li className="text-[var(--color-muted)]">No payouts.</li>}
          </ul>
        </section>

        {/* AMC pool credits */}
        <section className="rounded border border-[var(--color-border)] bg-white p-3">
          <div className="flex items-baseline justify-between mb-2">
            <h2 className="text-sm font-semibold">AMC pool credits (last 10)</h2>
            <Link href="/amc-pool-credits-recent" className="text-xs underline text-[var(--color-muted)]">all →</Link>
          </div>
          <ul className="space-y-1.5 text-xs">
            {credits.slice(0, 10).map((r) => (
              <li key={r.id} className="flex justify-between gap-2 border-b border-[var(--color-border)] pb-1">
                <span className="truncate">{r.hospital_name}</span>
                <span className="tabular-nums text-[var(--color-ok)]">+₹{formatNumber(r.amount_rupees)}</span>
              </li>
            ))}
            {credits.length === 0 && <li className="text-[var(--color-muted)]">No pool credits.</li>}
          </ul>
        </section>

        {/* Disputes */}
        <section className="rounded border border-[var(--color-border)] bg-white p-3">
          <div className="flex items-baseline justify-between mb-2">
            <h2 className="text-sm font-semibold">Disputes (last 10)</h2>
            <Link href="/disputes-recent" className="text-xs underline text-[var(--color-muted)]">all →</Link>
          </div>
          <ul className="space-y-1.5 text-xs">
            {disputes.slice(0, 10).map((r) => (
              <li key={r.id} className="flex justify-between gap-2 border-b border-[var(--color-border)] pb-1">
                <span className="truncate">{r.submitter_name}</span>
                <span className="tabular-nums text-[var(--color-muted)]">{r.status} · {fmt(r.submitted_at)}</span>
              </li>
            ))}
            {disputes.length === 0 && <li className="text-[var(--color-muted)]">No disputes.</li>}
          </ul>
        </section>

        {/* Code Red */}
        <section className="rounded border border-[var(--color-border)] bg-white p-3 md:col-span-2">
          <div className="flex items-baseline justify-between mb-2">
            <h2 className="text-sm font-semibold">Code Red (last 10)</h2>
            <Link href="/code-red-recent-list" className="text-xs underline text-[var(--color-muted)]">all →</Link>
          </div>
          <ul className="space-y-1.5 text-xs">
            {codeRed.slice(0, 10).map((r) => (
              <li key={r.id} className="flex justify-between gap-2 border-b border-[var(--color-border)] pb-1">
                <span className="truncate">{r.hospital_name} · <span className="text-[var(--color-muted)]">{r.equipment_type}</span></span>
                <span className="tabular-nums text-[var(--color-muted)]">{r.status} · {fmt(r.created_at)}</span>
              </li>
            ))}
            {codeRed.length === 0 && <li className="text-[var(--color-muted)]">No emergencies.</li>}
          </ul>
        </section>
      </div>

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Why this page.</strong> r872 /founder-morning-cockpit gives KPI-level summaries; r925 /state-overview gives geo-level aggregates. This page is the opposite — the RAW recent-events stream across 5 of the highest-signal surfaces. Use to spot real-time anomalies (someone disputing, AMC pool drained, big payout failing) before they hit the daily aggregates.
      </section>
    </div>
  );
}
