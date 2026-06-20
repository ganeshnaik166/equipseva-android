import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type Summary = {
  total_equipment: number;
  operational_count: number;
  maintenance_only_count: number;
  decommissioned_count: number;
  disposed_count: number;
  quotation_count: number;
  procurement_count: number;
  installation_count: number;
  commissioned_count: number;
  critical_count: number;
  high_count: number;
  total_purchase_cost_rupees: number;
  total_book_value_rupees: number;
  avg_useful_life_years: number;
  total_events: number;
  total_event_value_rupees: number;
};

type Equipment = {
  id: string;
  equipment_label: string;
  manufacturer: string | null;
  model_number: string | null;
  serial_number: string | null;
  equipment_category: string | null;
  lifecycle_stage: string;
  criticality_band: string;
  purchase_cost_rupees: number;
  current_book_value_rupees: number;
  useful_life_years: number;
  hospital_name: string | null;
  procurement_date: string | null;
  commission_date: string | null;
  created_at: string;
};

type Event = {
  id: string;
  equipment_id: string;
  equipment_label: string | null;
  event_kind: string;
  description: string | null;
  happened_at: string;
  value_rupees: number;
};

type StageRow = {
  lifecycle_stage: string;
  equipment_count: number;
  total_book_value_rupees: number;
};

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [{ data: summaryRows }, { data: equipRows }, { data: eventRows }, { data: stageRows }] =
    await Promise.all([
      sb.rpc("founder_equipment_lifecycle_summary"),
      sb.rpc("founder_equipment_lifecycle_recent", { p_limit: 100 }),
      sb.rpc("founder_equipment_lifecycle_events_recent", { p_limit: 50 }),
      sb.rpc("founder_equipment_lifecycle_by_stage"),
    ]);

  const s: Summary = (summaryRows?.[0] as Summary) ?? {
    total_equipment: 0,
    operational_count: 0,
    maintenance_only_count: 0,
    decommissioned_count: 0,
    disposed_count: 0,
    quotation_count: 0,
    procurement_count: 0,
    installation_count: 0,
    commissioned_count: 0,
    critical_count: 0,
    high_count: 0,
    total_purchase_cost_rupees: 0,
    total_book_value_rupees: 0,
    avg_useful_life_years: 0,
    total_events: 0,
    total_event_value_rupees: 0,
  };
  const equipment: Equipment[] = (equipRows as Equipment[]) ?? [];
  const events: Event[] = (eventRows as Event[]) ?? [];
  const stages: StageRow[] = (stageRows as StageRow[]) ?? [];

  const cards: Array<{ label: string; value: string }> = [
    { label: "Total equipment", value: formatNumber(s.total_equipment) },
    { label: "Operational", value: formatNumber(s.operational_count) },
    { label: "Maintenance-only", value: formatNumber(s.maintenance_only_count) },
    { label: "Decommissioned", value: formatNumber(s.decommissioned_count) },
    { label: "Disposed", value: formatNumber(s.disposed_count) },
    { label: "In quotation", value: formatNumber(s.quotation_count) },
    { label: "In procurement", value: formatNumber(s.procurement_count) },
    { label: "Installation", value: formatNumber(s.installation_count) },
    { label: "Commissioned", value: formatNumber(s.commissioned_count) },
    { label: "Critical units", value: formatNumber(s.critical_count) },
    { label: "High-criticality units", value: formatNumber(s.high_count) },
    { label: "Total purchase cost (Rs)", value: formatNumber(s.total_purchase_cost_rupees) },
    { label: "Total book value (Rs)", value: formatNumber(s.total_book_value_rupees) },
    { label: "Avg useful life (yrs)", value: Number(s.avg_useful_life_years ?? 0).toFixed(1) },
    { label: "Lifecycle events", value: formatNumber(s.total_events) },
    { label: "Event value (Rs)", value: formatNumber(s.total_event_value_rupees) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold tracking-tight">Hospital equipment lifecycle tracker</h1>
        <p className="mt-1 text-sm text-neutral-500">
          Acquisition {">"} installation {">"} operational {">"} retirement. Per-asset book value + event ledger.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {cards.map((c) => (
          <div key={c.label} className="rounded-xl border border-neutral-200 bg-white p-4">
            <div className="text-xs uppercase tracking-wide text-neutral-500">{c.label}</div>
            <div className="mt-1 text-xl font-semibold tabular-nums">{c.value}</div>
          </div>
        ))}
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold">Stage distribution</h2>
        <div className="overflow-x-auto rounded-xl border border-neutral-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-neutral-50 text-left text-xs uppercase tracking-wide text-neutral-500">
              <tr>
                <th className="px-4 py-2">Stage</th>
                <th className="px-4 py-2">Equipment</th>
                <th className="px-4 py-2">Book value (Rs)</th>
              </tr>
            </thead>
            <tbody>
              {stages.length === 0 ? (
                <tr><td className="px-4 py-3 text-neutral-500" colSpan={3}>No stages yet.</td></tr>
              ) : (
                stages.map((r) => (
                  <tr key={r.lifecycle_stage} className="border-t border-neutral-100">
                    <td className="px-4 py-2 font-medium">{r.lifecycle_stage}</td>
                    <td className="px-4 py-2 tabular-nums">{formatNumber(r.equipment_count)}</td>
                    <td className="px-4 py-2 tabular-nums">{formatNumber(r.total_book_value_rupees)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold">Equipment ledger (latest 100)</h2>
        <div className="overflow-x-auto rounded-xl border border-neutral-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-neutral-50 text-left text-xs uppercase tracking-wide text-neutral-500">
              <tr>
                <th className="px-4 py-2">Label</th>
                <th className="px-4 py-2">Hospital</th>
                <th className="px-4 py-2">Mfr</th>
                <th className="px-4 py-2">Model</th>
                <th className="px-4 py-2">Stage</th>
                <th className="px-4 py-2">Crit.</th>
                <th className="px-4 py-2">Cost (Rs)</th>
                <th className="px-4 py-2">Book (Rs)</th>
                <th className="px-4 py-2">Life</th>
              </tr>
            </thead>
            <tbody>
              {equipment.length === 0 ? (
                <tr><td className="px-4 py-3 text-neutral-500" colSpan={9}>No equipment registered.</td></tr>
              ) : (
                equipment.map((e) => (
                  <tr key={e.id} className="border-t border-neutral-100">
                    <td className="px-4 py-2 font-medium">{e.equipment_label}</td>
                    <td className="px-4 py-2">{e.hospital_name ?? "-"}</td>
                    <td className="px-4 py-2">{e.manufacturer ?? "-"}</td>
                    <td className="px-4 py-2">{e.model_number ?? "-"}</td>
                    <td className="px-4 py-2">{e.lifecycle_stage}</td>
                    <td className="px-4 py-2">{e.criticality_band}</td>
                    <td className="px-4 py-2 tabular-nums">{formatNumber(e.purchase_cost_rupees)}</td>
                    <td className="px-4 py-2 tabular-nums">{formatNumber(e.current_book_value_rupees)}</td>
                    <td className="px-4 py-2 tabular-nums">{e.useful_life_years}y</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-lg font-semibold">Recent events (latest 50)</h2>
        <div className="overflow-x-auto rounded-xl border border-neutral-200 bg-white">
          <table className="min-w-full text-sm">
            <thead className="bg-neutral-50 text-left text-xs uppercase tracking-wide text-neutral-500">
              <tr>
                <th className="px-4 py-2">When</th>
                <th className="px-4 py-2">Equipment</th>
                <th className="px-4 py-2">Kind</th>
                <th className="px-4 py-2">Description</th>
                <th className="px-4 py-2">Value (Rs)</th>
              </tr>
            </thead>
            <tbody>
              {events.length === 0 ? (
                <tr><td className="px-4 py-3 text-neutral-500" colSpan={5}>No events logged.</td></tr>
              ) : (
                events.map((ev) => (
                  <tr key={ev.id} className="border-t border-neutral-100">
                    <td className="px-4 py-2 tabular-nums text-neutral-600">
                      {new Date(ev.happened_at).toISOString().slice(0, 16).replace("T", " ")}
                    </td>
                    <td className="px-4 py-2">{ev.equipment_label ?? "-"}</td>
                    <td className="px-4 py-2">{ev.event_kind}</td>
                    <td className="px-4 py-2 text-neutral-600">{ev.description ?? "-"}</td>
                    <td className="px-4 py-2 tabular-nums">{formatNumber(ev.value_rupees)}</td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
