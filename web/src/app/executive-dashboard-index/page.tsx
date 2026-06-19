import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Executive dashboard index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Dash = { href: string; title: string; desc: string; round: string; priority: "Tier 1" | "Tier 2" | "Tier 3" };

const DASHES: Dash[] = [
  // Tier 1 — daily founder dashboards (bookmark these)
  { href: "/critical-cockpit",              title: "Critical cockpit",         desc: "14-tile aging/leak signals · open this first every morning",                round: "r1000", priority: "Tier 1" },
  { href: "/founder-morning-pulse-v2",      title: "Founder morning pulse v2", desc: "12 actionable numbers · today vs yesterday · 4 categories",                 round: "r1130", priority: "Tier 1" },
  { href: "/money-in-flight-summary",       title: "Money in flight summary",  desc: "Cross-domain cash position · escrow + payouts + spare-parts + AMC pool",   round: "r1193", priority: "Tier 1" },
  { href: "/trust-pulse-summary",           title: "Trust pulse summary",      desc: "Composite trust score · disputes + audits + Code Red + refunds + payouts", round: "r1195", priority: "Tier 1" },

  // Tier 2 — domain-specific snapshot dashboards
  { href: "/amc-snapshot-summary",          title: "AMC snapshot",             desc: "13-KPI AMC pipeline",                                                       round: "r1161", priority: "Tier 2" },
  { href: "/jobs-snapshot-summary",         title: "Jobs snapshot",            desc: "12-KPI marketplace mix",                                                    round: "r1162", priority: "Tier 2" },
  { href: "/code-red-snapshot-summary",     title: "Code Red snapshot",        desc: "13-KPI emergency queue + SLA breach %",                                     round: "r1165", priority: "Tier 2" },
  { href: "/payouts-snapshot-summary",      title: "Payouts snapshot",         desc: "14-KPI payouts pipeline",                                                   round: "r1166", priority: "Tier 2" },
  { href: "/spare-parts-snapshot-summary",  title: "Spare parts snapshot",     desc: "15-KPI commerce funnel",                                                    round: "r1167", priority: "Tier 2" },
  { href: "/engineers-snapshot-summary",    title: "Engineers snapshot",       desc: "14-KPI supply dashboard",                                                   round: "r1168", priority: "Tier 2" },
  { href: "/hospitals-snapshot-summary",    title: "Hospitals snapshot",       desc: "15-KPI demand dashboard",                                                   round: "r1169", priority: "Tier 2" },
  { href: "/disputes-snapshot-summary",     title: "Disputes snapshot",        desc: "14-KPI mediation queue",                                                    round: "r1170", priority: "Tier 2" },
  { href: "/escrow-snapshot-summary",       title: "Escrow snapshot",          desc: "18-KPI money-in-flight detail",                                             round: "r1171", priority: "Tier 2" },

  // Tier 3 — narrower domain dashboards
  { href: "/referrals-snapshot-summary",            title: "Referrals snapshot",            desc: "Growth-loop spend + ROI + stuck",            round: "r1180", priority: "Tier 3" },
  { href: "/hospital-chains-snapshot-summary",      title: "Hospital chains snapshot",      desc: "Chain whale dashboard",                       round: "r1181", priority: "Tier 3" },
  { href: "/supervised-training-snapshot-summary",  title: "Supervised training snapshot",  desc: "Pipeline + pass rate",                        round: "r1182", priority: "Tier 3" },
  { href: "/notifications-snapshot-summary",        title: "Notifications snapshot",        desc: "Throughput + stuck-unread alerts",            round: "r1183", priority: "Tier 3" },
  { href: "/signups-funnel-snapshot-summary",       title: "Signups funnel snapshot",       desc: "Acquisition funnel × role",                   round: "r1184", priority: "Tier 3" },
  { href: "/spot-audits-snapshot-summary",          title: "Spot audits snapshot",          desc: "QA + investor compliance",                    round: "r1185", priority: "Tier 3" },
];

const PRIO_TONE: Record<Dash["priority"], string> = {
  "Tier 1": "text-[var(--color-danger)]",
  "Tier 2": "text-[var(--color-warn)]",
  "Tier 3": "text-[var(--color-info)]",
};

export default async function ExecutiveDashboardIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Executive dashboard index ★ r1196</h1>
        <span className="text-xs text-[var(--color-muted)]">26th meta-landing · {DASHES.length} founder dashboards ranked by daily-usage priority</span>
      </header>
      <p className="text-sm text-[var(--color-muted)]">Tier 1 = open these first every morning. Tier 2 = drill into when a Tier-1 alert fires. Tier 3 = weekly review depth.</p>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {DASHES.map((d) => (
          <Link key={d.href} href={d.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{d.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{d.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{d.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${PRIO_TONE[d.priority]}`}>{d.priority}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
