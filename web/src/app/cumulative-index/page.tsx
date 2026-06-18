import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Cumulative index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type C = { href: string; title: string; domain: "Revenue" | "Trust" | "Volume" | "Quality" | "Growth"; round?: string };

const CUMS: C[] = [
  { href: "/amc-revenue-cumulative",       title: "AMC revenue cumulative",       domain: "Revenue", round: "r700+" },
  { href: "/platform-fee-cumulative",      title: "Platform fee cumulative",      domain: "Revenue", round: "r1067" },
  { href: "/gmv-cumulative",               title: "GMV cumulative",                domain: "Revenue", round: "r700+" },
  { href: "/commission-cumulative",        title: "Commission cumulative",         domain: "Revenue", round: "r700+" },
  { href: "/payouts-cumulative",           title: "Payouts cumulative",            domain: "Trust",   round: "r1068" },
  { href: "/escrow-cumulative",            title: "Escrow cumulative",             domain: "Trust",   round: "r700+" },
  { href: "/code-red-cumulative",          title: "Code Red cumulative",           domain: "Trust",   round: "r700+" },
  { href: "/disputes-cumulative",          title: "Disputes cumulative",           domain: "Trust",   round: "r700+" },
  { href: "/jobs-completed-cumulative",    title: "Jobs completed cumulative",     domain: "Volume",  round: "r1071" },
  { href: "/signups-cumulative",           title: "Signups cumulative",            domain: "Volume",  round: "r700+" },
  { href: "/spot-audits-cumulative",       title: "Spot audits cumulative",        domain: "Quality", round: "r700+" },
  { href: "/supervised-cumulative",        title: "Supervised cumulative",         domain: "Quality", round: "r700+" },
  { href: "/tier-changes-cumulative",      title: "Tier changes cumulative",       domain: "Quality", round: "r700+" },
  { href: "/referrals-cumulative",         title: "Referrals cumulative",          domain: "Growth",  round: "r700+" },
  { href: "/demand-signals-cumulative",    title: "Demand signals cumulative",     domain: "Growth",  round: "r700+" },
  { href: "/bonded-intake-cumulative",     title: "Bonded intake cumulative",      domain: "Quality", round: "r700+" },
];

const TONE: Record<C["domain"], string> = {
  Revenue: "text-[var(--color-ok)]",
  Trust:   "text-[var(--color-danger)]",
  Volume:  "text-[var(--color-info)]",
  Quality: "text-[var(--color-warn)]",
  Growth:  "text-[var(--color-muted)]",
};

export default async function CumulativeIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Cumulative index ★ r1072</h1>
        <span className="text-xs text-[var(--color-muted)]">12th meta-landing · 16 cumulative running-total surfaces by domain</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {CUMS.map((c) => (
          <Link key={c.href} href={c.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{c.title}</h3>
              {c.round ? <span className="text-xs font-mono text-[var(--color-muted)]">{c.round}</span> : null}
            </div>
            <span className={`mt-2 inline-block text-[10px] font-medium uppercase tracking-wider ${TONE[c.domain]}`}>{c.domain}</span>
          </Link>
        ))}
      </div>
    </div>
  );
}
