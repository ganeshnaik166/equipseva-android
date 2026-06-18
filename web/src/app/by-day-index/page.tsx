import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "By-day index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Daily = { href: string; title: string; desc: string; round: string; domain: "Marketplace" | "Revenue" | "Trust" | "Engagement" | "Governance" };

const DAILIES: Daily[] = [
  { href: "/jobs-by-day-30d",                   title: "Jobs by day 30d",                  desc: "Posted/completed/cancelled + bids",                            round: "r1039", domain: "Marketplace" },
  { href: "/amc-contracts-by-day-30d",          title: "AMC contracts by day 30d",          desc: "New AMCs + MRR added",                                          round: "r1038", domain: "Revenue"     },
  { href: "/code-red-by-day-30d",               title: "Code Red by day 30d",               desc: "Volume + resolved/timed_out + resolved %",                       round: "r1037", domain: "Trust"       },
  { href: "/daily-kpi-snapshot",                title: "Daily KPI snapshot",                 desc: "90d × 8 raw KPIs",                                              round: "r989",  domain: "Marketplace" },
  { href: "/notifications-engagement-30d",      title: "Notifications engagement 30d",      desc: "Daily sent/read + unread %",                                    round: "r1016", domain: "Engagement"  },
  { href: "/audit-ops-by-day-30d",              title: "Audit ops by day 30d",              desc: "Daily founder activity + success/fail + actors",                round: "r1034", domain: "Governance"  },
];

const DOMAIN_TONE: Record<Daily["domain"], string> = {
  Marketplace: "text-[var(--color-info)]",
  Revenue:     "text-[var(--color-ok)]",
  Trust:       "text-[var(--color-danger)]",
  Engagement:  "text-[var(--color-muted)]",
  Governance:  "text-[var(--color-warn)]",
};

export default async function ByDayIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">By-day index ★ r1040</h1>
        <span className="text-xs text-[var(--color-muted)]">7th meta-landing · 6 daily time-series surfaces grouped by domain</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {DAILIES.map((d) => (
          <Link key={d.href} href={d.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{d.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{d.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{d.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${DOMAIN_TONE[d.domain]}`}>{d.domain}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
