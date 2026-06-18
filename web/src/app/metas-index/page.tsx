import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Metas index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Meta = { href: string; title: string; desc: string; round: string; emoji: string };

const METAS: Meta[] = [
  { href: "/critical-cockpit",  title: "Critical cockpit ★",      desc: "14-tile founder cockpit (aging/leak signals)",       round: "r1000",  emoji: "🎯" },
  { href: "/cross-tabs-index",  title: "Cross-tabs index",         desc: "11 month × status / month × tier surfaces",          round: "r976",   emoji: "📊" },
  { href: "/funnels-index",     title: "Funnels index",            desc: "8 multi-stage funnels (renewal/payout/onboarding)",   round: "r1010",  emoji: "🔻" },
  { href: "/leaderboards-index", title: "Leaderboards index",      desc: "Supply/Demand/Seller leaderboards",                   round: "r1026",  emoji: "🏆" },
  { href: "/agings-index",      title: "Agings index",             desc: "9 aging surfaces × 4 severity domains",               round: "r1027",  emoji: "⏰" },
  { href: "/coverage-index",    title: "Coverage index",           desc: "7 geographic + chain coverage surfaces",              round: "r1030",  emoji: "🗺️" },
  { href: "/by-day-index",      title: "By-day index",             desc: "6 daily time-series surfaces",                        round: "r1040",  emoji: "📅" },
  { href: "/histograms-index",  title: "Histograms index",         desc: "Distribution surfaces by amount/latency",             round: "r1050",  emoji: "📈" },
  { href: "/retention-index",   title: "Retention index",          desc: "Cohort retention + activation leak (supply+demand)",  round: "r1053",  emoji: "🔄" },
  { href: "/by-hour-index",     title: "By-hour index",            desc: "24 IST hour-of-day distribution surfaces",            round: "r1059",  emoji: "🕐" },
  { href: "/events-index",      title: "Events index",             desc: "Live event feed surfaces (Money/Governance/Marketplace/Trust)", round: "r1062", emoji: "📋" },
  { href: "/cumulative-index",  title: "Cumulative index",         desc: "16 cumulative running-total surfaces by domain",        round: "r1072", emoji: "📊" },
  { href: "/by-week-index",     title: "By-week index",            desc: "11 weekly time-series surfaces (13wk grain)",            round: "r1104", emoji: "📆" },
  { href: "/rates-index",       title: "Rates index",              desc: "Conversion/success-rate surfaces by domain",            round: "r1120", emoji: "📐" },
  { href: "/amc-index",         title: "AMC index",                desc: "34 AMC surfaces grouped by Structure/Lifecycle/Pool/Revenue/Renewal/Health", round: "r1140", emoji: "🏥" },
];

export default async function MetasIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Metas index ★ r1041</h1>
        <span className="text-xs text-[var(--color-muted)]">Meta-of-metas · 7 founder console navigation root pages</span>
      </header>
      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {METAS.map((m) => (
          <Link key={m.href} href={m.href}
            className="block rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 transition hover:border-[var(--color-accent)]">
            <div className="flex items-baseline justify-between">
              <h3 className="text-sm font-semibold">{m.emoji} {m.title}</h3>
              <span className="text-xs font-mono text-[var(--color-muted)]">{m.round}</span>
            </div>
            <p className="mt-1 text-xs text-[var(--color-muted)]">{m.desc}</p>
          </Link>
        ))}
      </div>
      <p className="text-xs text-[var(--color-muted)] pt-4">
        Each meta-landing groups ~5-15 specific surfaces by domain. From any meta, click through to specific drill-downs.
        All 7 metas are reachable from /ops-index (the alphabetical full directory of ~250 surfaces).
      </p>
    </div>
  );
}
