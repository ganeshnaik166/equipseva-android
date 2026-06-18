import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber, formatPct } from "@/lib/format";

export const metadata = { title: "Hospitals no-jobs activation leak — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_hospitals: number;
  no_jobs_30d: number;
  no_jobs_30d_pct: number;
  no_jobs_60d: number;
  no_jobs_60d_pct: number;
  no_jobs_90d: number;
  no_jobs_90d_pct: number;
  never_posted_a_job: number;
  never_posted_a_job_pct: number;
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

export default async function HospitalsNoJobsPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_hospitals_no_jobs_30d");
  if (error) throw new Error(`founder_hospitals_no_jobs_30d: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Hospital activation leak</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Total hospitals: <span className="font-mono tabular-nums">{formatNumber(r?.total_hospitals ?? 0)}</span> · demand-side mirror of /engineers-no-jobs-30d
        </span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="No posted job in 30d" count={r.no_jobs_30d} pct={r.no_jobs_30d_pct} />
          <Card title="No posted job in 60d" count={r.no_jobs_60d} pct={r.no_jobs_60d_pct} />
          <Card title="No posted job in 90d" count={r.no_jobs_90d} pct={r.no_jobs_90d_pct} danger />
          <Card title="Never posted a job" count={r.never_posted_a_job} pct={r.never_posted_a_job_pct} danger />
        </div>
      ) : (
        <p className="text-sm text-[var(--color-muted)]">No hospital data.</p>
      )}
    </div>
  );
}
