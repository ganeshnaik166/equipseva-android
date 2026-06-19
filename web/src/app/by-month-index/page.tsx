import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "By-month index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Surf = { href: string; title: string; desc: string; round: string; section: "Marketplace" | "AMC" | "Money" | "Trust" | "Growth" | "Supply" };

const SURFACES: Surf[] = [
  // Marketplace
  { href: "/jobs-by-month-by-status",            title: "Jobs × status month",         desc: "12mo posted/completed/cancelled cross-tab",            round: "r965",  section: "Marketplace" },
  { href: "/repair-jobs-by-month",               title: "Repair jobs by month",        desc: "12mo posted + completed counts",                       round: "r615",  section: "Marketplace" },
  { href: "/spare-parts-by-month",               title: "Spare parts by month",        desc: "12mo orders + GMV",                                    round: "r913",  section: "Marketplace" },
  { href: "/spare-parts-by-month-by-status",     title: "Spare parts × status month",  desc: "12mo paid/shipped/delivered cross-tab",                round: "r966",  section: "Marketplace" },
  { href: "/spare-parts-revenue-by-month",       title: "Spare parts revenue / month", desc: "12mo paid GMV + avg/order",                            round: "r1159", section: "Marketplace" },
  { href: "/code-red-by-month",                  title: "Code Red by month",           desc: "12mo opened + resolved + timed_out",                   round: "r627",  section: "Marketplace" },
  { href: "/code-red-by-month-by-status",        title: "Code Red × status month",     desc: "12mo cross-tab by outcome",                            round: "r967",  section: "Marketplace" },
  { href: "/demand-signals-by-month",            title: "Demand signals by month",     desc: "12mo unmet-demand reports + SKUs",                     round: "r695",  section: "Marketplace" },

  // AMC
  { href: "/amc-contracts-by-month",             title: "AMC contracts / month",       desc: "12mo new AMCs + MRR added",                            round: "r628",  section: "AMC" },
  { href: "/amc-contracts-by-month-by-tier",     title: "AMC contracts × tier month",  desc: "6mo acquisition cross-tab",                             round: "r971",  section: "AMC" },
  { href: "/amc-payment-by-month",               title: "AMC payment by month",        desc: "12mo collected MRR",                                   round: "r629",  section: "AMC" },
  { href: "/amc-revenue-by-month-by-tier",       title: "AMC revenue × tier month",    desc: "12mo MRR cross-tab",                                   round: "r972",  section: "AMC" },
  { href: "/amc-renewal-attempts-by-month",      title: "AMC renewal attempts month",  desc: "12mo × status + success %",                            round: "r1078", section: "AMC" },
  { href: "/amc-renewal-by-month-by-status",     title: "AMC renewal × status month",  desc: "12mo succeeded/failed/abandoned",                       round: "r963",  section: "AMC" },
  { href: "/amc-renewal-rate-by-month",          title: "AMC renewal rate / month",    desc: "6mo renewed/due %",                                    round: "r1054", section: "AMC" },
  { href: "/amc-churn-rate-by-month",            title: "AMC churn rate / month",      desc: "(Expired + paused) / Active SOM %",                    round: "r1126", section: "AMC" },
  { href: "/amc-pool-net-flow-by-month",         title: "AMC pool net flow / month",   desc: "6mo credits − debits − refunds",                       round: "r1065", section: "AMC" },
  { href: "/amc-pool-credits-by-month-by-tier",  title: "Pool credits × tier month",   desc: "6mo top-up cross-tab",                                  round: "r985",  section: "AMC" },
  { href: "/amc-pool-debits-by-month-by-tier",   title: "Pool debits × tier month",    desc: "6mo consumption cross-tab",                             round: "r983",  section: "AMC" },

  // Money
  { href: "/payouts-by-month",                   title: "Payouts by month",            desc: "12mo paid count + INR",                                round: "r639",  section: "Money" },
  { href: "/payouts-by-month-by-status",         title: "Payouts × status month",      desc: "12mo queued/processed/failed cross-tab",                round: "r968",  section: "Money" },
  { href: "/commission-by-month",                title: "Commission by month",         desc: "12mo platform commission INR",                         round: "r687",  section: "Money" },
  { href: "/platform-fee-revenue-by-month",      title: "Platform fee revenue month",  desc: "12mo platform fee INR",                                round: "r688",  section: "Money" },
  { href: "/escrow-by-month",                    title: "Escrow by month",             desc: "12mo escrow held + released INR",                       round: "r692",  section: "Money" },
  { href: "/escrow-by-month-by-status",          title: "Escrow × status month",       desc: "12mo cross-tab",                                       round: "r970",  section: "Money" },
  { href: "/gst-invoices-by-month-by-source",    title: "GST invoices × source month", desc: "12mo cross-tab",                                       round: "r975",  section: "Money" },

  // Trust
  { href: "/disputes-by-month",                  title: "Disputes by month",           desc: "12mo opened + resolved",                                round: "r626",  section: "Trust" },
  { href: "/disputes-by-month-by-status",        title: "Disputes × status month",     desc: "12mo accepted/rejected/withdrawn",                      round: "r969",  section: "Trust" },
  { href: "/spot-audits-by-month",               title: "Spot audits by month",        desc: "12mo audits + pass rate",                               round: "r674",  section: "Trust" },

  // Growth
  { href: "/signups-by-month",                   title: "Signups by month",            desc: "12mo all roles",                                       round: "r625",  section: "Growth" },
  { href: "/signups-by-month-by-role",           title: "Signups × role month",        desc: "12mo engineer/hospital/buyer cross-tab",                round: "r964",  section: "Growth" },
  { href: "/referrals-by-month",                 title: "Referrals by month",          desc: "12mo referrals + conversions",                          round: "r684",  section: "Growth" },
  { href: "/referrals-by-month-by-status",       title: "Referrals × status month",    desc: "12mo cross-tab",                                       round: "r973",  section: "Growth" },
  { href: "/referral-bounty-payouts-by-month",   title: "Referral bounty / month",     desc: "12mo bounty paid + cancelled + queued INR",             round: "r1155", section: "Growth" },

  // Supply
  { href: "/supervised-by-month",                title: "Supervised by month",         desc: "12mo supervised sessions",                              round: "r689",  section: "Supply" },
  { href: "/supervised-by-month-by-status",      title: "Supervised × status month",   desc: "12mo cross-tab",                                       round: "r974",  section: "Supply" },
  { href: "/supervision-outcome-rate-by-month",  title: "Supervision outcome / month", desc: "12mo successful/requested %",                          round: "r1160", section: "Supply" },
  { href: "/tier-changes-by-month",              title: "Tier changes by month",       desc: "12mo promotion + demotion ledger",                      round: "r678",  section: "Supply" },
  { href: "/tier-promotion-rate-by-month",       title: "Tier promotion rate month",   desc: "12mo promoted / eligible %",                            round: "r1119", section: "Supply" },
];

const SEC_TONE: Record<Surf["section"], string> = {
  Marketplace: "text-[var(--color-info)]",
  AMC:         "text-[var(--color-ok)]",
  Money:       "text-[var(--color-warn)]",
  Trust:       "text-[var(--color-danger)]",
  Growth:      "text-[var(--color-accent)]",
  Supply:      "text-[var(--color-info)]",
};

export default async function ByMonthIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">By-month index ★ r1179</h1>
        <span className="text-xs text-[var(--color-muted)]">25th meta-landing · {SURFACES.length} monthly time-series surfaces grouped by section</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {SURFACES.map((s) => (
          <Link key={s.href} href={s.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{s.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{s.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{s.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${SEC_TONE[s.section]}`}>{s.section}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
