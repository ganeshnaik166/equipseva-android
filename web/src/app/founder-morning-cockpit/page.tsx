import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder morning cockpit — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type PulseRow = { metric: string; this_week: number; last_week: number; delta_pct: number | null; ord: number };

type RatePoint = { window_label: string; pass_pct?: number; collection_pct?: number; release_pct?: number; success_pct?: number; cancel_pct?: number; resolution_pct?: number; fill_pct?: number };

async function tryRpc<T>(supabase: Awaited<ReturnType<typeof getSupabaseServerClient>>, fn: string): Promise<T[]> {
  const { data, error } = await supabase.rpc(fn);
  if (error) return [];
  return (data ?? []) as T[];
}

export default async function FounderMorningCockpitPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [
    pulse,
    fillRate, releaseRate, collectionRate, payoutsSuccess, disputeRes,
    renewalRate, supervisedSuccess, cancelRate, codeRedRes, integritySummary,
  ] = await Promise.all([
    tryRpc<PulseRow>(supabase, "founder_pulse_extended"),
    tryRpc<RatePoint>(supabase, "founder_jobs_fill_rate"),
    tryRpc<RatePoint>(supabase, "founder_escrow_release_rate"),
    tryRpc<RatePoint>(supabase, "founder_amc_payment_collection_rate"),
    tryRpc<RatePoint>(supabase, "founder_payouts_success_rate"),
    tryRpc<RatePoint>(supabase, "founder_dispute_resolution_rate"),
    tryRpc<RatePoint>(supabase, "founder_amc_renewal_rate"),
    tryRpc<RatePoint>(supabase, "founder_supervised_success_rate"),
    tryRpc<RatePoint>(supabase, "founder_jobs_cancellation_rate"),
    tryRpc<RatePoint>(supabase, "founder_code_red_resolution_rate"),
    tryRpc<{ window_label: string; total_checks: number; pass_pct: number; dirty_header: number }>(supabase, "founder_integrity_summary"),
  ]);

  const pulseTop = pulse.slice(0, 8);
  const rateValue = (rows: RatePoint[], key: keyof RatePoint, window = "30d"): string => {
    const r = rows.find((x) => x.window_label === window);
    if (!r) return "—";
    const v = r[key];
    return typeof v === "number" ? `${v}%` : "—";
  };

  const rateCards: { title: string; value: string; href: string }[] = [
    { title: "Jobs fill 30d", value: rateValue(fillRate, "fill_pct"), href: "/jobs-fill-rate" },
    { title: "Escrow release 30d", value: rateValue(releaseRate, "release_pct"), href: "/escrow-release-rate" },
    { title: "AMC collection 30d", value: rateValue(collectionRate, "collection_pct"), href: "/amc-payment-collection-rate" },
    { title: "Payouts success 30d", value: rateValue(payoutsSuccess, "success_pct"), href: "/payouts-success-rate" },
    { title: "Dispute resolution 30d", value: rateValue(disputeRes, "resolution_pct"), href: "/dispute-resolution-rate" },
    { title: "AMC renewal 90d", value: rateValue(renewalRate, "success_pct", "90d"), href: "/amc-renewal-rate" },
    { title: "Supervised success 90d", value: rateValue(supervisedSuccess, "success_pct", "90d"), href: "/supervised-success-rate" },
    { title: "Jobs cancellation 30d", value: rateValue(cancelRate, "cancel_pct"), href: "/jobs-cancellation-rate" },
    { title: "Code Red resolution 30d", value: rateValue(codeRedRes, "resolution_pct"), href: "/code-red-resolution-rate" },
  ];

  const integrity = integritySummary.find((x) => x.window_label === "7d");

  return (
    <div className="space-y-8">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Founder morning cockpit</h1>
        <span className="text-xs text-[var(--color-muted)]">★ r872 / PR #1500 milestone · one-page daily snapshot</span>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          This week vs last week
        </h2>
        <div className="grid grid-cols-2 gap-2 md:grid-cols-4 lg:grid-cols-4">
          {pulseTop.map((p) => {
            const deltaTone = p.delta_pct == null ? "text-[var(--color-muted)]"
              : p.delta_pct > 0 ? "text-[var(--color-ok)]"
              : p.delta_pct < 0 ? "text-[var(--color-danger)]"
              : "text-[var(--color-muted)]";
            return (
              <div key={p.metric} className="rounded border border-[var(--color-border)] bg-white p-3">
                <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">{p.metric}</div>
                <div className="mt-1 text-lg font-semibold tabular-nums">{formatNumber(p.this_week)}</div>
                <div className={`mt-0.5 text-xs tabular-nums ${deltaTone}`}>
                  {p.delta_pct == null ? "n/a" : `${p.delta_pct > 0 ? "+" : ""}${p.delta_pct}% WoW`}
                </div>
              </div>
            );
          })}
        </div>
        <Link href="/pulse-extended" className="mt-2 inline-block text-xs underline text-[var(--color-muted)]">See all 20 KPIs →</Link>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Health rates
        </h2>
        <div className="grid grid-cols-2 gap-2 md:grid-cols-3 lg:grid-cols-3">
          {rateCards.map((r) => (
            <Link
              key={r.title}
              href={r.href}
              className="rounded border border-[var(--color-border)] bg-white p-3 transition-colors hover:border-[var(--color-fg)]"
            >
              <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">{r.title}</div>
              <div className="mt-1 text-2xl font-semibold tabular-nums">{r.value}</div>
            </Link>
          ))}
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Outreach queues (revenue protection)
        </h2>
        <div className="grid grid-cols-1 gap-2 md:grid-cols-2">
          <Link href="/amc-pool-low-balance" className="rounded border border-[var(--color-border)] bg-white p-3 hover:border-[var(--color-fg)]">
            <div className="text-sm font-semibold">AMC pool low balance</div>
            <div className="text-xs text-[var(--color-muted)]">Active AMCs below 2× monthly fee · auto-suspend risk</div>
          </Link>
          <Link href="/engineers-missing-payout" className="rounded border border-[var(--color-border)] bg-white p-3 hover:border-[var(--color-fg)]">
            <div className="text-sm font-semibold">Engineers missing payout method</div>
            <div className="text-xs text-[var(--color-muted)]">Earned 30d but no verified VPA</div>
          </Link>
          <Link href="/amc-near-expiry" className="rounded border border-[var(--color-border)] bg-white p-3 hover:border-[var(--color-fg)]">
            <div className="text-sm font-semibold">AMC expiring &lt;30d</div>
            <div className="text-xs text-[var(--color-muted)]">Renewal nudge target</div>
          </Link>
          <Link href="/unmatched-jobs" className="rounded border border-[var(--color-border)] bg-white p-3 hover:border-[var(--color-fg)]">
            <div className="text-sm font-semibold">Unmatched jobs &gt;7d</div>
            <div className="text-xs text-[var(--color-muted)]">Posted but no bids</div>
          </Link>
          <Link href="/amc-renewal-failures" className="rounded border border-[var(--color-border)] bg-white p-3 hover:border-[var(--color-fg)]">
            <div className="text-sm font-semibold">AMC renewal failures</div>
            <div className="text-xs text-[var(--color-muted)]">3-retry budget exhausted</div>
          </Link>
          <Link href="/chains-amc-gap" className="rounded border border-[var(--color-border)] bg-white p-3 hover:border-[var(--color-fg)]">
            <div className="text-sm font-semibold">Chains AMC gap</div>
            <div className="text-xs text-[var(--color-muted)]">Chain hospitals without AMC · sales upsell</div>
          </Link>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Integrity (7d)
        </h2>
        <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
          <StatCard label="Checks" value={formatNumber(integrity?.total_checks ?? 0)} />
          <StatCard label="Pass %" value={`${integrity?.pass_pct ?? 0}%`} />
          <StatCard label="Dirty header" value={formatNumber(integrity?.dirty_header ?? 0)} />
          <Link href="/security-overview" className="rounded border border-[var(--color-border)] bg-white p-3 hover:border-[var(--color-fg)]">
            <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">Anti-mod stack</div>
            <div className="mt-1 text-sm font-semibold">/security-overview →</div>
            <div className="text-xs text-[var(--color-muted)]">14 layers</div>
          </Link>
        </div>
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>Daily flow:</strong> open this page in the morning. Glance at pulse + rates for surprises, click through any red/warn rate, hit each outreach queue, check integrity row. Done in 2 minutes.
      </section>
    </div>
  );
}
