import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Engineers index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type E = { href: string; title: string; desc: string; round: string; section: "Aggregate" | "Tier" | "Retention" | "Earnings" | "Aging" | "Quality" | "Geographic" };

const SURFACES: E[] = [
  { href: "/signups",                        title: "Engineer signups overview",     desc: "Funnel + DAU/WAU/MAU",                              round: "r608+", section: "Aggregate"  },
  { href: "/tiers",                          title: "Engineer tiers",                desc: "Tier distribution + threshold",                     round: "r550+", section: "Tier"       },
  { href: "/tier-history",                   title: "Tier history",                  desc: "Promotion/demotion ledger",                          round: "r593+", section: "Tier"       },
  { href: "/tier-distribution-trend",        title: "Tier distribution trend",       desc: "Current + 30d delta",                                round: "r632",  section: "Tier"       },
  { href: "/tier-distribution-by-city",      title: "Tier distribution by city",     desc: "Top 50 cities × tier mix",                           round: "r898",  section: "Geographic" },
  { href: "/tier-climbers",                  title: "Tier climbers",                 desc: "Engineers close to promotion",                       round: "r676",  section: "Tier"       },
  { href: "/tier-changes-by-day-30d",        title: "Tier changes by day 30d",       desc: "Daily promotions vs demotions",                      round: "r1083", section: "Tier"       },
  { href: "/tier-changes-by-month",          title: "Tier changes by month",         desc: "Monthly tier change volume",                          round: "r704",  section: "Tier"       },
  { href: "/tier-changes-cumulative",        title: "Tier changes cumulative",       desc: "Cumulative tier event count",                         round: "r700+", section: "Tier"       },
  { href: "/tier-promotion-rate-by-month",   title: "Tier promotion rate by month",  desc: "12mo promotion/active engineer %",                    round: "r1125", section: "Quality"    },
  { href: "/engineers-no-jobs-30d",          title: "Engineer activation leak",      desc: "Engineers w/ 0 jobs 30/60/90d/never",                round: "r992",  section: "Aging"      },
  { href: "/engineer-suspension-aging",      title: "Engineer suspension aging",     desc: "Cash-suspended engineers × age buckets",             round: "r1056", section: "Aging"      },
  { href: "/kyc-pending-aging",              title: "KYC pending aging",             desc: "Engineers awaiting verification × age",              round: "r1012", section: "Aging"      },
  { href: "/engineer-cohort-retention",      title: "Engineer cohort retention",     desc: "12mo signup cohorts × 30/60/90/180d active %",       round: "r1051", section: "Retention"  },
  { href: "/engineer-onboarding-funnel",     title: "Engineer onboarding funnel",    desc: "Signup → profile → verified → 1st bid → 1st payout", round: "r1005", section: "Retention"  },
  { href: "/engineer-leaderboard-30d",       title: "Engineer leaderboard 30d",      desc: "Top 50 by jobs done + earnings",                     round: "r1024", section: "Aggregate"  },
  { href: "/engineer-earnings-distribution", title: "Engineer earnings distribution", desc: "90d earnings per engineer × 7 amount buckets",       round: "r1131", section: "Earnings"   },
  { href: "/founder-engineer-profile-completeness", title: "Engineer profile completeness", desc: "Bio/rate/city/specs/phone/avatar coverage",   round: "r620",  section: "Quality"    },
  { href: "/payouts-pending-by-engineer",    title: "Payouts pending by engineer",   desc: "Top 50 engineers · unblock queue",                   round: "r1077", section: "Earnings"   },
];

const SEC_TONE: Record<E["section"], string> = {
  Aggregate:  "text-[var(--color-ok)]",
  Tier:       "text-[var(--color-info)]",
  Retention:  "text-[var(--color-warn)]",
  Earnings:   "text-[var(--color-ok)]",
  Aging:      "text-[var(--color-danger)]",
  Quality:    "text-[var(--color-info)]",
  Geographic: "text-[var(--color-muted)]",
};

export default async function EngineersIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineers index ★ r1146</h1>
        <span className="text-xs text-[var(--color-muted)]">21st meta-landing · {SURFACES.length} engineer (supply side) surfaces · 7 sections</span>
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
