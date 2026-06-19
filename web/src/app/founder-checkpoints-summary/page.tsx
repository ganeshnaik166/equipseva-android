import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder checkpoints summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  days_since_launch: number;
  first_signup_at: string | null;
  lifetime_jobs_completed: number;
  first_job_completed_at: string | null;
  last_job_completed_at: string | null;
  lifetime_amc_signed: number;
  first_amc_signed_at: string | null;
  last_amc_signed_at: string | null;
  lifetime_payouts_processed: number;
  first_payout_at: string | null;
  last_payout_at: string | null;
  founder_actions_total: number;
  founder_actions_7d: number;
  founder_actions_30d: number;
  distinct_ops_30d: number;
  last_founder_action_at: string | null;
};

function fmtTs(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toLocaleString("en-IN", { timeZone: "Asia/Kolkata", dateStyle: "medium", timeStyle: "short" });
  } catch {
    return s;
  }
}

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function FounderCheckpointsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_founder_checkpoints_summary");
  if (error) throw new Error(`founder_founder_checkpoints_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Founder checkpoints summary</h1>
        <span className="text-xs text-[var(--color-muted)]">16-KPI release/activity timeline · 377 ships r797→r1170 · tags v0.4-day-5-r1145-350ships, v0.4-day-5-r1168-375ships</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Days since launch" val={formatNumber(r.days_since_launch)} sub={fmtTs(r.first_signup_at)} ok />
          <Card title="First signup" val={fmtTs(r.first_signup_at)} sub="cohort zero" />
          <Card title="Lifetime jobs completed" val={formatNumber(r.lifetime_jobs_completed)} ok />
          <Card title="First job completed" val={fmtTs(r.first_job_completed_at)} sub="revenue genesis" />
          <Card title="Latest job completed" val={fmtTs(r.last_job_completed_at)} sub="ops liveness" />
          <Card title="Lifetime AMCs signed" val={formatNumber(r.lifetime_amc_signed)} ok />
          <Card title="First AMC signed" val={fmtTs(r.first_amc_signed_at)} />
          <Card title="Latest AMC signed" val={fmtTs(r.last_amc_signed_at)} />
          <Card title="Lifetime payouts processed" val={formatNumber(r.lifetime_payouts_processed)} ok />
          <Card title="First payout" val={fmtTs(r.first_payout_at)} sub="rail unlocked" />
          <Card title="Latest payout" val={fmtTs(r.last_payout_at)} sub="rail liveness" />
          <Card title="Founder actions total" val={formatNumber(r.founder_actions_total)} />
          <Card title="Founder actions 7d" val={formatNumber(r.founder_actions_7d)} sub="recent activity" />
          <Card title="Founder actions 30d" val={formatNumber(r.founder_actions_30d)} />
          <Card title="Distinct ops 30d" val={formatNumber(r.distinct_ops_30d)} sub="op coverage" />
          <Card title="Last founder action" val={fmtTs(r.last_founder_action_at)} sub="last admin push" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
