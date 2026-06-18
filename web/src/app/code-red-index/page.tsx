import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Code Red index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type CR = { href: string; title: string; desc: string; round: string; section: "Aggregate" | "Timeseries" | "SLA" | "Aging" | "Leaderboard" };

const SURFACES: CR[] = [
  { href: "/code-red-sla",                    title: "Code Red SLA",                    desc: "7d/30d/90d resolved vs timed_out",                      round: "r622",  section: "SLA"         },
  { href: "/code-red-volume-trend",           title: "Code Red volume trend",           desc: "Volume across windows",                                 round: "r669",  section: "Aggregate"   },
  { href: "/code-red-by-month",               title: "Code Red by month",                desc: "Monthly grain",                                         round: "r702",  section: "Timeseries"  },
  { href: "/code-red-by-month-by-status",     title: "Code Red by month × status",       desc: "12mo cross-tab",                                       round: "r969",  section: "Timeseries"  },
  { href: "/code-red-by-day-30d",             title: "Code Red by day 30d",              desc: "Daily volume + resolved %",                              round: "r1037", section: "Timeseries"  },
  { href: "/code-red-by-week-13wk",           title: "Code Red by week 13wk",            desc: "Weekly grain",                                          round: "r1106", section: "Timeseries"  },
  { href: "/code-red-by-hour-7d",             title: "Code Red by hour 7d",              desc: "24 IST hour distribution",                              round: "r1086", section: "Timeseries"  },
  { href: "/code-red-cumulative",             title: "Code Red cumulative",              desc: "Cumulative running total",                              round: "r700+", section: "Aggregate"   },
  { href: "/code-red-aging",                  title: "Code Red aging",                   desc: "Open emergency requests × 6 age buckets",                round: "r995",  section: "Aging"       },
  { href: "/code-red-resolution-funnel-30d",  title: "Code Red resolution funnel 30d",   desc: "Created → accepted → resolved + tails",                  round: "r1111", section: "SLA"         },
  { href: "/code-red-resolution-rate-by-week", title: "Code Red resolution rate by week", desc: "13wk · resolved/total %",                                round: "r1119", section: "SLA"         },
  { href: "/code-red-by-engineer-90d",        title: "Code Red by engineer 90d",         desc: "Top 50 responders",                                      round: "r1135", section: "Leaderboard" },
];

const SEC_TONE: Record<CR["section"], string> = {
  Aggregate:    "text-[var(--color-ok)]",
  Timeseries:   "text-[var(--color-info)]",
  SLA:          "text-[var(--color-danger)]",
  Aging:        "text-[var(--color-warn)]",
  Leaderboard:  "text-[var(--color-muted)]",
};

export default async function CodeRedIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Code Red index ★ r1142</h1>
        <span className="text-xs text-[var(--color-muted)]">17th meta-landing · {SURFACES.length} Code Red surfaces grouped by section · life-safety lane</span>
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
