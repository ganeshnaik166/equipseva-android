import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";

export const metadata = { title: "Notifications index — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type N = { href: string; title: string; desc: string; round: string; section: "Aggregate" | "Daily" | "Kind" };

const SURFACES: N[] = [
  { href: "/notifications-throughput-30d",     title: "Notifications throughput 30d",     desc: "5 KPIs · sent + read + read % + users + kinds",       round: "r1148", section: "Aggregate" },
  { href: "/notifications-engagement-30d",     title: "Notifications engagement 30d",     desc: "Daily sent/read + unread %",                          round: "r1016", section: "Daily"     },
  { href: "/notifications-by-kind-30d",        title: "Notifications by kind 30d",         desc: "Per-kind sent/read/read-%",                            round: "r1017", section: "Kind"      },
];

const SEC_TONE: Record<N["section"], string> = {
  Aggregate: "text-[var(--color-ok)]",
  Daily:     "text-[var(--color-info)]",
  Kind:      "text-[var(--color-warn)]",
};

export default async function NotificationsIndexPage() {
  await requireFounder();
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Notifications index ★ r1149</h1>
        <span className="text-xs text-[var(--color-muted)]">23rd meta-landing · {SURFACES.length} notification engagement surfaces</span>
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
