import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer attendance summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  events_total: number;
  arrivals_total: number;
  departures_total: number;
  events_last_24h: number;
  events_last_7d: number;
  arrivals_last_24h: number;
  unique_engineers_checked_in_24h: number;
  unique_engineers_checked_in_7d: number;
  suspicious_events_total: number;
  suspicious_events_24h: number;
  suspicious_rate_pct: number;
  verified_engineers_no_checkin_7d: number;
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

export default async function EngineerAttendanceSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_attendance_summary");
  if (error) throw new Error(`founder_engineer_attendance_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  const suspiciousHigh = r ? Number(r.suspicious_rate_pct) >= 5 : false;
  const ghostHigh = r ? Number(r.verified_engineers_no_checkin_7d) > 0 : false;
  const subtitle = `12-KPI GPS attendance pulse · arrival/departure ledger from r496 · suspicious-distance flag ${'>'}500m off hospital coords · pair with /engineer-availability-summary`;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Engineer attendance summary</h1>
        <span className="text-xs text-[var(--color-muted)]">{subtitle}</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Events total" val={formatNumber(r.events_total)} sub="all check-in + check-out rows" />
          <Card title="Arrivals total" val={formatNumber(r.arrivals_total)} sub="event_kind = arrival_checkin" />
          <Card title="Departures total" val={formatNumber(r.departures_total)} sub="event_kind = departure_checkout" />
          <Card title="Events last 24h" val={formatNumber(r.events_last_24h)} sub="rolling window" />
          <Card title="Events last 7d" val={formatNumber(r.events_last_7d)} sub="rolling window" />
          <Card title="Arrivals last 24h" val={formatNumber(r.arrivals_last_24h)} ok={r.arrivals_last_24h > 0} sub="hot field activity" />
          <Card title="Engineers checked-in 24h" val={formatNumber(r.unique_engineers_checked_in_24h)} sub="unique engineer_user_id" />
          <Card title="Engineers checked-in 7d" val={formatNumber(r.unique_engineers_checked_in_7d)} sub="weekly active field crew" />
          <Card title="Suspicious events total" val={formatNumber(r.suspicious_events_total)} danger={r.suspicious_events_total > 0} sub="distance flag tripped" />
          <Card title="Suspicious events 24h" val={formatNumber(r.suspicious_events_24h)} danger={r.suspicious_events_24h > 0} sub="needs review" />
          <Card title="Suspicious rate %" val={`${Number(r.suspicious_rate_pct).toFixed(2)}%`} danger={suspiciousHigh} sub="suspicious / events_total" />
          <Card title="Ghost engineers 7d" val={formatNumber(r.verified_engineers_no_checkin_7d)} danger={ghostHigh} sub="verified but no check-in 7d" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}