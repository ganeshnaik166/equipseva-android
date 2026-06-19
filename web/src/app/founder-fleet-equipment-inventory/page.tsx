import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Fleet equipment inventory — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Summary = {
  total_equipment_under_amc_estimate: number;
  total_unique_categories: number;
  total_unique_manufacturers: number;
  top_category: string;
  top_category_count: number;
  top_manufacturer: string;
  top_manufacturer_count: number;
  equipment_with_5plus_visits_180d: number;
  equipment_with_zero_visits_180d_estimate: number;
  avg_visits_per_equipment_180d: number;
  equipment_categories_with_dental: number;
  equipment_categories_with_radiology: number;
  newest_equipment_seen_at: string | null;
  generated_at: string;
};

type CatRow = {
  equipment_category: string;
  unique_units: number;
  unique_manufacturers: number;
  total_visits_365d: number;
  visits_180d: number;
  last_seen_at: string | null;
};

type UnitRow = {
  equipment_category: string;
  manufacturer: string;
  model: string;
  serial: string;
  visits_365d: number;
  visits_180d: number;
  last_seen_at: string | null;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  const d = new Date(s);
  if (Number.isNaN(d.getTime())) return "—";
  return d.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" });
}

export default async function FounderFleetEquipmentInventoryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [sumRes, catRes, unitRes] = await Promise.all([
    supabase.rpc("founder_fleet_equipment_inventory_summary"),
    supabase.rpc("founder_fleet_equipment_inventory_by_category", { p_limit: 30 }),
    supabase.rpc("founder_fleet_equipment_inventory_top_units", { p_limit: 50 }),
  ]);
  if (sumRes.error)  throw new Error(`founder_fleet_equipment_inventory_summary: ${sumRes.error.message}`);
  if (catRes.error)  throw new Error(`founder_fleet_equipment_inventory_by_category: ${catRes.error.message}`);
  if (unitRes.error) throw new Error(`founder_fleet_equipment_inventory_top_units: ${unitRes.error.message}`);

  const s = ((sumRes.data ?? [])[0] ?? null) as Summary | null;
  const cats  = (catRes.data ?? []) as CatRow[];
  const units = (unitRes.data ?? []) as UnitRow[];

  const cards: Array<{ label: string; value: string; hint?: string }> = s ? [
    { label: "Equipment under AMC (est.)", value: formatNumber(s.total_equipment_under_amc_estimate), hint: "distinct serials seen, 365d" },
    { label: "Unique categories",          value: formatNumber(s.total_unique_categories) },
    { label: "Unique manufacturers",       value: formatNumber(s.total_unique_manufacturers) },
    { label: "Top category",               value: s.top_category, hint: `${formatNumber(s.top_category_count)} units` },
    { label: "Top manufacturer",           value: s.top_manufacturer, hint: `${formatNumber(s.top_manufacturer_count)} units` },
    { label: "High-use units (5+ / 180d)", value: formatNumber(s.equipment_with_5plus_visits_180d) },
    { label: "Zero-visit units (180d)",    value: formatNumber(s.equipment_with_zero_visits_180d_estimate), hint: "placeholder · needs inventory list" },
    { label: "Avg visits / unit · 180d",   value: Number(s.avg_visits_per_equipment_180d ?? 0).toFixed(2) },
    { label: "Dental categories",          value: formatNumber(s.equipment_categories_with_dental) },
    { label: "Radiology categories",       value: formatNumber(s.equipment_categories_with_radiology) },
    { label: "Newest seen",                value: fmtDate(s.newest_equipment_seen_at) },
    { label: "Generated at",               value: fmtDate(s.generated_at) },
    { label: "Window · long",              value: "365d" },
    { label: "Window · short",             value: "180d" },
  ] : [];

  const catCols: Column<CatRow>[] = [
    { key: "c", header: "Category",        render: (r) => <span className="text-xs font-medium">{r.equipment_category}</span> },
    { key: "u", header: "Unique units",    render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.unique_units)}</span> },
    { key: "m", header: "Mfrs",            render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.unique_manufacturers)}</span> },
    { key: "v", header: "Visits · 365d",   render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.total_visits_365d)}</span> },
    { key: "s", header: "Visits · 180d",   render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.visits_180d)}</span> },
    { key: "l", header: "Last seen",       render: (r) => <span className="text-xs tabular-nums">{fmtDate(r.last_seen_at)}</span> },
  ];

  const unitCols: Column<UnitRow>[] = [
    { key: "c", header: "Category",        render: (r) => <span className="text-xs">{r.equipment_category}</span> },
    { key: "m", header: "Manufacturer",    render: (r) => <span className="text-xs font-medium">{r.manufacturer}</span> },
    { key: "d", header: "Model",           render: (r) => <span className="text-xs">{r.model}</span> },
    { key: "s", header: "Serial",          render: (r) => <span className="text-xs font-mono">{r.serial}</span> },
    { key: "v", header: "Visits · 365d",   render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.visits_365d)}</span> },
    { key: "x", header: "Visits · 180d",   render: (r) => <span className="text-xs tabular-nums">{formatNumber(r.visits_180d)}</span> },
    { key: "l", header: "Last seen",       render: (r) => <span className="text-xs tabular-nums">{fmtDate(r.last_seen_at)}</span> },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Fleet equipment inventory</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Equipment fingerprints from AMC jobs · category · manufacturer · model · serial · 365d window
        </span>
      </header>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 xl:grid-cols-7">
        {cards.map((c) => (
          <div key={c.label} className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{c.label}</div>
            <div className="mt-1 text-base font-semibold tabular-nums break-words">{c.value}</div>
            {c.hint ? <div className="mt-0.5 text-[10px] text-[var(--color-muted)]">{c.hint}</div> : null}
          </div>
        ))}
      </section>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold">Top categories · 30</h2>
        <DataTable
          columns={catCols}
          rows={cats}
          rowKey={(r) => r.equipment_category}
          emptyMessage="No AMC equipment categories seen in the last 365d."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-sm font-semibold">Top equipment units by visit count · 50</h2>
        <DataTable
          columns={unitCols}
          rows={units}
          rowKey={(r) => `${r.equipment_category}|${r.manufacturer}|${r.model}|${r.serial}`}
          emptyMessage="No AMC equipment units seen in the last 365d."
        />
      </section>

      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4 text-xs text-[var(--color-muted)] leading-relaxed">
        <div className="font-semibold text-[var(--color-fg)] mb-1">What this informs</div>
        <ul className="list-disc pl-4 space-y-1">
          <li>
            <span className="text-[var(--color-fg)]">Spare-parts inventory:</span> top categories + top manufacturers
            tell us which SKUs to pre-stock with our supplier-onboarded sellers · prioritise the top-N category × manufacturer pairs.
          </li>
          <li>
            <span className="text-[var(--color-fg)]">Supplier onboarding:</span> manufacturers we already service heavily
            on AMC but don{"'"}t yet have on the marketplace are the priority targets for outbound.
          </li>
          <li>
            <span className="text-[var(--color-fg)]">Engineer specialisation:</span> high-use categories signal where
            to invest in supervised training rounds and Tier-A engineer recruitment.
          </li>
          <li>
            <span className="text-[var(--color-fg)]">Inventory completeness gap:</span> zero-visit estimate is a placeholder
            (0) until we ingest a complete equipment census per hospital — until then we only see units that have actually
            had a job, not idle gear in the corner room.
          </li>
          <li>
            High-use units ({">"}= 5 visits in 180d) are candidates for an explicit replacement / refurbishment conversation
            with the hospital — failing equipment burns engineer hours and bleeds SLA credit on our books.
          </li>
        </ul>
      </section>
    </div>
  );
}
