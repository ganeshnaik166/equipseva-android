import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Agings index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Agg = { href: string; title: string; desc: string; round: string; sev: "Trust" | "Liquidity" | "Pipeline" | "Engagement" };

const AGINGS: Agg[] = [
  { href: "/payouts-stuck-aging",       title: "Payouts stuck aging",        desc: "Queued/processing payouts × 6 age buckets",            round: "r994",  sev: "Trust"      },
  { href: "/code-red-aging",            title: "Code Red aging",              desc: "Open emergency requests × 6 age buckets",               round: "r995",  sev: "Trust"      },
  { href: "/spare-parts-stuck-aging",   title: "Spare parts stuck aging",     desc: "Paid orders not shipped × age",                          round: "r996",  sev: "Trust"      },
  { href: "/escrow-held-aging",         title: "Escrow held aging",           desc: "Held escrow × age × INR (capital tied up)",              round: "r999",  sev: "Trust"      },
  { href: "/jobs-unassigned-aging",     title: "Jobs unassigned aging",        desc: "Open jobs no engineer × age",                            round: "r997",  sev: "Liquidity"  },
  { href: "/bids-stuck-aging",          title: "Bids stuck aging",             desc: "Undecided bids × age",                                   round: "r998",  sev: "Liquidity"  },
  { href: "/kyc-pending-aging",         title: "KYC pending aging",            desc: "Engineers awaiting verification × age",                  round: "r1012", sev: "Pipeline"   },
  { href: "/dispute-aging",             title: "Dispute aging",                desc: "Submitted disputes × age",                                round: "r613",  sev: "Trust"      },
  { href: "/reviews-pending-aging",     title: "Reviews pending aging",        desc: "Completed jobs no hospital rating × age",                round: "r1009", sev: "Engagement" },
];

const SEV_TONE: Record<Agg["sev"], string> = {
  Trust:      "text-[var(--color-danger)]",
  Liquidity:  "text-[var(--color-warn)]",
  Pipeline:   "text-[var(--color-info)]",
  Engagement: "text-[var(--color-muted)]",
};

export default async function AgingsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Agings index ★ r1027</h1>
        <span className="text-xs text-[var(--color-muted)]">5th meta-landing · 9 aging surfaces grouped by severity domain</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {AGINGS.map((a) => (
          <Link key={a.href} href={a.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{a.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{a.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{a.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${SEV_TONE[a.sev]}`}>{a.sev}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
