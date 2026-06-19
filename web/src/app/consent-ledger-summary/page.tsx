import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Consent ledger summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  events_total: number;
  events_today: number;
  events_30d: number;
  granted_30d: number;
  revoked_30d: number;
  granted_today: number;
  revoked_today: number;
  distinct_users_consented: number;
  marketing_granted_latest: number;
  marketing_revoked_latest: number;
  location_granted_latest: number;
  privacy_policy_grants_30d: number;
  top_revoked_type: string;
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

export default async function ConsentLedgerSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_consent_ledger_summary");
  if (error) throw new Error(`founder_consent_ledger_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Consent ledger summary</h1>
        <span className="text-xs text-[var(--color-muted)]">13-KPI DPDP consent posture · per-purpose grant/revoke latest-state · revocation velocity</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Events all-time" val={formatNumber(r.events_total)} />
          <Card title="Events today" val={formatNumber(r.events_today)} />
          <Card title="Events 30d" val={formatNumber(r.events_30d)} />
          <Card title="Granted 30d" val={formatNumber(r.granted_30d)} ok />
          <Card title="Revoked 30d" val={formatNumber(r.revoked_30d)} danger={r.revoked_30d > 0} sub="withdrawal velocity" />
          <Card title="Granted today" val={formatNumber(r.granted_today)} />
          <Card title="Revoked today" val={formatNumber(r.revoked_today)} danger={r.revoked_today > 0} />
          <Card title="Distinct users consented" val={formatNumber(r.distinct_users_consented)} />
          <Card title="Marketing — latest granted" val={formatNumber(r.marketing_granted_latest)} ok sub="marketing_emails" />
          <Card title="Marketing — latest revoked" val={formatNumber(r.marketing_revoked_latest)} danger={r.marketing_revoked_latest > 0} sub="withdrawn" />
          <Card title="Location — latest granted" val={formatNumber(r.location_granted_latest)} sub="location_tracking" />
          <Card title="Privacy policy grants 30d" val={formatNumber(r.privacy_policy_grants_30d)} />
          <Card title="Top revoked type 30d" val={String(r.top_revoked_type ?? "(none)")} sub="revocation hotspot" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
