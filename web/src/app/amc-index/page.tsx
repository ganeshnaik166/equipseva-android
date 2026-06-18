import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "AMC index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type AmcSurface = { href: string; title: string; desc: string; round: string; section: "Structure" | "Lifecycle" | "Pool" | "Revenue" | "Renewal" | "Health" };

const SURFACES: AmcSurface[] = [
  { href: "/amc-tier-current-snapshot",  title: "AMC tier current snapshot",  desc: "Per-tier active/paused/expired + avg INR + MRR",          round: "r1043", section: "Structure"  },
  { href: "/amc-amount-histogram",        title: "AMC amount histogram",       desc: "Active AMCs × 7 amount buckets",                          round: "r1049", section: "Structure"  },
  { href: "/amc-by-equipment-category",   title: "AMC by equipment category",   desc: "Grouped by equipment_categories array",                   round: "r1137", section: "Structure"  },
  { href: "/amc-by-visit-frequency",      title: "AMC by visit frequency",     desc: "Weekly/biweekly/monthly/quarterly cadence",                round: "r1138", section: "Structure"  },
  { href: "/amc-by-renewal-term",         title: "AMC by renewal term",         desc: "By contract length (months)",                             round: "r1139", section: "Structure"  },
  { href: "/amc-paused-by-tier",          title: "AMC paused by tier",          desc: "Frozen MRR per tier",                                     round: "r982",  section: "Health"     },
  { href: "/amc-paused-aging",            title: "AMC paused aging",            desc: "Paused × 6 age buckets × frozen MRR",                     round: "r1055", section: "Health"     },
  { href: "/amc-churn-rate-by-month",     title: "AMC churn rate by month",     desc: "(Expired + newly paused) / Active SOM %",                  round: "r1126", section: "Health"     },
  { href: "/amc-pool-balance-distribution", title: "AMC pool balance distribution", desc: "Active AMCs × 7 current-balance buckets",            round: "r1073", section: "Pool"       },
  { href: "/amc-pool-zero-balance",       title: "AMC pool zero balance",       desc: "Per-tier 0-balance count + blocked MRR",                  round: "r1011", section: "Pool"       },
  { href: "/amc-pool-top-balances",       title: "AMC pool top balances",       desc: "Top 50 active AMCs by pool balance",                      round: "r1075", section: "Pool"       },
  { href: "/amc-pool-bottom-balances",    title: "AMC pool bottom balances",    desc: "Bottom 50 (founder top-up queue)",                        round: "r1076", section: "Pool"       },
  { href: "/amc-pool-burn-rate-by-tier",  title: "AMC pool burn rate × tier",   desc: "Predictive months-to-zero per tier",                      round: "r1031", section: "Pool"       },
  { href: "/amc-pool-net-flow-by-month",  title: "AMC pool net flow by month",  desc: "6mo · credits − debits − refunds",                        round: "r1065", section: "Pool"       },
  { href: "/amc-pool-net-flow-by-week-13wk", title: "AMC pool net flow by week", desc: "13wk weekly grain",                                       round: "r1114", section: "Pool"       },
  { href: "/amc-pool-running-balance",    title: "AMC pool running balance",    desc: "6mo cumulative trajectory",                                round: "r1066", section: "Pool"       },
  { href: "/amc-pool-running-balance-by-week", title: "AMC pool running balance by week", desc: "13wk cumulative",                              round: "r1115", section: "Pool"       },
  { href: "/amc-pool-debits-by-month-by-tier", title: "Pool debits by month × tier", desc: "6mo cross-tab",                                       round: "r983",  section: "Pool"       },
  { href: "/amc-pool-credits-by-month-by-tier", title: "Pool credits by month × tier", desc: "6mo cross-tab",                                     round: "r985",  section: "Pool"       },
  { href: "/amc-pool-debits-by-week-13wk", title: "Pool debits by week 13wk",   desc: "Consumption velocity",                                    round: "r1127", section: "Pool"       },
  { href: "/amc-pool-credits-by-week-13wk", title: "Pool credits by week 13wk", desc: "Top-up velocity",                                          round: "r1128", section: "Pool"       },
  { href: "/amc-contracts-by-month-by-tier", title: "AMC contracts by month × tier", desc: "6mo acquisition cross-tab",                          round: "r971",  section: "Lifecycle"  },
  { href: "/amc-contracts-by-day-30d",    title: "AMC contracts by day 30d",    desc: "Daily new AMCs + MRR added",                              round: "r1038", section: "Lifecycle"  },
  { href: "/amc-contracts-by-week-13wk",  title: "AMC contracts by week 13wk",  desc: "Weekly new AMCs + MRR",                                    round: "r1098", section: "Lifecycle"  },
  { href: "/amc-revenue-by-week-13wk",    title: "AMC revenue by week 13wk",    desc: "Weekly new MRR − expired MRR",                            round: "r1108", section: "Revenue"    },
  { href: "/amc-revenue-projection",      title: "AMC revenue projection",      desc: "Current MRR + 30/90d forward projections",                 round: "r1035", section: "Revenue"    },
  { href: "/amc-renewal-window-30d",      title: "AMC renewal window 30d",      desc: "Renewing in next 30d × tier × MRR at risk",                round: "r991",  section: "Renewal"    },
  { href: "/amc-renewal-window-90d",      title: "AMC renewal window 90d",      desc: "Longer pipeline view",                                     round: "r1084", section: "Renewal"    },
  { href: "/amc-renewal-funnel-90d",      title: "AMC renewal funnel 90d",      desc: "Notify 1→2→3 → renewed/expired",                          round: "r1003", section: "Renewal"    },
  { href: "/amc-renewal-rate-by-month",   title: "AMC renewal rate by month",   desc: "6mo renewed/due %",                                       round: "r1054", section: "Renewal"    },
  { href: "/amc-renewal-rate-by-week",    title: "AMC renewal rate by week",    desc: "13wk renewed/due %",                                       round: "r1118", section: "Renewal"    },
  { href: "/amc-renewal-attempts-by-tier", title: "AMC renewal attempts by tier", desc: "Per-tier 90d outcomes",                                  round: "r977",  section: "Renewal"    },
  { href: "/amc-renewal-attempts-by-month", title: "AMC renewal attempts by month", desc: "12mo × status + success %",                            round: "r1078", section: "Renewal"    },
  { href: "/amc-renewal-attempts-recent",  title: "AMC renewal attempts recent",  desc: "Top 100 live feed with errors",                          round: "r1088", section: "Renewal"    },
];

const SEC_TONE: Record<AmcSurface["section"], string> = {
  Structure: "text-[var(--color-info)]",
  Lifecycle: "text-[var(--color-ok)]",
  Pool:      "text-[var(--color-warn)]",
  Revenue:   "text-[var(--color-ok)]",
  Renewal:   "text-[var(--color-info)]",
  Health:    "text-[var(--color-danger)]",
};

export default async function AmcIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC index ★ r1140</h1>
        <span className="text-xs text-[var(--color-muted)]">15th meta-landing · {SURFACES.length} AMC surfaces grouped by section</span>
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
