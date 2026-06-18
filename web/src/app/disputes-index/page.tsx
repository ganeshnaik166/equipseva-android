import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Disputes index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type D = { href: string; title: string; desc: string; round: string; section: "Aggregate" | "Timeseries" | "Latency" | "Aging" | "Outcome" };

const SURFACES: D[] = [
  { href: "/disputes",                            title: "Disputes overview",                desc: "Headline dispute cards",                                 round: "r495+", section: "Aggregate"  },
  { href: "/dispute-aging",                       title: "Dispute aging",                    desc: "Submitted disputes × age buckets",                       round: "r613",  section: "Aging"      },
  { href: "/dispute-resolution-latency",          title: "Dispute resolution latency",       desc: "7d/30d/90d avg + p50 + p90 hours",                       round: "r648",  section: "Latency"    },
  { href: "/dispute-resolution-rate",             title: "Dispute resolution rate",          desc: "Resolution rate aggregate",                              round: "r700+", section: "Aggregate"  },
  { href: "/dispute-outcomes",                    title: "Dispute outcomes",                  desc: "Accepted vs rejected breakdown",                          round: "r700+", section: "Outcome"    },
  { href: "/dispute-by-mediator",                 title: "Dispute by mediator",              desc: "Per-mediator load + outcomes",                            round: "r700+", section: "Outcome"    },
  { href: "/disputes-by-month",                   title: "Disputes by month",                desc: "Monthly grain",                                          round: "r700+", section: "Timeseries" },
  { href: "/disputes-by-month-by-status",         title: "Disputes by month × status",       desc: "12mo cross-tab",                                         round: "r974",  section: "Timeseries" },
  { href: "/disputes-by-week",                    title: "Disputes by week",                 desc: "Weekly grain",                                           round: "r700+", section: "Timeseries" },
  { href: "/disputes-by-week-13wk",               title: "Disputes by week 13wk",            desc: "Submitted + resolved + open-EOW",                        round: "r1105", section: "Timeseries" },
  { href: "/disputes-by-day-30d",                 title: "Disputes by day 30d",              desc: "Daily submitted + resolved + open-EOD",                  round: "r1079", section: "Timeseries" },
  { href: "/disputes-cumulative",                 title: "Disputes cumulative",              desc: "Cumulative running total",                               round: "r700+", section: "Aggregate"  },
  { href: "/disputes-resolution-time-distribution", title: "Dispute resolution time distribution", desc: "90d resolved × 6 latency buckets",                   round: "r1090", section: "Latency"    },
];

const SEC_TONE: Record<D["section"], string> = {
  Aggregate:  "text-[var(--color-ok)]",
  Timeseries: "text-[var(--color-info)]",
  Latency:    "text-[var(--color-warn)]",
  Aging:      "text-[var(--color-danger)]",
  Outcome:    "text-[var(--color-muted)]",
};

export default async function DisputesIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Disputes index ★ r1143</h1>
        <span className="text-xs text-[var(--color-muted)]">18th meta-landing · {SURFACES.length} dispute lane surfaces grouped by section</span>
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
