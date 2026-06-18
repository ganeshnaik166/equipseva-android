import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Coverage index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Geo = { href: string; title: string; desc: string; round: string; level: "City" | "State" | "Chain" };

const COVERAGE: Geo[] = [
  { href: "/city-coverage",                  title: "City coverage",                desc: "Top 50 cities · engineers + hospitals + jobs + AMCs",   round: "r1028", level: "City"  },
  { href: "/state-coverage",                 title: "State coverage",                desc: "All states · supply/demand/MRR matrix",                   round: "r1029", level: "State" },
  { href: "/tier-distribution-by-city",      title: "Tier distribution by city",     desc: "Top 50 cities × engineer cert tier mix",                  round: "r898", level: "City"  },
  { href: "/amc-revenue-by-city",            title: "AMC revenue by city",           desc: "Top cities by AMC revenue",                                round: "r700+", level: "City"  },
  { href: "/amc-revenue-by-state",           title: "AMC revenue by state",          desc: "Per-state AMC revenue rollup",                             round: "r700+", level: "State" },
  { href: "/spare-parts-by-state",           title: "Spare parts by state",          desc: "Per-state spare parts demand",                             round: "r700+", level: "State" },
  { href: "/chains-health",                  title: "Chains health",                 desc: "Per-chain AMC penetration",                                round: "r621",  level: "Chain" },
];

const LEVEL_TONE: Record<Geo["level"], string> = {
  City:  "text-[var(--color-info)]",
  State: "text-[var(--color-warn)]",
  Chain: "text-[var(--color-ok)]",
};

export default async function CoverageIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Coverage index ★ r1030</h1>
        <span className="text-xs text-[var(--color-muted)]">6th meta-landing · all geographic + chain coverage surfaces</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {COVERAGE.map((c) => (
          <Link key={c.href} href={c.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{c.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{c.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{c.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${LEVEL_TONE[c.level]}`}>{c.level}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
