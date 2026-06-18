import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "By-week index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type W = { href: string; title: string; desc: string; round: string; domain: "Marketplace" | "Revenue" | "Trust" | "Governance" };

const WEEKLIES: W[] = [
  { href: "/jobs-by-week-13wk",                title: "Jobs by week 13wk",                desc: "Posted + completed + cancelled + bids",                round: "r1099", domain: "Marketplace" },
  { href: "/signups-by-week-13wk",             title: "Signups by week 13wk",              desc: "Engineer + hospital + other splits",                    round: "r1101", domain: "Marketplace" },
  { href: "/spare-part-orders-by-week-13wk",   title: "Spare part orders by week 13wk",    desc: "Orders + paid + delivered + paid GMV",                  round: "r1107", domain: "Marketplace" },
  { href: "/amc-contracts-by-week-13wk",       title: "AMC contracts by week 13wk",        desc: "New AMCs + MRR added + tiers used",                     round: "r1098", domain: "Revenue"     },
  { href: "/amc-revenue-by-week-13wk",         title: "AMC revenue by week 13wk",          desc: "New MRR − expired MRR = net change",                    round: "r1108", domain: "Revenue"     },
  { href: "/commission-by-week-13wk",          title: "Commission by week 13wk",            desc: "Platform-fee invoices + total INR",                      round: "r1109", domain: "Revenue"     },
  { href: "/payouts-by-week-13wk",             title: "Payouts by week 13wk",              desc: "Queued + processed + failed + paid INR",                round: "r1103", domain: "Revenue"     },
  { href: "/code-red-by-week-13wk",            title: "Code Red by week 13wk",              desc: "Total + resolved + timed_out + resolved %",              round: "r1106", domain: "Trust"       },
  { href: "/disputes-by-week-13wk",            title: "Disputes by week 13wk",              desc: "Submitted + resolved + open-EOW",                        round: "r1105", domain: "Trust"       },
  { href: "/audit-by-week",                    title: "Audit by week",                      desc: "Founder ops weekly aggregate",                          round: "r980",  domain: "Governance"  },
  { href: "/audit-success-rate-by-week",       title: "Audit success rate by week",         desc: "Success/fail % weekly trend",                            round: "r1074", domain: "Governance"  },
];

const TONE: Record<W["domain"], string> = {
  Marketplace: "text-[var(--color-info)]",
  Revenue:     "text-[var(--color-ok)]",
  Trust:       "text-[var(--color-danger)]",
  Governance:  "text-[var(--color-warn)]",
};

export default async function ByWeekIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">By-week index ★ r1104 (expanded r1110)</h1>
        <span className="text-xs text-[var(--color-muted)]">13th meta-landing · 11 weekly time-series surfaces grouped by domain</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {WEEKLIES.map((w) => (
          <Link key={w.href} href={w.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{w.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{w.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{w.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${TONE[w.domain]}`}>{w.domain}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
