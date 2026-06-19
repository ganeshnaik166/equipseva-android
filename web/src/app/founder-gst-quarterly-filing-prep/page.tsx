import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Founder GST quarterly filing prep — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Prep = {
  quarter_label: string;
  period_start: string;
  period_end: string;
  b2b_invoice_count: number;
  b2b_taxable_value_rupees: number;
  b2b_igst_rupees: number;
  b2b_cgst_rupees: number;
  b2b_sgst_rupees: number;
  b2c_invoice_count: number;
  b2c_taxable_value_rupees: number;
  b2c_igst_rupees: number;
  b2c_cgst_rupees: number;
  b2c_sgst_rupees: number;
  nil_rated_count: number;
  hsn_distinct_count: number;
  total_outward_taxable_rupees: number;
  total_igst_rupees: number;
  total_cgst_rupees: number;
  total_sgst_rupees: number;
  itc_eligible_rupees: number;
  net_tax_payable_rupees: number;
};

type Filing = {
  id: string;
  quarter_label: string;
  period_start: string;
  period_end: string;
  status: string;
  arn: string | null;
  filed_at: string | null;
  total_outward_taxable_rupees: number;
  total_igst_rupees: number;
  total_cgst_rupees: number;
  total_sgst_rupees: number;
  created_at: string;
  updated_at: string;
};

function Card({ title, val, sub, danger, ok, info }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean; info?: boolean }) {
  const tone = danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : info ? "text-[var(--color-info)]" : "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${tone}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function quarterStartFor(d: Date): Date {
  const m = d.getUTCMonth();
  const qStartMonth = m - (m % 3);
  return new Date(Date.UTC(d.getUTCFullYear(), qStartMonth, 1));
}

function fmtQuarterLabel(start: Date): string {
  const q = Math.floor(start.getUTCMonth() / 3) + 1;
  const yy = String(start.getUTCFullYear()).slice(-2);
  const yyNext = String(start.getUTCFullYear() + 1).slice(-2);
  return `Q${q}-FY${yy}-${yyNext}`;
}

function isoDate(d: Date): string {
  return d.toISOString().slice(0, 10);
}

