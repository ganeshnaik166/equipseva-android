import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Hospitals with no AMC — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_hospitals: number;
  with_no_amc: number;
  with_no_amc_pct: number;
  with_active_amc: number;
  with_only_expired_amc: number;
  with_only_paused_amc: number;
};

function Card({ title, val, sub, danger }: { title: string; val: string; sub?: string; danger?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function HospitalsWithNoAmcPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospitals_with_no_amc");
  if (error) throw new Error(`founder_hospitals_with_no_amc: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospitals with no AMC</h1>
        <span className="text-xs text-[var(--color-muted)]">Conversion gap · hospitals signed up but no AMC contract · upsell target</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-3">
          <Card title="Total hospitals" val={formatNumber(r.total_hospitals)} />
          <Card title="With no AMC ever" val={formatNumber(r.with_no_amc)} sub={formatPct(r.with_no_amc_pct / 100)} danger={r.with_no_amc_pct > 50} />
          <Card title="With active AMC" val={formatNumber(r.with_active_amc)} />
          <Card title="With only expired AMC" val={formatNumber(r.with_only_expired_amc)} sub="churned" />
          <Card title="With only paused AMC" val={formatNumber(r.with_only_paused_amc)} sub="reactivation candidate" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
