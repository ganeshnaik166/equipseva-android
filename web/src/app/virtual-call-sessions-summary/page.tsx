import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Virtual call sessions summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  created_today: number;
  created_7d: number;
  created_30d: number;
  answered_30d: number;
  failed_30d: number;
  released_30d: number;
  answer_rate_pct_30d: number;
  fail_rate_pct_30d: number;
  avg_call_count_30d: number;
  high_call_count_30d: number;
  active_engineers_30d: number;
};

function Kpi({ label, value, tone }: { label: string; value: string; tone?: "ok" | "warn" | "danger" }) {
  const color =
    tone === "ok" ? "text-[var(--color-ok)]" :
    tone === "warn" ? "text-[var(--color-warn)]" :
    tone === "danger" ? "text-[var(--color-danger)]" : "";
  return (
    <div className="rounded border border-[var(--color-border)] p-3">
      <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-lg font-semibold tabular-nums ${color}`}>{value}</div>
    </div>
  );
}

export default async function VirtualCallSessionsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_virtual_call_sessions_summary");
  if (error) throw new Error(`founder_virtual_call_sessions_summary: ${error.message}`);
  const r = ((data ?? [])[0] ?? {}) as Row;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Virtual call sessions summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Exotel click-to-call bridge health · anti-disintermediation moat · 30d window
        </span>
      </header>
      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 lg:grid-cols-4">
        <Kpi label="Total all time" value={formatNumber(Number(r.total_all_time ?? 0))} />
        <Kpi label="Created today" value={formatNumber(Number(r.created_today ?? 0))} />
        <Kpi label="Created 7d" value={formatNumber(Number(r.created_7d ?? 0))} />
        <Kpi label="Created 30d" value={formatNumber(Number(r.created_30d ?? 0))} />
        <Kpi label="Answered 30d" value={formatNumber(Number(r.answered_30d ?? 0))} tone="ok" />
        <Kpi label="Failed 30d" value={formatNumber(Number(r.failed_30d ?? 0))} tone="danger" />
        <Kpi label="Released 30d" value={formatNumber(Number(r.released_30d ?? 0))} />
        <Kpi label="Answer rate 30d" value={`${Number(r.answer_rate_pct_30d ?? 0).toFixed(1)}%`} tone="ok" />
        <Kpi label="Fail rate 30d" value={`${Number(r.fail_rate_pct_30d ?? 0).toFixed(1)}%`} tone="danger" />
        <Kpi label="Avg calls/session 30d" value={Number(r.avg_call_count_30d ?? 0).toFixed(2)} />
        <Kpi label="High call-count (>=10) 30d" value={formatNumber(Number(r.high_call_count_30d ?? 0))} tone="warn" />
        <Kpi label="Active engineers 30d" value={formatNumber(Number(r.active_engineers_30d ?? 0))} />
      </div>
      <p className="text-xs text-[var(--color-muted)]">
        Note: sessions table has no per-call duration column (Exotel click-to-call is stateless).
        High call-count rows (&ge;10 per session) are the abuse-detection signal for circumvention attempts.
      </p>
    </div>
  );
}
