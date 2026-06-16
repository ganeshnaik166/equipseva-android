import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Platform pulse — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { metric: string; value_text: string; value_numeric: number; ord: number };

function inr(v: number) {
  return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR", maximumFractionDigits: 0 }).format(v);
}

const RUPEE_METRICS = new Set([
  "Total MRR",
  "GMV (30d)",
  "Engineer payouts (30d)",
  "Live escrow balance",
]);

export default async function PlatformPulsePage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_platform_pulse");
  if (error) throw new Error(`founder_platform_pulse: ${error.message}`);
  const rows = (data ?? []) as Row[];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Platform pulse</h1>
        <span className="text-xs text-[var(--color-muted)]">r700 milestone · executive snapshot</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-4">
          {rows.map((r) => {
            const isRupee = RUPEE_METRICS.has(r.metric);
            const display = isRupee ? inr(Number(r.value_numeric)) : formatNumber(Number(r.value_numeric));
            return <StatCard key={r.metric} label={r.metric} value={display} />;
          })}
        </div>
      </section>
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        <strong>r700 milestone.</strong> Twelve at-a-glance numbers for founder
        situational awareness. All values computed at request time via SECDEF
        RPC. For deeper analytics, browse the full <a href="/ops-index" className="underline">ops-index</a>.
      </section>
    </div>
  );
}
