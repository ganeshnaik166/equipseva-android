import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Equipment category snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  categories_total: number;
  categories_active: number;
  categories_repair_scope: number;
  categories_spare_part_scope: number;
  categories_both_scope: number;
  taxonomy_in_scope_v04: number;
  taxonomy_out_of_scope_v04: number;
  jobs_distinct_types_90d: number;
  jobs_top_category: string;
  jobs_top_category_count_90d: number;
  jobs_unspecified_90d: number;
  amc_distinct_categories_active: number;
  code_red_distinct_types_90d: number;
  spare_parts_distinct_cats_active: number;
  categories_updated_30d: number;
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

export default async function EquipmentCategorySnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_equipment_category_snapshot_summary");
  if (error) throw new Error(`founder_equipment_category_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Equipment category snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">13-KPI catalog/taxonomy mix · scope gate · 90d activity · pair with /equipment-type-breakdown</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Categories total" val={formatNumber(r.categories_total)} sub={`${formatNumber(r.categories_active)} active`} />
          <Card title="Repair scope" val={formatNumber(r.categories_repair_scope)} sub="active only" />
          <Card title="Spare-part scope" val={formatNumber(r.categories_spare_part_scope)} sub="active only" />
          <Card title="Both scopes" val={formatNumber(r.categories_both_scope)} sub="shared catalog" />
          <Card title="In scope v0.4" val={formatNumber(r.taxonomy_in_scope_v04)} ok sub="allowed_in_v04=true" />
          <Card title="Out of scope v0.4" val={formatNumber(r.taxonomy_out_of_scope_v04)} danger={r.taxonomy_out_of_scope_v04 > 0} sub="MDR Class C/D + AERB" />
          <Card title="Job types (90d)" val={formatNumber(r.jobs_distinct_types_90d)} sub="distinct equipment_type" />
          <Card title="Top category (90d)" val={r.jobs_top_category} sub={`${formatNumber(r.jobs_top_category_count_90d)} jobs`} />
          <Card title="Unspecified jobs (90d)" val={formatNumber(r.jobs_unspecified_90d)} danger={r.jobs_unspecified_90d > 0} sub="missing taxonomy tag" />
          <Card title="AMC categories live" val={formatNumber(r.amc_distinct_categories_active)} sub="active+paused contracts" />
          <Card title="Code Red types (90d)" val={formatNumber(r.code_red_distinct_types_90d)} sub="emergency mix" />
          <Card title="Spare-parts cats live" val={formatNumber(r.spare_parts_distinct_cats_active)} sub="is_active catalog" />
          <Card title="Catalog updated 30d" val={formatNumber(r.categories_updated_30d)} sub="curator activity" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}