export default async function Page({ searchParams }: { searchParams: Promise<{ q?: string }> }) {
  await requireFounder();
  const sp = await searchParams;
  const supabase = await getSupabaseServerClient();

  const now = new Date();
  const currentQStart = quarterStartFor(now);

  const choices: { label: string; start: string }[] = [];
  for (let i = 0; i < 4; i++) {
    const s = new Date(Date.UTC(currentQStart.getUTCFullYear(), currentQStart.getUTCMonth() - i * 3, 1));
    choices.push({ label: fmtQuarterLabel(s), start: isoDate(s) });
  }

  const selectedStart = sp?.q && choices.some((c) => c.start === sp.q) ? sp.q! : choices[0].start;

  const { data: prepData } = await supabase.rpc("founder_gst_quarterly_prep", { p_quarter_start: selectedStart });
  const prep: Prep | null = Array.isArray(prepData) && prepData.length > 0 ? (prepData[0] as Prep) : null;

  const { data: recentData } = await supabase.rpc("founder_gst_quarterly_filings_recent", { p_limit: 8 });
  const recent: Filing[] = Array.isArray(recentData) ? (recentData as Filing[]) : [];

  return (
    <div className="mx-auto max-w-7xl space-y-6 p-4 sm:p-6">
      <header className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Founder GST quarterly filing prep</h1>
          <p className="text-sm text-[var(--color-muted)]">
            r1316 — GSTR-1 + GSTR-3B prefill from gst_invoices → manual review → push to GSTN
          </p>
        </div>
        <form className="flex items-center gap-2" action="" method="get">
          <label className="text-xs text-[var(--color-muted)]" htmlFor="q">Quarter</label>
          <select id="q" name="q" defaultValue={selectedStart} className="rounded-md border border-[var(--color-border)] bg-[var(--color-surface)] px-2 py-1 text-sm">
            {choices.map((c) => (
              <option key={c.start} value={c.start}>{c.label}</option>
            ))}
          </select>
          <button type="submit" className="rounded-md border border-[var(--color-border)] bg-[var(--color-surface)] px-3 py-1 text-sm hover:border-[var(--color-accent)]">Load</button>
        </form>
      </header>

      {!prep ? (
        <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6 text-sm text-[var(--color-muted)]">
          No invoice activity in the selected quarter, or RPC returned no rows.
        </div>
      ) : (
        <>
          <section>
            <div className="mb-2 flex items-baseline justify-between">
              <h2 className="text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">Quarter summary</h2>
              <div className="text-xs text-[var(--color-muted)] tabular-nums">{prep.quarter_label} - {prep.period_start} to {prep.period_end}</div>
            </div>
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
              <Card title="Outward taxable" val={`Rs ${formatNumber(prep.total_outward_taxable_rupees)}`} sub="across B2B + B2C" />
              <Card title="IGST" val={`Rs ${formatNumber(prep.total_igst_rupees)}`} info />
              <Card title="CGST" val={`Rs ${formatNumber(prep.total_cgst_rupees)}`} info />
              <Card title="SGST" val={`Rs ${formatNumber(prep.total_sgst_rupees)}`} info />
              <Card title="Net tax payable" val={`Rs ${formatNumber(prep.net_tax_payable_rupees)}`} danger sub={`ITC eligible Rs ${formatNumber(prep.itc_eligible_rupees)}`} />
            </div>
          </section>

          <section>
            <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">B2B vs B2C breakdown</h2>
            <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
              <table className="min-w-full text-sm">
                <thead className="bg-[var(--color-surface-2,transparent)] text-left text-xs uppercase tracking-wide text-[var(--color-muted)]">
                  <tr>
                    <th className="px-4 py-2">Segment</th>
                    <th className="px-4 py-2 text-right">Invoices</th>
                    <th className="px-4 py-2 text-right">Taxable value</th>
                    <th className="px-4 py-2 text-right">IGST</th>
                    <th className="px-4 py-2 text-right">CGST</th>
                    <th className="px-4 py-2 text-right">SGST</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-[var(--color-border)]">
                  <tr>
                    <td className="px-4 py-2 font-medium">B2B (buyer GSTIN present)</td>
                    <td className="px-4 py-2 text-right tabular-nums">{formatNumber(prep.b2b_invoice_count)}</td>
                    <td className="px-4 py-2 text-right tabular-nums">Rs {formatNumber(prep.b2b_taxable_value_rupees)}</td>
                    <td className="px-4 py-2 text-right tabular-nums">Rs {formatNumber(prep.b2b_igst_rupees)}</td>
                    <td className="px-4 py-2 text-right tabular-nums">Rs {formatNumber(prep.b2b_cgst_rupees)}</td>
                    <td className="px-4 py-2 text-right tabular-nums">Rs {formatNumber(prep.b2b_sgst_rupees)}</td>
                  </tr>
                  <tr>
                    <td className="px-4 py-2 font-medium">B2C (no buyer GSTIN)</td>
                    <td className="px-4 py-2 text-right tabular-nums">{formatNumber(prep.b2c_invoice_count)}</td>
                    <td className="px-4 py-2 text-right tabular-nums">Rs {formatNumber(prep.b2c_taxable_value_rupees)}</td>
                    <td className="px-4 py-2 text-right tabular-nums">Rs {formatNumber(prep.b2c_igst_rupees)}</td>
                    <td className="px-4 py-2 text-right tabular-nums">Rs {formatNumber(prep.b2c_cgst_rupees)}</td>
                    <td className="px-4 py-2 text-right tabular-nums">Rs {formatNumber(prep.b2c_sgst_rupees)}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </section>

          <section className="grid grid-cols-1 gap-3 sm:grid-cols-3">
            <Card title="HSN distinct codes" val={formatNumber(prep.hsn_distinct_count)} sub="GSTR-1 HSN summary" />
            <Card title="Nil-rated invoices" val={formatNumber(prep.nil_rated_count)} sub="taxable_value = 0" />
            <Card title="Total invoices" val={formatNumber(prep.b2b_invoice_count + prep.b2c_invoice_count)} ok />
          </section>
        </>
      )}

      <section>
        <h2 className="mb-2 text-sm font-semibold uppercase tracking-wide text-[var(--color-muted)]">Recent filings log</h2>
        <div className="overflow-x-auto rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)]">
          <table className="min-w-full text-sm">
            <thead className="text-left text-xs uppercase tracking-wide text-[var(--color-muted)]">
              <tr>
                <th className="px-4 py-2">Quarter</th>
                <th className="px-4 py-2">Period</th>
                <th className="px-4 py-2">Status</th>
                <th className="px-4 py-2">ARN</th>
                <th className="px-4 py-2">Filed at</th>
                <th className="px-4 py-2 text-right">Outward taxable</th>
                <th className="px-4 py-2 text-right">IGST</th>
                <th className="px-4 py-2 text-right">CGST + SGST</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-[var(--color-border)]">
              {recent.length === 0 ? (
                <tr><td colSpan={8} className="px-4 py-6 text-center text-[var(--color-muted)]">No filings logged yet. Generate a draft via log_founder_gst_filing_draft RPC.</td></tr>
              ) : recent.map((f) => {
                const statusTone = f.status === "filed" ? "text-[var(--color-ok)]" : f.status === "rejected" ? "text-[var(--color-danger)]" : f.status === "reviewed" ? "text-[var(--color-info)]" : "text-[var(--color-warn)]";
                return (
                  <tr key={f.id}>
                    <td className="px-4 py-2 font-medium">{f.quarter_label}</td>
                    <td className="px-4 py-2 tabular-nums text-[var(--color-muted)]">{f.period_start} to {f.period_end}</td>
                    <td className={`px-4 py-2 font-medium ${statusTone}`}>{f.status}</td>
                    <td className="px-4 py-2 tabular-nums">{f.arn ?? "-"}</td>
                    <td className="px-4 py-2 tabular-nums text-[var(--color-muted)]">{f.filed_at ? new Date(f.filed_at).toISOString().slice(0, 10) : "-"}</td>
                    <td className="px-4 py-2 text-right tabular-nums">Rs {formatNumber(f.total_outward_taxable_rupees)}</td>
                    <td className="px-4 py-2 text-right tabular-nums">Rs {formatNumber(f.total_igst_rupees)}</td>
                    <td className="px-4 py-2 text-right tabular-nums">Rs {formatNumber(f.total_cgst_rupees + f.total_sgst_rupees)}</td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </section>

      <div className="rounded-lg border border-[var(--color-warn)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)]">
        <strong className="text-[var(--color-warn)]">Manual review + sign-off required</strong> before push to GSTN portal. JSON payloads (gstr1_payload, gstr3b_payload) are stored on founder_gst_filings and available for export. Net tax payable shown gross of ITC - apply ITC offsets before final 3B submission. RPC: log_founder_gst_filing_draft(label, start) generates payload; log_founder_gst_filing_status(id, status, arn) marks reviewed / filed / rejected.
      </div>
    </div>
  );
}
