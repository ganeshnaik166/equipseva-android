import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Ops index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type OpsLink = { href: string; title: string; desc: string; round: string };

const SECTIONS: { label: string; links: OpsLink[] }[] = [
  {
    label: "Database health",
    links: [
      { href: "/db-storage", title: "DB storage", desc: "Per-table size · WoW growth", round: "r600+" },
      { href: "/index-health", title: "Index health", desc: "Unused + seq-scan-heavy", round: "r605" },
      { href: "/long-queries", title: "Long-running queries", desc: ">5s queries · idle-in-tx", round: "r604" },
      { href: "/slow-rpcs", title: "Slow RPCs", desc: "pg_stat_statements top 50", round: "r610" },
    ],
  },
  {
    label: "Security & audit",
    links: [
      { href: "/rls-coverage", title: "RLS coverage", desc: "Per-table RLS + grants + risk", round: "r603" },
      { href: "/audit", title: "Founder action log", desc: "Append-only audit ledger", round: "r482+" },
      { href: "/admin-actions-trend", title: "Admin actions trend", desc: "Daily founder_action_log volume", round: "r672" },
      { href: "/admin-top-ops", title: "Admin top ops", desc: "Most-used founder ops · 30d", round: "r673" },
      { href: "/pending-kyc", title: "Pending KYC", desc: "Engineer verification queue", round: "r664" },
      { href: "/open-disputes", title: "Open disputes", desc: "Submitted packs awaiting decision", round: "r665" },
      { href: "/spot-audits-summary", title: "Spot audits", desc: "Invitations · responses · ratings", round: "r682" },
    ],
  },
  {
    label: "Cash flow & integrations",
    links: [
      { href: "/escrow-aging", title: "Escrow aging", desc: "Live escrow by age × status", round: "r607" },
      { href: "/escrow-balance-rollup", title: "Escrow balance rollup", desc: "Per-status totals + oldest", round: "r650" },
      { href: "/escrow-stuck", title: "Escrow stuck >30d", desc: "Pending/held/dispute aged out", round: "r662" },
      { href: "/escrow-velocity", title: "Escrow velocity", desc: "Created → released p50/p90", round: "r674" },
      { href: "/webhooks", title: "Webhook health", desc: "Razorpay + payouts success", round: "r606" },
      { href: "/payouts", title: "Engineer payouts", desc: "Queue · dead-letter · ops", round: "r428+" },
      { href: "/payout-latency", title: "Payout latency", desc: "Queued → processed time", round: "r624" },
      { href: "/payout-volume-30d", title: "Payout volume 30d", desc: "Per-status rupees", round: "r651" },
      { href: "/payouts-by-day-trend", title: "Payouts by day", desc: "Daily paid + failed (14d)", round: "r686" },
      { href: "/payout-fail-reasons", title: "Payout fail reasons", desc: "RazorpayX status distribution", round: "r666" },
      { href: "/refunds", title: "Refunds", desc: "Refund authorizations + history", round: "—" },
      { href: "/commission-revenue-30d", title: "Commission revenue (30d)", desc: "Daily platform take (est)", round: "r663" },
      { href: "/amc-revenue-trend", title: "AMC revenue trend", desc: "Daily AMC paid orders (14d)", round: "r656" },
      { href: "/amc-payment-orders-status", title: "AMC payment orders status", desc: "Pending/paid/failed/refunded", round: "r667" },
    ],
  },
  {
    label: "Growth & engagement",
    links: [
      { href: "/dashboard", title: "Hero dashboard", desc: "Top-line KPIs", round: "r597+" },
      { href: "/signups", title: "Signups + active users", desc: "Funnel + DAU/WAU/MAU", round: "r608+" },
      { href: "/weekly-kpis", title: "Weekly KPIs", desc: "WoW snapshot · 7 metrics", round: "r625" },
      { href: "/tiers", title: "Engineer tiers", desc: "Tier distribution + threshold", round: "r550+" },
      { href: "/tier-history", title: "Tier history", desc: "Promotion/demotion ledger", round: "r593+" },
      { href: "/tier-distribution-trend", title: "Tier distribution trend", desc: "Current + 30d delta", round: "r632" },
      { href: "/tier-climbers", title: "Tier climbers", desc: "Non-gold close to promotion", round: "r676" },
      { href: "/demand-signals", title: "Demand signals", desc: "Market intel + priority", round: "r571+" },
      { href: "/demand-signal-status", title: "Demand signal status", desc: "Open by priority + resolved", round: "r677" },
      { href: "/training", title: "Supervised training", desc: "Pending + active assignments", round: "r576+" },
      { href: "/supervised-active", title: "Supervised active", desc: "Pending + active list", round: "r684" },
      { href: "/supervised-outcomes", title: "Supervised outcomes", desc: "Lifetime status distribution", round: "r685" },
      { href: "/supervision-funnel", title: "Supervision funnel", desc: "Request → success conversion", round: "r623" },
      { href: "/profile-completeness", title: "Profile completeness", desc: "Per-field coverage", round: "r620" },
      { href: "/referral-funnel", title: "Referral funnel", desc: "90d cohort signed → paid", round: "r646" },
      { href: "/referral-volume-trend", title: "Referral volume trend", desc: "Daily referrals/first-jobs/bounties", round: "r668" },
      { href: "/referrers-leaderboard", title: "Referrers leaderboard", desc: "Top 50 by first-job conversions", round: "r680" },
      { href: "/retention-cohort", title: "Retention cohort", desc: "Engineer signup-week × active", round: "r647" },
    ],
  },
  {
    label: "Engineers",
    links: [
      { href: "/engineer-utilization", title: "Utilization", desc: "Verified active 7/30/90d", round: "r628" },
      { href: "/engineer-tenure", title: "Tenure", desc: "Verified by signup age", round: "r629" },
      { href: "/engineer-onboarding-funnel", title: "Onboarding funnel", desc: "Signup → first job", round: "r630" },
      { href: "/engineer-dormancy", title: "Dormancy", desc: "Past completers idle >30d", round: "r631" },
      { href: "/engineer-geo", title: "Geo", desc: "Top 50 cities + verification", round: "r633" },
      { href: "/engineer-specialization-coverage", title: "Specialization coverage", desc: "Per-category counts (flag <3)", round: "r634" },
      { href: "/top-engineers-7d", title: "Top earners (7d)", desc: "Top 25 by 7d gross", round: "r615" },
      { href: "/top-engineers-30d", title: "Top earners (30d)", desc: "Top 50 by 30d gross", round: "r635" },
      { href: "/engineer-acceptance-rate", title: "Acceptance rate", desc: "30d bid → accepted %", round: "r636" },
      { href: "/engineer-payout-history", title: "Payout history", desc: "30/90d/lifetime per engineer", round: "r658" },
      { href: "/engineer-rating-distribution", title: "Rating distribution", desc: "180d histogram 5..1 stars", round: "r671" },
      { href: "/lead-scoring", title: "Lead scoring", desc: "≥10 bids, 0 completions", round: "r670" },
    ],
  },
  {
    label: "Hospitals",
    links: [
      { href: "/hospital-utilization", title: "Utilization", desc: "Posting jobs 7/30/90d", round: "r637" },
      { href: "/hospital-repeat-rate", title: "Repeat rate", desc: "Lifetime job count buckets", round: "r638" },
      { href: "/hospital-geo", title: "Geo", desc: "Top 50 cities", round: "r639" },
      { href: "/hospital-spend-30d", title: "Spend (30d)", desc: "Top 50 spenders + AMC flag", round: "r659" },
      { href: "/hospital-amc-coverage", title: "AMC coverage", desc: "With vs without active AMC", round: "r675" },
      { href: "/top-hospitals-30d", title: "Top hospitals (30d)", desc: "Top 25 by 30d posts", round: "r616" },
    ],
  },
  {
    label: "Repair jobs",
    links: [
      { href: "/repair-job-funnel", title: "Funnel", desc: "30d posted → completed", round: "r641" },
      { href: "/job-fee-distribution", title: "Fee distribution", desc: "90d gross by bucket", round: "r642" },
      { href: "/job-bid-counts", title: "Bid counts", desc: "Bids-per-job histogram", round: "r643" },
      { href: "/unmatched-jobs", title: "Unmatched >7d", desc: "Posted >7d ago · zero bids", round: "r661" },
    ],
  },
  {
    label: "Spare parts",
    links: [
      { href: "/parts-demand-supply", title: "Demand vs supply", desc: "90d demand vs bonded stock", round: "r644" },
      { href: "/parts-vendor-share", title: "Vendor share", desc: "Top 50 bonded suppliers", round: "r645" },
      { href: "/bonded-inventory", title: "Bonded inventory", desc: "SKU rollup · in-stock", round: "r619" },
    ],
  },
  {
    label: "Operations latency",
    links: [
      { href: "/kyc-aging", title: "KYC aging", desc: "Pending/rejected age buckets", round: "r612" },
      { href: "/dispute-aging", title: "Dispute aging", desc: "Evidence pack age buckets", round: "r613" },
      { href: "/dispute-resolution-latency", title: "Dispute resolution latency", desc: "Submitted → decision p50/p90", round: "r648" },
      { href: "/bid-latency", title: "Bid acceptance latency", desc: "Posted → accepted (p50/p90)", round: "r617" },
      { href: "/dsr-latency", title: "DSR sign-off latency", desc: "Engineer → hospital signed", round: "r618" },
      { href: "/code-red-sla", title: "Code Red SLA", desc: "Emergency accept rate", round: "r622" },
    ],
  },
  {
    label: "Business health",
    links: [
      { href: "/amc-churn", title: "AMC churn", desc: "Rolling 30/90/180d churn %", round: "r614" },
      { href: "/amc-renewal-pipeline", title: "AMC renewal pipeline", desc: "Expiring 30/60/90d · MRR/ARR", round: "r627" },
      { href: "/amc-near-expiry", title: "AMC near expiry", desc: "Expiring within 30d list", round: "r660" },
      { href: "/amc-tier-distribution", title: "AMC tier distribution", desc: "Per-tier active + MRR", round: "r640" },
      { href: "/amc-visits-cadence", title: "AMC visits cadence", desc: "Completed vs scheduled %", round: "r649" },
      { href: "/amc-pool-health", title: "AMC pool health", desc: "Balance distribution buckets", round: "r678" },
      { href: "/amc-paused", title: "AMC paused", desc: "Paused contracts · MRR frozen", round: "r679" },
      { href: "/amc-cancellations", title: "AMC cancellations 30d", desc: "Cancelled/failed/expired list", round: "r683" },
      { href: "/chains-health", title: "Chains health", desc: "Per-chain AMC % + jobs", round: "r621" },
      { href: "/chains-leaderboard", title: "Chains leaderboard", desc: "Top 50 by member count", round: "r681" },
    ],
  },
  {
    label: "Daily trends (14d)",
    links: [
      { href: "/signups-by-day-trend", title: "Signups by day", desc: "Daily + engineer breakdown", round: "r652" },
      { href: "/bid-volume-trend", title: "Bid volume", desc: "Placed + accepted + engineers", round: "r653" },
      { href: "/jobs-volume-trend", title: "Jobs volume", desc: "Posted + completed + gross", round: "r654" },
      { href: "/demand-signals-trend", title: "Demand signals", desc: "Daily + distinct SKUs + reporters", round: "r655" },
      { href: "/referral-volume-trend", title: "Referral volume", desc: "Daily referrals + first-jobs + bounties", round: "r668" },
      { href: "/code-red-volume-trend", title: "Code Red volume", desc: "Daily opened + timed-out", round: "r669" },
      { href: "/payouts-by-day-trend", title: "Payouts by day", desc: "Daily paid + rupees + failed", round: "r686" },
    ],
  },
  {
    label: "Cron & periodic jobs",
    links: [
      { href: "/cron-status", title: "Cron status", desc: "pg_cron last-run + failures", round: "r599" },
    ],
  },
];

