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
      {
        href: "/db-storage",
        title: "DB storage",
        desc: "Per-table size · heap vs indexes · WoW growth delta",
        round: "r600 + r601",
      },
      {
        href: "/index-health",
        title: "Index health",
        desc: "Unused indexes (DROP candidates) · seq-scan-heavy tables (CREATE candidates)",
        round: "r605",
      },
      {
        href: "/long-queries",
        title: "Long-running queries",
        desc: "pg_stat_activity wrapper · >5s queries · idle-in-transaction flagged red",
        round: "r604",
      },
      {
        href: "/slow-rpcs",
        title: "Slow RPCs",
        desc: "pg_stat_statements top 50 by total wall-clock · degrades when ext off",
        round: "r610",
      },
    ],
  },
  {
    label: "Security",
    links: [
      {
        href: "/rls-coverage",
        title: "RLS coverage",
        desc: "Per-table RLS state + grants + risk score · anon-writable flagged red",
        round: "r603",
      },
      {
        href: "/audit",
        title: "Founder action log",
        desc: "Append-only audit ledger · filter by op_name · forensics for every founder mutation",
        round: "r482+",
      },
    ],
  },
  {
    label: "Cash flow & integrations",
    links: [
      {
        href: "/escrow-aging",
        title: "Escrow aging",
        desc: "pending/held/in_dispute by age bucket × status · stuck cash >30d flagged",
        round: "r607",
      },
      {
        href: "/webhooks",
        title: "Webhook health",
        desc: "Razorpay + payouts success rate · 24h failure counts",
        round: "r606",
      },
      {
        href: "/payouts",
        title: "Engineer payouts",
        desc: "Queue · dead-letter · founder actions · job drilldown",
        round: "r428+",
      },
      {
        href: "/refunds",
        title: "Refunds",
        desc: "Refund authorizations + history",
        round: "—",
      },
    ],
  },
  {
    label: "Growth & engagement",
    links: [
      {
        href: "/dashboard",
        title: "Hero dashboard",
        desc: "Top-line KPIs + today vs yesterday + v0.5 pipeline health",
        round: "r597 + r602",
      },
      {
        href: "/signups",
        title: "Signups + active users",
        desc: "30d signup funnel by role + DAU/WAU/MAU breakdown",
        round: "r608 + r609",
      },
      {
        href: "/tiers",
        title: "Engineer tiers",
        desc: "Tier distribution + per-engineer evaluations + supervised threshold editor",
        round: "r550+",
      },
      {
        href: "/tier-history",
        title: "Tier history",
        desc: "Append-only ledger of every promotion/demotion with signal snapshots",
        round: "r593 + r596",
      },
      {
        href: "/demand-signals",
        title: "Demand signals",
        desc: "Spare-parts market intel · founder priority + bonded-intake link",
        round: "r571+",
      },
      {
        href: "/training",
        title: "Supervised training",
        desc: "Pending + active assignments · threshold editor · revoke",
        round: "r576+",
      },
      {
        href: "/supervision-funnel",
        title: "Supervision funnel",
        desc: "request → accept → signoff → success conversion across 7d/30d/90d",
        round: "r623",
      },
      {
        href: "/profile-completeness",
        title: "Profile completeness",
        desc: "Per-field coverage for verified engineers · bio/rate/city/specs/phone/avatar",
        round: "r620",
      },
      {
        href: "/weekly-kpis",
        title: "Weekly KPIs",
        desc: "WoW snapshot · 7 metrics × this-week vs last-week × delta_pct",
        round: "r625",
      },
    ],
  },
  {
    label: "Operations latency",
    links: [
      {
        href: "/kyc-aging",
        title: "KYC aging",
        desc: "Engineer KYC pending/rejected by age bucket (0-3/3-7/7-30/>30d)",
        round: "r612",
      },
      {
        href: "/dispute-aging",
        title: "Dispute aging",
        desc: "Evidence packs submitted/accepted/rejected by age bucket",
        round: "r613",
      },
      {
        href: "/bid-latency",
        title: "Bid acceptance latency",
        desc: "Job-posted → bid-accepted (avg/p50/p90/max) across 7d/30d/90d",
        round: "r617",
      },
      {
        href: "/dsr-latency",
        title: "DSR sign-off latency",
        desc: "Engineer-submitted → hospital-signed lag + unsigned counts",
        round: "r618",
      },
      {
        href: "/payout-latency",
        title: "Payout latency",
        desc: "Engineer payout queued → processed (hours) + pending/failed counts",
        round: "r624",
      },
      {
        href: "/code-red-sla",
        title: "Code Red SLA",
        desc: "Emergency request accept rate + avg accept minutes + timed-out count",
        round: "r622",
      },
    ],
  },
  {
    label: "Business health",
    links: [
      {
        href: "/amc-churn",
        title: "AMC churn",
        desc: "Rolling 30d/90d/180d new + cancelled + expired + renewal_failed + churn %",
        round: "r614",
      },
      {
        href: "/chains-health",
        title: "Chains health",
        desc: "Per-chain member count, AMC penetration %, 30d job volume",
        round: "r621",
      },
      {
        href: "/top-engineers-7d",
        title: "Top engineers (7d)",
        desc: "Top 25 engineers by 7-day gross + jobs + avg/job",
        round: "r615",
      },
      {
        href: "/top-hospitals-30d",
        title: "Top hospitals (30d)",
        desc: "Top 25 hospitals by 30d posts + AMC-attached flag",
        round: "r616",
      },
      {
        href: "/bonded-inventory",
        title: "Bonded inventory",
        desc: "r500 bonded-parts intake rollup by SKU · in-stock / dispatched / oldest-intake",
        round: "r619",
      },
    ],
  },
  {
    label: "Cron & periodic jobs",
    links: [
      {
        href: "/cron-status",
        title: "Cron status",
        desc: "pg_cron last-run + 24h failure counts · docs view when ext off",
        round: "r599",
      },
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
          r599–r625 sprint · all founder ops surfaces in one place
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
        <strong>r611 ops index.</strong> Catalogs the ops-tooling sprint
        (r599-r610 + r482-era surfaces). Each card links to a dedicated
        founder-only page powered by a SECDEF RPC. Pages degrade gracefully
        when underlying extensions (pg_cron, pg_stat_statements) aren&apos;t
        enabled on the current Supabase tier.
      </section>
    </div>
  );
}
