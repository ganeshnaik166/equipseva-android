import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Founder runbook — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Item = { href: string; title: string; why: string };
type Section = { cadence: string; intent: string; items: Item[] };

const SECTIONS: Section[] = [
  {
    cadence: "Daily (5 minutes, IST morning)",
    intent: "Spot what changed overnight + handle action queues.",
    items: [
      { href: "/platform-pulse",  title: "Platform pulse",         why: "12 KPIs at a glance. Tone-coded tiles flag attention." },
      { href: "/at-risk-revenue", title: "At-risk revenue",        why: "6 leak categories rolled up · MRR + counts you can act on." },
      { href: "/pulse-extended",  title: "Pulse extended",         why: "10 KPIs × this-week vs last-week deltas. Spot trends fast." },
      { href: "/open-disputes",   title: "Open disputes",          why: "Anything submitted but not decided. Mediation queue." },
      { href: "/pending-kyc",     title: "Pending KYC",            why: "Engineers waiting on verification. Approve/reject." },
      { href: "/unmatched-jobs",  title: "Unmatched jobs (>7d)",    why: "Posted jobs with zero bids. Routing/outreach signal." },
      { href: "/escrow-stuck",    title: "Escrow stuck (>30d)",    why: "Cash held in escrow >30d. Likely a stuck flow." },
      { href: "/payout-fail-reasons", title: "Payout fail reasons", why: "RazorpayX failure codes accumulating. Reach out to engineers." },
      { href: "/payout-method-coverage", title: "Payout method coverage", why: "Platform-wide % of earners with verified VPA. <90% = meaningful payouts stuck." },
      { href: "/amc-pool-low-balance", title: "AMC pool low balance", why: "Active AMCs heading toward auto-suspend. Outreach BEFORE pause." },
      { href: "/engineers-missing-payout", title: "Engineers missing payout", why: "Earned in 30d but no verified VPA. Money stuck — nudge them." },
      { href: "/cron-status",     title: "Cron status",            why: "Confirm scheduled jobs ran. Quick sanity tile." },
    ],
  },
  {
    cadence: "Weekly (15 minutes, Monday)",
    intent: "Look at week-over-week trends + plan outreach.",
    items: [
      { href: "/weekly-kpis",            title: "Weekly KPIs",         why: "7 metrics × this-week vs last-week × delta %." },
      { href: "/amc-near-expiry",        title: "AMC near expiry (30d)", why: "Outreach queue for manual (non-auto-renew) AMCs." },
      { href: "/amc-paused",             title: "AMC paused",          why: "Contracts paused (often pool-balance shortfall). Restart queue." },
      { href: "/engineer-dormancy",      title: "Engineer dormancy",   why: "Past completers idle >30d. Re-engagement candidates." },
      { href: "/lead-scoring",           title: "Lead scoring",        why: "Engineers with ≥10 bids but 0 completions. Coaching list." },
      { href: "/supervision-funnel",     title: "Supervision funnel",  why: "Request → accept → signoff → success conversion." },
      { href: "/referral-funnel",        title: "Referral funnel",     why: "90d referral cohort progression." },
      { href: "/code-red-sla",           title: "Code Red SLA",        why: "Emergency request accept rate. Trust signal." },
      { href: "/dispute-resolution-latency", title: "Dispute resolution latency", why: "Mediation throughput health." },
    ],
  },
  {
    cadence: "Monthly (30 minutes, 1st of month)",
    intent: "Review business health + plan the next month's bets.",
    items: [
      { href: "/repair-jobs-by-month",   title: "Repair jobs by month",  why: "12-month posted/completed/cancelled + gross." },
      { href: "/signups-by-month",       title: "Signups by month",      why: "Acquisition trajectory." },
      { href: "/amc-contracts-by-month", title: "AMC contracts by month", why: "MRR additions per month." },
      { href: "/amc-revenue-by-tier",    title: "AMC revenue by tier",   why: "Tier mix · where MRR concentrates." },
      { href: "/amc-churn",              title: "AMC churn",             why: "30/90/180d churn % buckets." },
      { href: "/payouts-by-month",       title: "Payouts by month",      why: "Engineer-side cash flow trajectory." },
      { href: "/disputes-by-month",      title: "Disputes by month",     why: "Trust-pipeline health." },
      { href: "/retention-cohort",       title: "Retention cohort",      why: "Engineer signup-week × active-30d." },
      { href: "/escrow-by-month",        title: "Escrow by month",       why: "Released vs refunded over 12 months." },
      { href: "/commission-revenue-30d", title: "Commission revenue",    why: "Daily platform take (est.) over 30d." },
    ],
  },
  {
    cadence: "On-demand (when something breaks or surprises)",
    intent: "Forensics + debug surfaces.",
    items: [
      { href: "/audit",                  title: "Founder action log",    why: "Every founder mutation. Forensics ledger." },
      { href: "/admin-actions-trend",    title: "Admin actions trend",   why: "Volume of admin ops over 14d. Spot spikes." },
      { href: "/admin-top-ops",          title: "Admin top ops",         why: "Which RPCs get the most use." },
      { href: "/rls-coverage",           title: "RLS coverage",          why: "Per-table RLS state. Investigate any anon-writable findings." },
      { href: "/long-queries",           title: "Long-running queries",  why: "Slow queries currently in flight." },
      { href: "/slow-rpcs",              title: "Slow RPCs",             why: "Top RPCs by total wall-clock." },
      { href: "/index-health",           title: "Index health",          why: "Unused vs seq-scan-heavy." },
      { href: "/db-storage",             title: "DB storage",            why: "Heap vs index growth WoW." },
    ],
  },
];

export default async function FounderRunbookPage() {
  await requireFounder();
  return (
    <div className="space-y-8">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Founder runbook</h1>
        <span className="text-xs text-[var(--color-muted)]">workflow guide · what to check, when, and why</span>
      </header>

      {SECTIONS.map((section) => (
        <section key={section.cadence}>
          <h2 className="text-sm font-semibold">{section.cadence}</h2>
          <p className="mt-1 text-xs text-[var(--color-muted)]">{section.intent}</p>
          <div className="mt-3 grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
            {section.items.map((item) => (
              <Link
                key={item.href}
                href={item.href}
                className="rounded border border-[var(--color-border)] bg-white p-3 transition-colors hover:border-[var(--color-fg)]"
              >
                <h3 className="text-sm font-semibold">{item.title}</h3>
                <p className="mt-1 text-xs text-[var(--color-muted)]">{item.why}</p>
              </Link>
            ))}
          </div>
        </section>
      ))}

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Full catalog of every founder ops surface at <Link href="/ops-index" className="underline">/ops-index</Link>.
        This runbook is a curated subset — the surfaces a founder actually
        reviews on a routine cadence. Pages not listed here are still valuable
        for ad-hoc analysis but don&apos;t belong in a daily/weekly/monthly loop.
      </section>
    </div>
  );
}
