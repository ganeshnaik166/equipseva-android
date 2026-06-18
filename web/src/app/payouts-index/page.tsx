import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Payouts index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type P = { href: string; title: string; desc: string; round: string; section: "Aggregate" | "Timeseries" | "Diagnostics" | "Leaderboard" | "Distribution" };

const SURFACES: P[] = [
  { href: "/payouts",                          title: "Payouts overview",                desc: "Headline payout cards",                              round: "r460+", section: "Aggregate"   },
  { href: "/payouts-stuck-aging",              title: "Payouts stuck aging",             desc: "Queued/processing × 6 age buckets",                  round: "r994",  section: "Diagnostics" },
  { href: "/payouts-by-bank",                  title: "Payouts by bank",                  desc: "Per-bank success/fail rate",                          round: "r700+", section: "Diagnostics" },
  { href: "/payouts-by-mode",                  title: "Payouts by mode",                  desc: "UPI/IMPS/NEFT/RTGS split",                            round: "r700+", section: "Diagnostics" },
  { href: "/payouts-by-engineer-tier",         title: "Payouts by engineer tier",         desc: "Tier × payout distribution",                          round: "r700+", section: "Distribution" },
  { href: "/payouts-amount-histogram",         title: "Payouts amount histogram",         desc: "90d × 7 amount buckets",                              round: "r1048", section: "Distribution" },
  { href: "/payouts-pending-by-engineer",      title: "Payouts pending by engineer",      desc: "Top 50 engineers · founder unblock queue",            round: "r1077", section: "Leaderboard"  },
  { href: "/failed-payouts-recent",            title: "Failed payouts recent",            desc: "Top 100 recent failures + reason",                    round: "r1032", section: "Diagnostics" },
  { href: "/failed-payouts-by-reason",         title: "Failed payouts by reason",         desc: "Top 50 failure_reason patterns",                      round: "r1033", section: "Diagnostics" },
  { href: "/payout-success-funnel-90d",        title: "Payout success funnel 90d",        desc: "Queued → processed/failed/stuck",                     round: "r1004", section: "Diagnostics" },
  { href: "/payouts-by-month",                 title: "Payouts by month",                 desc: "Monthly grain",                                       round: "r700+", section: "Timeseries"  },
  { href: "/payouts-by-month-by-status",       title: "Payouts by month × status",         desc: "Monthly × status cross-tab",                          round: "r700+", section: "Timeseries"  },
  { href: "/payouts-by-day-trend",             title: "Payouts by day trend",             desc: "Daily grain",                                         round: "r700+", section: "Timeseries"  },
  { href: "/payouts-by-day-of-week",           title: "Payouts by day-of-week",           desc: "Weekday pattern",                                     round: "r700+", section: "Timeseries"  },
  { href: "/payouts-by-week-13wk",             title: "Payouts by week 13wk",             desc: "Weekly grain · queued/processed/failed/INR",          round: "r1103", section: "Timeseries"  },
  { href: "/payouts-by-hour-7d",               title: "Payouts by hour 7d",                desc: "24 IST hour distribution",                            round: "r1087", section: "Timeseries"  },
  { href: "/payouts-cumulative",               title: "Payouts cumulative",               desc: "12mo monthly + cumulative",                           round: "r1068", section: "Timeseries"  },
  { href: "/payouts-success-rate-by-week",     title: "Payouts success rate by week",     desc: "13wk · processed/queued % · target ≥95%",             round: "r1117", section: "Aggregate"   },
];

const SEC_TONE: Record<P["section"], string> = {
  Aggregate:    "text-[var(--color-ok)]",
  Timeseries:   "text-[var(--color-info)]",
  Diagnostics:  "text-[var(--color-danger)]",
  Leaderboard:  "text-[var(--color-warn)]",
  Distribution: "text-[var(--color-muted)]",
};

export default async function PayoutsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Payouts index ★ r1141</h1>
        <span className="text-xs text-[var(--color-muted)]">16th meta-landing · {SURFACES.length} payout surfaces grouped by section</span>
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
