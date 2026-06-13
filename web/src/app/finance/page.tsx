import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { formatNumber, formatRupees } from "@/lib/format";
import { currentFiscalQuarter, currentFiscalYear } from "@/lib/fy";

export const metadata = { title: "Finance — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type TdsRow = {
  fiscal_year: string;
  fy_quarter: number;
  deduction_count: number | null;
  total_tds_rupees: number | null;
  deposited_rupees: number | null;
  pending_rupees: number | null;
};

type GstRow = {
  fiscal_year: string;
  fy_quarter: number;
  invoice_count: number | null;
  taxable_total_rupees: number | null;
  cgst_total: number | null;
  sgst_total: number | null;
  igst_total: number | null;
  rcm_count: number | null;
  rcm_taxable_total: number | null;
};

export default async function FinancePage() {
  await requireFounder();
  const fy = currentFiscalYear();
  const fq = currentFiscalQuarter();
  const supabase = await getSupabaseServerClient();

  const [tdsRes, gstRes] = await Promise.all([
    supabase.rpc("founder_tds_quarterly_summary", { p_fiscal_year: fy }),
    supabase.rpc("founder_gst_summary", { p_fiscal_year: fy }),
  ]);
  if (tdsRes.error) throw new Error(`founder_tds_quarterly_summary: ${tdsRes.error.message}`);
  if (gstRes.error) throw new Error(`founder_gst_summary: ${gstRes.error.message}`);
  const tdsRows = (tdsRes.data ?? []) as TdsRow[];
  const gstRows = (gstRes.data ?? []) as GstRow[];

  const tdsTotal = tdsRows.reduce((s, r) => s + (r.total_tds_rupees ?? 0), 0);
  const tdsPending = tdsRows.reduce((s, r) => s + (r.pending_rupees ?? 0), 0);
  const gstCgst = gstRows.reduce((s, r) => s + (r.cgst_total ?? 0), 0);
  const gstSgst = gstRows.reduce((s, r) => s + (r.sgst_total ?? 0), 0);
  const gstIgst = gstRows.reduce((s, r) => s + (r.igst_total ?? 0), 0);
  const gstInvoices = gstRows.reduce((s, r) => s + (r.invoice_count ?? 0), 0);

  return (
    <div className="space-y-8">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Finance — FY {fy}</h1>
        <span className="text-xs text-[var(--color-muted)]">currently in Q{fq}</span>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          TDS §194-O (FY total)
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="TDS withheld (YTD)" value={formatRupees(tdsTotal)} />
          <StatCard
            label="Pending deposit"
            value={formatRupees(tdsPending)}
            tone={tdsPending > 0 ? "warn" : "ok"}
          />
          <StatCard
            label="Deductions count"
            value={formatNumber(tdsRows.reduce((s, r) => s + (r.deduction_count ?? 0), 0))}
          />
          <StatCard label="Quarters reported" value={formatNumber(tdsRows.length)} />
        </div>
        <div className="mt-3 overflow-x-auto rounded border border-[var(--color-border)] bg-white">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] bg-gray-50 text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="px-3 py-2 font-medium">FY</th>
                <th className="px-3 py-2 font-medium">Q</th>
                <th className="px-3 py-2 font-medium">Deductions</th>
                <th className="px-3 py-2 font-medium">Withheld</th>
                <th className="px-3 py-2 font-medium">Deposited</th>
                <th className="px-3 py-2 font-medium">Pending</th>
              </tr>
            </thead>
            <tbody>
              {tdsRows.map((r) => (
                <tr key={`tds-${r.fy_quarter}`} className="border-b border-[var(--color-border)] last:border-0">
                  <td className="px-3 py-2">{r.fiscal_year}</td>
                  <td className="px-3 py-2">Q{r.fy_quarter}</td>
                  <td className="px-3 py-2">{formatNumber(r.deduction_count)}</td>
                  <td className="px-3 py-2">{formatRupees(r.total_tds_rupees)}</td>
                  <td className="px-3 py-2">{formatRupees(r.deposited_rupees)}</td>
                  <td className="px-3 py-2">{formatRupees(r.pending_rupees)}</td>
                </tr>
              ))}
              {tdsRows.length === 0 && (
                <tr>
                  <td className="px-3 py-4 text-center text-[var(--color-muted)]" colSpan={6}>
                    No TDS rows for {fy}.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          GST (FY total)
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Invoices issued" value={formatNumber(gstInvoices)} />
          <StatCard label="CGST collected" value={formatRupees(gstCgst)} />
          <StatCard label="SGST collected" value={formatRupees(gstSgst)} />
          <StatCard label="IGST collected" value={formatRupees(gstIgst)} />
        </div>
        <div className="mt-3 overflow-x-auto rounded border border-[var(--color-border)] bg-white">
          <table className="min-w-full text-sm">
            <thead>
              <tr className="border-b border-[var(--color-border)] bg-gray-50 text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                <th className="px-3 py-2 font-medium">FY</th>
                <th className="px-3 py-2 font-medium">Q</th>
                <th className="px-3 py-2 font-medium">Invoices</th>
                <th className="px-3 py-2 font-medium">Taxable</th>
                <th className="px-3 py-2 font-medium">CGST</th>
                <th className="px-3 py-2 font-medium">SGST</th>
                <th className="px-3 py-2 font-medium">IGST</th>
                <th className="px-3 py-2 font-medium">RCM</th>
              </tr>
            </thead>
            <tbody>
              {gstRows.map((r) => (
                <tr key={`gst-${r.fy_quarter}`} className="border-b border-[var(--color-border)] last:border-0">
                  <td className="px-3 py-2">{r.fiscal_year}</td>
                  <td className="px-3 py-2">Q{r.fy_quarter}</td>
                  <td className="px-3 py-2">{formatNumber(r.invoice_count)}</td>
                  <td className="px-3 py-2">{formatRupees(r.taxable_total_rupees)}</td>
                  <td className="px-3 py-2">{formatRupees(r.cgst_total)}</td>
                  <td className="px-3 py-2">{formatRupees(r.sgst_total)}</td>
                  <td className="px-3 py-2">{formatRupees(r.igst_total)}</td>
                  <td className="px-3 py-2">
                    {formatNumber(r.rcm_count)} <span className="text-[var(--color-muted)]">/ {formatRupees(r.rcm_taxable_total)}</span>
                  </td>
                </tr>
              ))}
              {gstRows.length === 0 && (
                <tr>
                  <td className="px-3 py-4 text-center text-[var(--color-muted)]" colSpan={8}>
                    No GST rows for {fy}.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </div>
  );
}
