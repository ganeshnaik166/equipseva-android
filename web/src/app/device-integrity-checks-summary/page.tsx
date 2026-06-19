import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Device integrity checks summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_all_time: number;
  checks_24h: number;
  checks_7d: number;
  checks_30d: number;
  fail_7d: number;
  fail_30d: number;
  pass_pct_7d: number;
  pass_pct_30d: number;
  dirty_header_7d: number;
  dirty_header_30d: number;
  rooted_30d: number;
  emulator_30d: number;
  unique_users_failed_30d: number;
  last_check_at: string | null;
};

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function fmtTs(s: string | null) {
  if (!s) return "—";
  try {
    return new Date(s).toLocaleString("en-IN", { timeZone: "Asia/Kolkata" });
  } catch {
    return s;
  }
}

export default async function DeviceIntegrityChecksSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_device_integrity_checks_summary");
  if (error) throw new Error(`founder_device_integrity_checks_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Device integrity checks summary</h1>
        <span className="text-xs text-[var(--color-muted)]">14-KPI Play Integrity pulse · failure rate + tamper headers · pair with /security-overview</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Total checks all-time" val={formatNumber(r.total_all_time)} sub="every verify attempt" />
          <Card title="Checks 24h" val={formatNumber(r.checks_24h)} sub="last day volume" />
          <Card title="Checks 7d" val={formatNumber(r.checks_7d)} sub="last week volume" />
          <Card title="Checks 30d" val={formatNumber(r.checks_30d)} sub="last month volume" />
          <Card title="Fail 7d" val={formatNumber(r.fail_7d)} danger={r.fail_7d > 0} sub="Google said dirty" />
          <Card title="Fail 30d" val={formatNumber(r.fail_30d)} danger={r.fail_30d > 0} sub="Google said dirty" />
          <Card title="Pass % 7d" val={`${Number(r.pass_pct_7d).toFixed(1)}%`} ok={Number(r.pass_pct_7d) >= 95} danger={Number(r.pass_pct_7d) < 90 && r.checks_7d > 0} sub="clean / total" />
          <Card title="Pass % 30d" val={`${Number(r.pass_pct_30d).toFixed(1)}%`} ok={Number(r.pass_pct_30d) >= 95} danger={Number(r.pass_pct_30d) < 90 && r.checks_30d > 0} sub="clean / total" />
          <Card title="Dirty header 7d" val={formatNumber(r.dirty_header_7d)} danger={r.dirty_header_7d > 0} sub="client self-reported tampered" />
          <Card title="Dirty header 30d" val={formatNumber(r.dirty_header_30d)} danger={r.dirty_header_30d > 0} sub="client self-reported tampered" />
          <Card title="Rooted 30d" val={formatNumber(r.rooted_30d)} danger={r.rooted_30d > 0} sub="root=1 header" />
          <Card title="Emulator 30d" val={formatNumber(r.emulator_30d)} danger={r.emulator_30d > 0} sub="emu=1 header" />
          <Card title="Unique users failed 30d" val={formatNumber(r.unique_users_failed_30d)} danger={r.unique_users_failed_30d > 0} sub="distinct user_id at least one fail" />
          <Card title="Last check at" val={fmtTs(r.last_check_at)} sub="IST" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
