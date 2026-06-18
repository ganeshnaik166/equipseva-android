import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Jobs index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type J = { href: string; title: string; desc: string; round: string; section: "Aggregate" | "Timeseries" | "Latency" | "Aging" | "Equipment" | "Funnel" | "Rate" };

const SURFACES: J[] = [
  { href: "/jobs",                                  title: "Jobs overview",                       desc: "Headline job cards",                            round: "r500+", section: "Aggregate"  },
  { href: "/jobs/list",                              title: "Jobs list",                           desc: "Full job list with filters",                    round: "r510",  section: "Aggregate"  },
  { href: "/jobs-by-month",                          title: "Jobs by month",                       desc: "Monthly grain",                                 round: "r700+", section: "Timeseries" },
  { href: "/jobs-by-day-30d",                        title: "Jobs by day 30d",                     desc: "Daily posted/completed/cancelled + bids",        round: "r1039", section: "Timeseries" },
  { href: "/jobs-by-week-13wk",                      title: "Jobs by week 13wk",                   desc: "Weekly grain",                                  round: "r1099", section: "Timeseries" },
  { href: "/jobs-by-hour-7d",                        title: "Jobs by hour 7d",                     desc: "24 IST hour distribution",                       round: "r1058", section: "Timeseries" },
  { href: "/jobs-completion-rate-by-week",           title: "Jobs completion rate by week",        desc: "13wk · completed/posted %",                      round: "r1116", section: "Rate"       },
  { href: "/jobs-cancellation-rate-by-week",         title: "Jobs cancellation rate by week",      desc: "13wk · cancelled/posted %",                      round: "r1121", section: "Rate"       },
  { href: "/jobs-fill-rate",                         title: "Jobs fill rate",                       desc: "% got bid within 7d",                           round: "r794",  section: "Rate"       },
  { href: "/jobs-completion-by-equipment",           title: "Jobs completion by equipment",         desc: "Equipment-type breakdown",                       round: "r700+", section: "Equipment"  },
  { href: "/jobs-completion-by-tier",                title: "Jobs completion by tier",              desc: "Engineer tier breakdown",                        round: "r700+", section: "Equipment"  },
  { href: "/equipment-type-breakdown",               title: "Equipment type breakdown",             desc: "90d jobs by equipment_type top 50",              round: "r1008", section: "Equipment"  },
  { href: "/jobs-completion-latency-histogram",      title: "Jobs completion latency histogram",    desc: "90d completed × 7 latency buckets",              round: "r1022", section: "Latency"    },
  { href: "/jobs-time-to-complete",                  title: "Jobs time-to-complete",                desc: "Posted → completed p50/p90 hours",               round: "r795",  section: "Latency"    },
  { href: "/first-bid-latency",                      title: "First bid latency",                    desc: "Median + p90 first-bid latency",                 round: "r700+", section: "Latency"    },
  { href: "/first-bid-latency-distribution",         title: "First-bid latency distribution",       desc: "90d × 6 buckets post→1st-bid",                    round: "r1091", section: "Latency"    },
  { href: "/bid-latency",                            title: "Bid latency",                          desc: "Bid response time stats",                        round: "r700+", section: "Latency"    },
  { href: "/bids-per-job-distribution",              title: "Bids per job distribution",            desc: "90d jobs × 6 bid-count buckets",                  round: "r1092", section: "Aggregate"  },
  { href: "/jobs-unassigned-aging",                  title: "Jobs unassigned aging",                desc: "Open jobs no engineer × age",                   round: "r997",  section: "Aging"      },
  { href: "/bids-stuck-aging",                       title: "Bids stuck aging",                     desc: "Undecided bids × age",                          round: "r998",  section: "Aging"      },
  { href: "/repair-job-funnel-30d",                  title: "Repair job funnel 30d",                desc: "Posted → bid → assigned → completed + cancelled", round: "r1047", section: "Funnel"     },
  { href: "/bid-acceptance-funnel-30d",              title: "Bid acceptance funnel 30d",            desc: "Submitted → accepted → completed + tails",        round: "r1045", section: "Funnel"     },
  { href: "/jobs-completed-cumulative",              title: "Jobs completed cumulative",            desc: "12mo cumulative completed",                     round: "r1071", section: "Aggregate"  },
];

const SEC_TONE: Record<J["section"], string> = {
  Aggregate:  "text-[var(--color-ok)]",
  Timeseries: "text-[var(--color-info)]",
  Latency:    "text-[var(--color-warn)]",
  Aging:      "text-[var(--color-danger)]",
  Equipment:  "text-[var(--color-muted)]",
  Funnel:     "text-[var(--color-info)]",
  Rate:       "text-[var(--color-ok)]",
};

export default async function JobsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs index ★ r1145</h1>
        <span className="text-xs text-[var(--color-muted)]">20th meta-landing · {SURFACES.length} repair-job surfaces · core marketplace lane</span>
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
