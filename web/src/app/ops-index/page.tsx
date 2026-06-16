import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Ops index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type OpsLink = {
  href: string;
  title: string;
  desc: string;
  round: string;
};

const SECTIONS: { label: string; links: OpsLink[] }[] = [
  {
    label: "Database health",
    links: [
      { href: "/db-storage", title: "DB storage", desc: "Per-table size · heap vs indexes · WoW growth delta", round: "r600 + r601" },
      { href: "/index-health", title: "Index health", desc: "Unused indexes · seq-scan-heavy tables", round: "r605" },
      { href: "/long-queries", title: "Long-running queries", desc: ">5s queries · idle-in-transaction flagged red", round: "r604" },
      { href: "/slow-rpcs", title: "Slow RPCs", desc: "pg_stat_statements top 50 by total wall-clock", round: "r610" },
    ],
  },
  {
    label: "Security",
    links: [
      { href: "/rls-coverage", title: "RLS coverage", desc: "Per-table RLS state + grants + risk score", round: "r603" },
      { href: "/audit", title: "Founder action log", desc: "Append-only audit ledger · filter by op_name", round: "r482+" },
    ],
  },
  {
    label: "Cash flow & integrations",
    links: [
      { href: "/escrow-aging", title: "Escrow aging", desc: "pending/held/in_dispute by age bucket × status", round: "r607" },
      { href: "/escrow-balance-rollup", title: "Escrow balance rollup", desc: "Per-status totals + avg + oldest", round: "r650" },
      { href: "/webhooks", title: "Webhook health", desc: "Razorpay + payouts success rate · 24h fail counts", round: "r606" },
      { href: "/payouts", title: "Engineer payouts", desc: "Queue · dead-letter · founder actions", round: "r428+" },
      { href: "/payout-latency", title: "Payout latency", desc: "Engineer payout queued → processed", round: "r624" },
      { href: "/payout-volume-30d", title: "Payout volume (30d)", desc: "Per-status total rupees + counts", round: "r651" },
      { href: "/refunds", title: "Refunds", desc: "Refund authorizations + history", round: "—" },
      { href: "/amc-revenue-trend", title: "AMC revenue trend", desc: "Daily AMC payment-orders paid (14d)", round: "r656" },
    ],
  },
  {
    label: "Growth & engagement",
    links: [
      { href: "/dashboard", title: "Hero dashboard", desc: "Top-line KPIs + today vs yesterday + v0.5 pipeline", round: "r597 + r602" },
      { href: "/signups", title: "Signups + active users", desc: "30d funnel + DAU/WAU/MAU breakdown", round: "r608 + r609" },
      { href: "/tiers", title: "Engineer tiers", desc: "Tier distribution + supervised threshold editor", round: "r550+" },
      { href: "/tier-history", title: "Tier history", desc: "Append-only ledger of promotion/demotion", round: "r593 + r596" },
      { href: "/tier-distribution-trend", title: "Tier distribution trend", desc: "Current + 30d net promotion/demotion delta", round: "r632" },
      { href: "/demand-signals", title: "Demand signals", desc: "Spare-parts market intel · founder priority", round: "r571+" },
      { href: "/training", title: "Supervised training", desc: "Pending + active assignments · threshold editor", round: "r576+" },
      { href: "/supervision-funnel", title: "Supervision funnel", desc: "request → accept → signoff → success", round: "r623" },
      { href: "/profile-completeness", title: "Profile completeness", desc: "Per-field coverage for verified engineers", round: "r620" },
      { href: "/weekly-kpis", title: "Weekly KPIs", desc: "WoW snapshot · 7 metrics × delta_pct", round: "r625" },
      { href: "/referral-funnel", title: "Referral funnel", desc: "90d referral cohort · signed → first job → bounty paid", round: "r646" },
      { href: "/retention-cohort", title: "Retention cohort", desc: "Engineer signup-week × active-30d retention", round: "r647" },
    ],
  },
  {
    label: "Engineers",
    links: [
      { href: "/engineer-utilization", title: "Utilization", desc: "Verified engineers active 7/30/90d + %", round: "r628" },
      { href: "/engineer-tenure", title: "Tenure", desc: "Verified engineers by signup age", round: "r629" },
      { href: "/engineer-onboarding-funnel", title: "Onboarding funnel", desc: "signed up → verified → first bid → first job", round: "r630" },
      { href: "/engineer-dormancy", title: "Dormancy", desc: "Past completers idle > 30d (re-engagement queue)", round: "r631" },
      { href: "/engineer-geo", title: "Geo", desc: "Top 50 cities by engineer count + verification mix", round: "r633" },
      { href: "/engineer-specialization-coverage", title: "Specialization coverage", desc: "Per-category engineer counts (flags <3)", round: "r634" },
      { href: "/top-engineers-7d", title: "Top earners (7d)", desc: "Top 25 by 7d gross + jobs + avg/job", round: "r615" },
      { href: "/top-engineers-30d", title: "Top earners (30d)", desc: "Top 50 by 30d gross + jobs + avg/job", round: "r635" },
      { href: "/engineer-acceptance-rate", title: "Acceptance rate", desc: "30d bid → accepted % (≥5 bids cohort)", round: "r636" },
    ],
  },
  {
    label: "Hospitals",
    links: [
      { href: "/hospital-utilization", title: "Utilization", desc: "Hospitals posting jobs 7/30/90d + %", round: "r637" },
      { href: "/hospital-repeat-rate", title: "Repeat rate", desc: "Distribution by lifetime job count", round: "r638" },
      { href: "/hospital-geo", title: "Geo", desc: "Top 50 cities · hospitals + 30d jobs + AMCs", round: "r639" },
      { href: "/top-hospitals-30d", title: "Top hospitals (30d)", desc: "Top 25 hospitals by 30d posts + AMC flag", round: "r616" },
    ],
  },
  {
    label: "Repair jobs",
    links: [
      { href: "/repair-job-funnel", title: "Funnel", desc: "30d cohort · posted → bid → accepted → in-progress → completed", round: "r641" },
      { href: "/job-fee-distribution", title: "Fee distribution", desc: "90d completed jobs by rupee bucket", round: "r642" },
      { href: "/job-bid-counts", title: "Bid counts", desc: "Jobs distributed by bids received (0/1/2-3/4-5/>5)", round: "r643" },
    ],
  },
  {
    label: "Spare parts",
    links: [
      { href: "/parts-demand-supply", title: "Demand vs supply", desc: "Per SKU: 90d demand vs bonded in-stock (top by gap)", round: "r644" },
      { href: "/parts-vendor-share", title: "Vendor share", desc: "Top 50 bonded suppliers by intake quantity", round: "r645" },
      { href: "/bonded-inventory", title: "Bonded inventory", desc: "r500 bonded-parts SKU rollup · in-stock/dispatched", round: "r619" },
    ],
  },
  {
    label: "Operations latency",
    links: [
      { href: "/kyc-aging", title: "KYC aging", desc: "Engineer KYC pending/rejected by age bucket", round: "r612" },
      { href: "/dispute-aging", title: "Dispute aging", desc: "Evidence packs submitted/accepted/rejected by age", round: "r613" },
      { href: "/dispute-resolution-latency", title: "Dispute resolution latency", desc: "Submitted → mediator-decision p50/p90", round: "r648" },
      { href: "/bid-latency", title: "Bid acceptance latency", desc: "Job-posted → bid-accepted (avg/p50/p90/max)", round: "r617" },
      { href: "/dsr-latency", title: "DSR sign-off latency", desc: "Engineer-submitted → hospital-signed lag", round: "r618" },
      { href: "/code-red-sla", title: "Code Red SLA", desc: "Emergency request accept rate + avg minutes", round: "r622" },
    ],
  },
  {
    label: "Business health",
    links: [
      { href: "/amc-churn", title: "AMC churn", desc: "Rolling 30/90/180d new + cancelled + churn %", round: "r614" },
      { href: "/amc-renewal-pipeline", title: "AMC renewal pipeline", desc: "Active AMCs expiring 30/60/90d · MRR/ARR at stake", round: "r627" },
      { href: "/amc-tier-distribution", title: "AMC tier distribution", desc: "Active + total contracts per tier + MRR + avg fee", round: "r640" },
      { href: "/amc-visits-cadence", title: "AMC visits cadence", desc: "Per-cadence visits completed vs scheduled", round: "r649" },
      { href: "/chains-health", title: "Chains health", desc: "Per-chain member count, AMC %, 30d job volume", round: "r621" },
    ],
  },
  {
    label: "Daily trends (14d)",
    links: [
      { href: "/signups-by-day-trend", title: "Signups by day", desc: "Daily total + engineer breakdown · IST", round: "r652" },
      { href: "/bid-volume-trend", title: "Bid volume", desc: "Daily bids placed + accepted + distinct engineers", round: "r653" },
      { href: "/jobs-volume-trend", title: "Jobs volume", desc: "Daily jobs posted + completed + gross rupees", round: "r654" },
      { href: "/demand-signals-trend", title: "Demand signals", desc: "Daily demand signals + distinct SKUs + reporters", round: "r655" },
    ],
  },
  {
    label: "Cron & periodic jobs",
    links: [
      { href: "/cron-status", title: "Cron status", desc: "pg_cron last-run + 24h failure counts", round: "r599" },
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
          r599–r656 sprint · all founder ops surfaces in one place
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
        <strong>r657 ops index.</strong> Catalogs the 30-ship autonomous chain
        (r628-r657) on top of the prior r599-r626 sprint. Each card links to a
        dedicated founder-only page powered by a SECDEF RPC. Pages degrade
        gracefully when underlying extensions (pg_cron, pg_stat_statements)
        aren&apos;t enabled on the current Supabase tier.
      </section>
    </div>
  );
}
