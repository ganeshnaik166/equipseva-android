import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Engineers no-jobs activation leak — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_engineers: number;
  no_jobs_30d: number;
  no_jobs_30d_pct: number;
  no_jobs_60d: number;
  no_jobs_60d_pct: number;
  no_jobs_90d: number;
  no_jobs_90d_pct: number;
  never_had_a_job: number;
  never_had_a_job_pct: number;
};

function Card({ title, count, pct, danger }: { title: string; count: number; pct: number; danger?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ""}`}>{formatNumber(count)}</div>
      <div className="text-xs tabular-nums text-[var(--color-muted)]">{formatPct(pct / 100)}</div>
    </div>
  );
}

export default async function EngineersNoJobsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineers_no_jobs_30d");
  if (error) throw new Error(`founder_engineers_no_jobs_30d: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer activation leak</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Total engineers: <span className="font-mono tabular-nums">{formatNumber(r?.total_engineers ?? 0)}</span>
        </span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="No completed job in 30d" count={r.no_jobs_30d} pct={r.no_jobs_30d_pct} />
          <Card title="No completed job in 60d" count={r.no_jobs_60d} pct={r.no_jobs_60d_pct} />
          <Card title="No completed job in 90d" count={r.no_jobs_90d} pct={r.no_jobs_90d_pct} danger />
          <Card title="Never completed a job" count={r.never_had_a_job} pct={r.never_had_a_job_pct} danger />
        </div>
      ) : (
        <p className="text-sm text-[var(--color-muted)]">No engineer data.</p>
      )}
    </div>
  );
}