export default async function OpsIndexPage() {
  await requireFounder();

  return (
    <div className="space-y-8">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Ops index</h1>
        <span className="text-xs text-[var(--color-muted)]">
          r599–r686 sprint · all founder ops surfaces in one place
        </span>
      </header>

      {SECTIONS.map((section) => (
        <section key={section.label}>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            {section.label}
          </h2>
          <div className="grid grid-cols-1 gap-3 md:grid-cols-2 lg:grid-cols-3">
            {section.links.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="rounded border border-[var(--color-border)] bg-white p-3 transition-colors hover:border-[var(--color-fg)]"
              >
                <div className="flex items-baseline justify-between">
                  <h3 className="text-sm font-semibold">{link.title}</h3>
                  <span className="text-[10px] text-[var(--color-muted)]">
                    {link.round}
                  </span>
                </div>
                <p className="mt-1 text-xs text-[var(--color-muted)]">{link.desc}</p>
              </Link>
            ))}
          </div>
        </section>
      ))}

      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>r687 ops index.</strong> Catalogs the second 30-ship autonomous
        chain (r658-r687) on top of r628-r657 and r599-r627. 85+ founder ops
        surfaces, each powered by a SECDEF RPC + <code>is_founder()</code> gate.
        Pages degrade gracefully when underlying extensions (pg_cron, pg_stat_statements)
        aren&apos;t enabled on the current Supabase tier.
      </section>
    </div>
  );
}
