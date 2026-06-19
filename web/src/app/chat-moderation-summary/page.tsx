import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Chat moderation summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  messages_today: number;
  messages_7d: number;
  messages_30d: number;
  active_conversations_today: number;
  active_senders_today: number;
  deleted_today: number;
  pii_attempts_today: number;
  pii_attempts_7d: number;
  pii_attempts_30d: number;
  pii_phone_attempts_30d: number;
  pii_email_attempts_30d: number;
  repeat_offenders_30d: number;
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

export default async function ChatModerationSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_chat_moderation_summary");
  if (error) throw new Error(`founder_chat_moderation_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Chat moderation summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI DPDP / safety dashboard · today / 7d / 30d windows · PII-leak attempts + volume — no message bodies surfaced</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Messages today" val={formatNumber(r.messages_today)} sub="IST day" />
          <Card title="Messages 7d" val={formatNumber(r.messages_7d)} />
          <Card title="Messages 30d" val={formatNumber(r.messages_30d)} />
          <Card title="Active conversations today" val={formatNumber(r.active_conversations_today)} sub="distinct threads" />
          <Card title="Active senders today" val={formatNumber(r.active_senders_today)} />
          <Card title="Messages deleted today" val={formatNumber(r.deleted_today)} sub="regret / takedown signal" />
          <Card title="PII attempts today" val={formatNumber(r.pii_attempts_today)} danger={r.pii_attempts_today > 0} sub="phone / email leak" />
          <Card title="PII attempts 7d" val={formatNumber(r.pii_attempts_7d)} danger={r.pii_attempts_7d > 5} />
          <Card title="PII attempts 30d" val={formatNumber(r.pii_attempts_30d)} />
          <Card title="Phone leak attempts 30d" val={formatNumber(r.pii_phone_attempts_30d)} sub="off-platform risk" />
          <Card title="Email leak attempts 30d" val={formatNumber(r.pii_email_attempts_30d)} />
          <Card title="Repeat offenders 30d" val={formatNumber(r.repeat_offenders_30d)} danger={r.repeat_offenders_30d > 0} sub=">=3 PII events" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
