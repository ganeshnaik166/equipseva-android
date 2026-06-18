import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Spare parts index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type S = { href: string; title: string; desc: string; round: string; section: "Aggregate" | "Timeseries" | "Aging" | "Leaderboard" | "Geographic" };

const SURFACES: S[] = [
  { href: "/spare-part-orders-recent",            title: "Spare part orders recent",         desc: "Top 100 recent orders feed",                            round: "r911",  section: "Aggregate"   },
  { href: "/spare-parts-by-month",                title: "Spare parts by month",             desc: "Monthly grain",                                         round: "r700+", section: "Timeseries"  },
  { href: "/spare-parts-by-month-by-status",      title: "Spare parts by month × status",     desc: "12mo payment-status cross-tab",                          round: "r978",  section: "Timeseries"  },
  { href: "/spare-parts-by-status",               title: "Spare parts by status",            desc: "Aggregate status breakdown",                            round: "r700+", section: "Aggregate"   },
  { href: "/spare-part-orders-by-day-30d",        title: "Spare part orders by day 30d",     desc: "Daily orders + paid + shipped + delivered + GMV",        round: "r1080", section: "Timeseries"  },
  { href: "/spare-part-orders-by-week-13wk",      title: "Spare part orders by week 13wk",   desc: "Weekly orders + GMV",                                    round: "r1107", section: "Timeseries"  },
  { href: "/spare-parts-stuck-aging",             title: "Spare parts stuck aging",          desc: "Paid orders not shipped × age × INR",                    round: "r996",  section: "Aging"       },
  { href: "/spare-parts-delivery-rate-by-week",   title: "Spare parts delivery rate by week", desc: "13wk delivered/paid %",                                  round: "r1122", section: "Aggregate"   },
  { href: "/spare-part-order-funnel-30d",         title: "Spare part order funnel 30d",       desc: "Created → paid → shipped → delivered + tails",            round: "r1046", section: "Aggregate"   },
  { href: "/spare-parts-by-supplier-30d",         title: "Spare parts by supplier 30d",       desc: "Top 50 suppliers · orders + GMV",                        round: "r1023", section: "Leaderboard" },
  { href: "/spare-parts-buyer-mix",               title: "Spare parts buyer mix",             desc: "Buyer concentration",                                   round: "r700+", section: "Leaderboard" },
  { href: "/spare-parts-by-state",                title: "Spare parts by state",              desc: "Per-state spare parts demand",                          round: "r700+", section: "Geographic"  },
];

const SEC_TONE: Record<S["section"], string> = {
  Aggregate:   "text-[var(--color-ok)]",
  Timeseries:  "text-[var(--color-info)]",
  Aging:       "text-[var(--color-danger)]",
  Leaderboard: "text-[var(--color-warn)]",
  Geographic:  "text-[var(--color-muted)]",
};

export default async function SparePartsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Spare parts index ★ r1144</h1>
        <span className="text-xs text-[var(--color-muted)]">19th meta-landing · {SURFACES.length} spare-parts surfaces · marketplace inventory lane</span>
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
