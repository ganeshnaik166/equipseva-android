import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Email delivery health summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  emails_sent_today: number;
  emails_sent_mtd: number;
  emails_sent_7d: number;
  emails_sent_30d: number;
  resend_failed_30d: number;
  skipped_no_email_30d: number;
  disabled_30d: number;
  delivery_success_pct_30d: number;
  revenue_in_failed_30d_rupees: number;
  unique_recipient_domains_30d: number;
  expired_signed_urls_30d: number;
  hours_since_last_sent: number;
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

function fmtRupees(n: number): string {
  return `Rs ${formatNumber(Math.round(Number(n) || 0))}`;
}

export default async function EmailDeliveryHealthSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_email_delivery_health_summary");
  if (error) throw new Error(`founder_email_delivery_health_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Email delivery health summary</h1>
        <span className="text-xs text-[var(--color-muted)]">12-KPI email channel · GST invoice auto-dispatch + founder digest · silent-bounce detector</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Emails sent today" val={formatNumber(r.emails_sent_today)} sub="IST day, status=sent" />
          <Card title="Emails sent MTD" val={formatNumber(r.emails_sent_mtd)} sub="month-to-date" />
          <Card title="Emails sent 7d" val={formatNumber(r.emails_sent_7d)} sub="rolling week" />
          <Card title="Emails sent 30d" val={formatNumber(r.emails_sent_30d)} sub="rolling month" ok={r.emails_sent_30d > 0} />
          <Card
            title="Resend failed 30d"
            val={formatNumber(r.resend_failed_30d)}
            sub="provider rejected"
            danger={r.resend_failed_30d > 0}
          />
          <Card
            title="Skipped no-email 30d"
            val={formatNumber(r.skipped_no_email_30d)}
            sub="recipient missing"
            danger={r.skipped_no_email_30d > 0}
          />
          <Card
            title="Disabled 30d"
            val={formatNumber(r.disabled_30d)}
            sub="config gap / kill-switch"
            danger={r.disabled_30d > 0}
          />
          <Card
            title="Delivery success 30d"
            val={`${Number(r.delivery_success_pct_30d).toFixed(1)}%`}
            sub="sent / total"
            ok={r.delivery_success_pct_30d >= 95}
            danger={r.delivery_success_pct_30d < 80 && r.emails_sent_30d + r.resend_failed_30d + r.skipped_no_email_30d + r.disabled_30d > 0}
          />
          <Card
            title="Revenue in failed 30d"
            val={fmtRupees(r.revenue_in_failed_30d_rupees)}
            sub="invoices stuck unsent"
            danger={Number(r.revenue_in_failed_30d_rupees) > 0}
          />
          <Card
            title="Recipient domains 30d"
            val={formatNumber(r.unique_recipient_domains_30d)}
            sub="distinct hospital domains"
          />
          <Card
            title="Expired signed URLs 30d"
            val={formatNumber(r.expired_signed_urls_30d)}
            sub="link rot, needs re-sign"
            danger={r.expired_signed_urls_30d > 0}
          />
          <Card
            title="Hours since last sent"
            val={Number(r.hours_since_last_sent).toFixed(1)}
            sub="staleness probe"
            danger={Number(r.hours_since_last_sent) > 48}
            ok={Number(r.hours_since_last_sent) > 0 && Number(r.hours_since_last_sent) <= 24}
          />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}