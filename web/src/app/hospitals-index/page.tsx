import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Hospitals index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type H = { href: string; title: string; desc: string; round: string; section: "Aggregate" | "Retention" | "Spend" | "Aging" | "Chain" | "Geographic" };

const SURFACES: H[] = [
  { href: "/hospital-loyalty-funnel",      title: "Hospital loyalty funnel",         desc: "Repeat purchase signal",                                round: "r904",  section: "Retention"  },
  { href: "/hospital-recency",             title: "Hospital recency",                desc: "Time-since-last-action distribution",                  round: "r887",  section: "Retention"  },
  { href: "/hospital-onboarding-funnel",   title: "Hospital onboarding funnel",      desc: "Signup → 1st job → 1st bid → 1st done → 1st AMC",       round: "r1007", section: "Retention"  },
  { href: "/hospital-cohort-retention",    title: "Hospital cohort retention",       desc: "12mo signup cohorts × 30/60/90/180d posted-job %",       round: "r1052", section: "Retention"  },
  { href: "/hospitals-no-jobs-30d",        title: "Hospital activation leak",        desc: "Hospitals w/ 0 posted jobs in 30/60/90d + never",       round: "r993",  section: "Aging"      },
  { href: "/hospital-leaderboard-30d",     title: "Hospital leaderboard 30d",        desc: "Top 50 by 30d jobs posted",                              round: "r1025", section: "Aggregate"  },
  { href: "/hospital-spend-distribution",  title: "Hospital spend distribution",     desc: "90d spend per hospital × 7 amount buckets",              round: "r1132", section: "Spend"      },
  { href: "/founder-amc-leaderboard",      title: "AMC leaderboard",                 desc: "Top hospitals by AMC contract value",                    round: "r700+", section: "Spend"      },
  { href: "/chains-amc-leaderboard",       title: "Chains AMC leaderboard",          desc: "Top 50 chains × AMC MRR",                                round: "r1063", section: "Chain"      },
  { href: "/chains-engineer-coverage",     title: "Chains engineer coverage",        desc: "Per chain · engineer supply readiness",                  round: "r1064", section: "Chain"      },
  { href: "/chains-health",                title: "Chains health",                   desc: "Per-chain AMC penetration",                              round: "r621",  section: "Chain"      },
  { href: "/coverage-index",               title: "Coverage index",                   desc: "Geographic + chain coverage surfaces (meta)",            round: "r1030", section: "Geographic" },
  { href: "/hospital-by-state",            title: "Hospital by state",                desc: "Per-state hospital count",                              round: "r700+", section: "Geographic" },
];

const SEC_TONE: Record<H["section"], string> = {
  Aggregate:  "text-[var(--color-ok)]",
  Retention:  "text-[var(--color-warn)]",
  Spend:      "text-[var(--color-ok)]",
  Aging:      "text-[var(--color-danger)]",
  Chain:      "text-[var(--color-info)]",
  Geographic: "text-[var(--color-muted)]",
};

export default async function HospitalsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospitals index ★ r1147</h1>
        <span className="text-xs text-[var(--color-muted)]">22nd meta-landing · {SURFACES.length} hospital (demand side) surfaces · 6 sections</span>
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
