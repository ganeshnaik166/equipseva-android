import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "By-hour index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Hourly = { href: string; title: string; desc: string; round: string; domain: "Marketplace" | "Governance" | "Payments" };

const HOURLIES: Hourly[] = [
  { href: "/jobs-by-hour-7d",       title: "Jobs by hour 7d",       desc: "24 IST hours · jobs posted + bids + completed",       round: "r1058", domain: "Marketplace" },
  { href: "/signups-by-hour-7d",    title: "Signups by hour 7d",    desc: "24 IST hours · engineer/hospital/other splits",        round: "r1094", domain: "Marketplace" },
  { href: "/code-red-by-hour-7d",   title: "Code Red by hour 7d",   desc: "24 IST hours · volume + resolved + timed_out",         round: "r1086", domain: "Marketplace" },
  { href: "/audit-by-hour-7d",      title: "Audit by hour 7d",      desc: "24 IST hours · founder ops distribution",              round: "r1057", domain: "Governance"  },
  { href: "/payouts-by-hour-7d",    title: "Payouts by hour 7d",    desc: "24 IST hours · queued/processed/failed + paid INR",    round: "r1087", domain: "Payments"    },
  { href: "/payouts-by-hour",       title: "Payouts by hour (orig)", desc: "Original payout processing time-of-day distribution", round: "r700+", domain: "Payments"    },
];

const TONE: Record<Hourly["domain"], string> = {
  Marketplace: "text-[var(--color-info)]",
  Governance:  "text-[var(--color-warn)]",
  Payments:    "text-[var(--color-ok)]",
};

export default async function ByHourIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">By-hour index ★ r1059 (expanded r1095)</h1>
        <span className="text-xs text-[var(--color-muted)]">10th meta-landing · 6 hour-of-day surfaces grouped by domain</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {HOURLIES.map((h) => (
          <Link key={h.href} href={h.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{h.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{h.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{h.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${TONE[h.domain]}`}>{h.domain}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
