import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";
import { SupplierForm } from "./SupplierForm";
import { IntakeForm } from "./IntakeForm";

export const metadata = { title: "Bonded supply — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SupplyKpis = {
  total_suppliers: number | null;
  total_intake_lots: number | null;
  total_units_received: number | null;
  total_units_dispatched: number | null;
  total_units_installed: number | null;
  total_units_lost: number | null;
  unmatched_qr_scans: number | null;
};

type Supplier = {
  id: string;
  supplier_name: string;
  supplier_tier: string;
  oem_brands: string[] | null;
};

export default async function SupplyPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [kpiRes, suppliersRes] = await Promise.all([
    supabase.rpc("founder_bonded_parts_dashboard"),
    supabase
      .from("bonded_parts_suppliers")
      .select("id, supplier_name, supplier_tier, oem_brands")
      .order("supplier_name"),
  ]);
  if (kpiRes.error) throw new Error(`founder_bonded_parts_dashboard: ${kpiRes.error.message}`);
  if (suppliersRes.error)
    throw new Error(`bonded_parts_suppliers: ${suppliersRes.error.message}`);
  const k: SupplyKpis = (Array.isArray(kpiRes.data) ? kpiRes.data[0] : kpiRes.data) ?? ({} as SupplyKpis);
  const suppliers = (suppliersRes.data ?? []) as Supplier[];

  const lostPct =
    k.total_units_received && k.total_units_received > 0 && k.total_units_lost != null
      ? (k.total_units_lost / k.total_units_received) * 100
      : 0;

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Bonded parts provenance</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          OEM / authorized / verified supplier chain from r500. Closes the counterfeit-parts
          CRITICAL (BNS §304A liability). Every intake → dispatch → install is tracked via
          tamper-evident QR codes.
        </p>
      </header>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Ledger state
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Suppliers" value={formatNumber(k.total_suppliers)} />
          <StatCard label="Intake lots" value={formatNumber(k.total_intake_lots)} />
          <StatCard label="Units received" value={formatNumber(k.total_units_received)} />
          <StatCard label="Units installed" value={formatNumber(k.total_units_installed)} />
        </div>
      </section>

      <section>
        <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
          Flow + integrity
        </h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Units dispatched" value={formatNumber(k.total_units_dispatched)} />
          <StatCard
            label="Units lost / shrink"
            value={formatNumber(k.total_units_lost)}
            subtext={lostPct > 0 ? `${lostPct.toFixed(2)}% of received` : undefined}
            tone={lostPct > 1 ? "warn" : "neutral"}
          />
          <StatCard
            label="Unmatched QR scans"
            value={formatNumber(k.unmatched_qr_scans)}
            tone={(k.unmatched_qr_scans ?? 0) > 0 ? "danger" : "ok"}
          />
          <StatCard
            label="Counterfeit hit-rate"
            value={
              k.total_units_dispatched && k.total_units_dispatched > 0
                ? `${(((k.unmatched_qr_scans ?? 0) / k.total_units_dispatched) * 100).toFixed(2)}%`
                : "—"
            }
          />
        </div>
      </section>

      <div className="grid gap-4 lg:grid-cols-2">
        <SupplierForm />
        <IntakeForm suppliers={suppliers} />
      </div>

      {suppliers.length > 0 && (
        <section>
          <h2 className="mb-2 text-xs font-medium uppercase tracking-wider text-[var(--color-muted)]">
            Registered suppliers ({suppliers.length})
          </h2>
          <div className="overflow-x-auto rounded border border-[var(--color-border)] bg-white">
            <table className="min-w-full text-sm">
              <thead>
                <tr className="border-b border-[var(--color-border)] bg-gray-50 text-left text-xs uppercase tracking-wider text-[var(--color-muted)]">
                  <th className="px-3 py-2 font-medium">Name</th>
                  <th className="px-3 py-2 font-medium">Tier</th>
                  <th className="px-3 py-2 font-medium">OEM brands</th>
                </tr>
              </thead>
              <tbody>
                {suppliers.map((s) => (
                  <tr key={s.id} className="border-b border-[var(--color-border)] last:border-0">
                    <td className="px-3 py-2">{s.supplier_name}</td>
                    <td className="px-3 py-2">
                      <span className="rounded bg-gray-100 px-1.5 py-0.5 text-xs">{s.supplier_tier}</span>
                    </td>
                    <td className="px-3 py-2 text-xs text-[var(--color-muted)]">
                      {(s.oem_brands ?? []).join(", ") || "—"}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}
    </div>
  );
}
