import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Hospital billing engine — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_cycles_lifetime: number;
  cycles_this_month: number;
  cycles_pending: number;
  cycles_invoiced: number;
  cycles_paid: number;
  cycles_overdue: number;
  total_invoiced_amount_lifetime_rupees: number;
  total_collected_lifetime_rupees: number;
  total_outstanding_rupees: number;
  outstanding_30d_rupees: number;
  outstanding_over_60d_rupees: number;
  collection_rate_lifetime_pct: number;
  collection_rate_30d_pct: number;
  dunning_events_30d: number;
  oldest_unpaid_invoice_age_days: number;
  generated_at: string;
};

type Invoice = {
  id: string;
  invoice_number: string;
  invoice_date: string;
  cycle_month: string;
  total_amount_rupees: number;
  amount_paid_rupees: number;
  amount_due_rupees: number;
  payment_status: string;
  delivery_channel: string;
  delivered_at: string | null;
  age_days: number;
};

type Dunning = {
  id: string;
  invoice_number: string;
  dunning_step: number;
  channel: string;
  sent_at: string;
  outcome: string | null;
  outcome_at: string | null;
};

function Card({ label, value, sub, tone }: { label: string; value: string; sub?: string; tone?: "ok" | "warn" | "danger" }) {
  const t = tone === "ok" ? "text-[var(--color-ok)]" : tone === "warn" ? "text-[var(--color-warn)]" : tone === "danger" ? "text-[var(--color-danger)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${t}`}>{value}</div>
      {sub ? <div className="text-xs text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}
function rup(n: number): string { return `₹${formatNumber(Math.round(n))}`; }

export default async function FounderHospitalBillingEnginePage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();
  const [sRes, iRes, dRes] = await Promise.all([
    sb.rpc("founder_hospital_billing_engine_summary"),
    sb.rpc("founder_hospital_billing_invoices_recent", { p_limit: 100 }),
    sb.rpc("founder_hospital_billing_dunning_recent", { p_limit: 50 }),
  ]);
  if (sRes.error) throw new Error(`billing_engine_summary: ${sRes.error.message}`);
  if (iRes.error) throw new Error(`billing_invoices_recent: ${iRes.error.message}`);
  if (dRes.error) throw new Error(`billing_dunning_recent: ${dRes.error.message}`);
  const s = (sRes.data?.[0] ?? null) as Summary | null;
  const invoices = (iRes.data ?? []) as Invoice[];
  const dunning = (dRes.data ?? []) as Dunning[];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Hospital billing engine ★★★★ recurring AMC billing</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          End-to-end monthly AMC billing. 3 tables (cycles + invoices + dunning events). 8 RPCs (cycle generator cron + overdue-flip cron + summary + invoice list + dunning list + payment recorder + dunning sender). 7-status cycle state machine pending→invoiced→paid/partially_paid/overdue/waived/cancelled.
        </p>
      </header>

      {s ? (
        <section className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="Cycles lifetime" value={formatNumber(s.total_cycles_lifetime)} />
          <Card label="Cycles this month" value={formatNumber(s.cycles_this_month)} />
          <Card label="Cycles pending" value={formatNumber(s.cycles_pending)} />
          <Card label="Cycles invoiced" value={formatNumber(s.cycles_invoiced)} />
          <Card label="Cycles paid" value={formatNumber(s.cycles_paid)} tone="ok" />
          <Card label="Cycles overdue" value={formatNumber(s.cycles_overdue)} tone={s.cycles_overdue > 0 ? "danger" : "ok"} />
          <Card label="Invoiced lifetime" value={rup(s.total_invoiced_amount_lifetime_rupees)} />
          <Card label="Collected lifetime" value={rup(s.total_collected_lifetime_rupees)} tone="ok" />
          <Card label="Outstanding total" value={rup(s.total_outstanding_rupees)} tone={s.total_outstanding_rupees > 0 ? "warn" : "ok"} />
          <Card label="Outstanding 30d" value={rup(s.outstanding_30d_rupees)} />
          <Card label="Outstanding >60d" value={rup(s.outstanding_over_60d_rupees)} tone={s.outstanding_over_60d_rupees > 0 ? "danger" : "ok"} />
          <Card label="Collection rate lifetime" value={`${s.collection_rate_lifetime_pct.toFixed(1)}%`} />
          <Card label="Collection rate 30d" value={`${s.collection_rate_30d_pct.toFixed(1)}%`} tone={s.collection_rate_30d_pct >= 90 ? "ok" : s.collection_rate_30d_pct >= 70 ? "warn" : "danger"} />
          <Card label="Dunning events 30d" value={formatNumber(s.dunning_events_30d)} />
          <Card label="Oldest unpaid age" value={`${s.oldest_unpaid_invoice_age_days}d`} tone={s.oldest_unpaid_invoice_age_days > 60 ? "danger" : s.oldest_unpaid_invoice_age_days > 30 ? "warn" : "ok"} />
          <Card label="Generated" value={new Date(s.generated_at).toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" })} sub="IST" />
        </section>
      ) : <p className="text-sm text-[var(--color-muted)]">No data — run founder_hospital_billing_generate_current_month() to seed.</p>}

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Recent invoices ({invoices.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">Invoice #</th>
                <th className="py-2 pr-3">Cycle</th>
                <th className="py-2 pr-3">Issued</th>
                <th className="py-2 pr-3 text-right">Total</th>
                <th className="py-2 pr-3 text-right">Paid</th>
                <th className="py-2 pr-3 text-right">Due</th>
                <th className="py-2 pr-3">Status</th>
                <th className="py-2 pr-3">Channel</th>
                <th className="py-2 text-right">Age</th>
              </tr>
            </thead>
            <tbody>
              {invoices.map((i) => (
                <tr key={i.id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs font-mono">{i.invoice_number}</td>
                  <td className="py-2 pr-3 text-xs text-[var(--color-muted)]">{i.cycle_month}</td>
                  <td className="py-2 pr-3 text-xs">{i.invoice_date}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{rup(i.total_amount_rupees)}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{rup(i.amount_paid_rupees)}</td>
                  <td className={`py-2 pr-3 text-xs text-right tabular-nums ${i.amount_due_rupees > 0 ? "text-[var(--color-warn)] font-semibold" : ""}`}>{rup(i.amount_due_rupees)}</td>
                  <td className={`py-2 pr-3 text-xs ${i.payment_status === "paid" ? "text-[var(--color-ok)]" : i.payment_status === "unpaid" ? "text-[var(--color-warn)]" : i.payment_status === "disputed" ? "text-[var(--color-danger)]" : ""}`}>{i.payment_status}</td>
                  <td className="py-2 pr-3 text-xs">{i.delivery_channel}</td>
                  <td className={`py-2 text-xs text-right tabular-nums ${i.age_days > 60 ? "text-[var(--color-danger)] font-semibold" : ""}`}>{i.age_days}d</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold uppercase tracking-wider text-[var(--color-muted)]">Recent dunning events ({dunning.length})</h2>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="py-2 pr-3">When</th>
                <th className="py-2 pr-3">Invoice</th>
                <th className="py-2 pr-3 text-right">Step</th>
                <th className="py-2 pr-3">Channel</th>
                <th className="py-2">Outcome</th>
              </tr>
            </thead>
            <tbody>
              {dunning.map((d) => (
                <tr key={d.id} className="border-b border-[var(--color-border)]">
                  <td className="py-2 pr-3 text-xs font-mono text-[var(--color-muted)]">{new Date(d.sent_at).toLocaleString("en-IN")}</td>
                  <td className="py-2 pr-3 text-xs font-mono">{d.invoice_number}</td>
                  <td className="py-2 pr-3 text-xs text-right tabular-nums">{d.dunning_step}</td>
                  <td className="py-2 pr-3 text-xs">{d.channel}</td>
                  <td className="py-2 text-xs">{d.outcome ?? "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <p className="text-xs text-[var(--color-muted)]">
        Cron-callable: <code>founder_hospital_billing_generate_current_month()</code> (monthly cycle generator · idempotent on (amc_contract_id, cycle_month) unique) and <code>founder_hospital_billing_flip_overdue()</code> (daily overdue flipper). 5-step dunning ladder with 6 channels (email/sms/whatsapp/phone/in_person/legal_notice).
      </p>
    </div>
  );
}
