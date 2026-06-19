import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Leaderboards index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type LB = { href: string; title: string; desc: string; round: string; side: "Supply" | "Demand" | "Seller" };

const LEADERBOARDS: LB[] = [
  { href: "/engineer-leaderboard-30d",     title: "Engineer leaderboard 30d",      desc: "Top 50 engineers · jobs done + earnings + avg rating + tier",         round: "r1024", side: "Supply"  },
  { href: "/hospital-leaderboard-30d",     title: "Hospital leaderboard 30d",      desc: "Top 50 hospitals · jobs posted + completed + spend + AMC count",       round: "r1025", side: "Demand"  },
  { href: "/spare-parts-by-supplier-30d",  title: "Spare parts suppliers 30d",     desc: "Top 50 suppliers · orders + paid + GMV INR",                            round: "r1023", side: "Seller"  },
  { href: "/tier-climbers",                title: "Tier climbers",                  desc: "Non-gold engineers close to promotion",                                  round: "r676",  side: "Supply"  },
  { href: "/chains-amc-leaderboard",       title: "AMC leaderboard",                desc: "Top hospital chains by AMC contract value · MRR · contract count",       round: "r722",  side: "Demand"  },
];

const SIDE_TONE: Record<LB["side"], string> = {
  Supply: "text-[var(--color-ok)]",
  Demand: "text-[var(--color-info)]",
  Seller: "text-[var(--color-warn)]",
};

export default async function LeaderboardsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Leaderboards index ★ r1026</h1>
        <span className="text-xs text-[var(--color-muted)]">Supply · Demand · Seller leaderboards in one place · 4th meta-landing</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {LEADERBOARDS.map((l) => (
          <Link key={l.href} href={l.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{l.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{l.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{l.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${SIDE_TONE[l.side]}`}>{l.side}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
