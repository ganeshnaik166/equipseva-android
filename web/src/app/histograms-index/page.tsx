import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Histograms index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Hist = { href: string; title: string; desc: string; round: string; axis: "Amount" | "Latency" | "Frequency" };

const HISTS: Hist[] = [
  { href: "/payouts-amount-histogram",          title: "Payouts amount histogram",        desc: "90d processed payouts × 7 amount buckets",          round: "r1048", axis: "Amount"    },
  { href: "/amc-amount-histogram",              title: "AMC amount histogram",             desc: "Active AMCs × 7 amount buckets",                     round: "r1049", axis: "Amount"    },
  { href: "/jobs-completion-latency-histogram", title: "Jobs completion latency histogram", desc: "90d completed × 7 latency buckets",                  round: "r1022", axis: "Latency"   },
];

const AXIS_TONE: Record<Hist["axis"], string> = {
  Amount:    "text-[var(--color-ok)]",
  Latency:   "text-[var(--color-warn)]",
  Frequency: "text-[var(--color-info)]",
};

export default async function HistogramsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Histograms index ★ r1050</h1>
        <span className="text-xs text-[var(--color-muted)]">8th meta-landing · distribution surfaces (Amount/Latency/Frequency)</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {HISTS.map((h) => (
          <Link key={h.href} href={h.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{h.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{h.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{h.desc}</p>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${AXIS_TONE[h.axis]}`}>{h.axis}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
