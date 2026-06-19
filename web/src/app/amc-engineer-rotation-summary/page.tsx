import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC engineer rotation summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_active_contracts: number;
  contracts_with_rotation: number;
  contracts_no_fallback: number;
  contracts_solo_primary_only: number;
  total_rotation_seats: number;
  active_rotation_seats: number;
  inactive_rotation_seats: number;
  distinct_engineers_rostered: number;
  avg_rotation_depth: number;
  max_rotation_depth: number;
  median_rotation_depth: number;
  engineers_overloaded_5plus: number;
  engineers_in_single_contract: number;
  unverified_engineers_in_rotation: number;
  unavailable_engineers_in_rotation: number;
  rotation_seats_added_7d: number;
  rotation_seats_added_30d: number;
  contracts_primary_unverified: number;
  contracts_primary_unavailable: number;
  top_loaded_engineer_id: string | null;
  top_loaded_engineer_name: string | null;
  top_loaded_active_contract_count: number;
};

function Card({ label, value, tone }: { label: string; value: string; tone?: "ok" | "warn" | "danger" | "muted" }) {
  const color =
    tone === "ok" ? "var(--color-ok)" :
    tone === "warn" ? "var(--color-warn)" :
    tone === "danger" ? "var(--color-danger)" :
    tone === "muted" ? "var(--color-muted)" :
    "var(--color-fg)";
  return (
    <div className="rounded-md border border-[var(--color-border)] p-3">
      <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-lg font-semibold tabular-nums" style={{ color }}>{value}</div>
    </div>
  );
}

export default async function AmcEngineerRotationSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_engineer_rotation_summary");
  if (error) throw new Error(`founder_amc_engineer_rotation_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const r = rows[0];

  if (!r) {
    return (
      <div className="space-y-6">
        <header>
          <h1 className="text-xl font-semibold">AMC engineer rotation summary</h1>
        </header>
        <p className="text-sm text-[var(--color-muted)]">No active AMC contracts yet.</p>
      </div>
    );
  }

  const noFallbackPct =
    r.total_active_contracts > 0
      ? Math.round((r.contracts_no_fallback / r.total_active_contracts) * 100)
      : 0;
  const overloadedTone: "ok" | "warn" | "danger" =
    r.engineers_overloaded_5plus === 0 ? "ok" : r.engineers_overloaded_5plus <= 2 ? "warn" : "danger";
  const noFallbackTone: "ok" | "warn" | "danger" =
    noFallbackPct === 0 ? "ok" : noFallbackPct <= 20 ? "warn" : "danger";

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC engineer rotation summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Roster load & rotation depth across active AMC contracts · v21 amc_engineer_rotation
        </span>
      </header>

      <section className="space-y-2">
        <h2 className="text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">Coverage</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="Active contracts" value={formatNumber(r.total_active_contracts)} />
          <Card label="With rotation seats" value={formatNumber(r.contracts_with_rotation)} tone="ok" />
          <Card label="No fallback (primary only)" value={`${formatNumber(r.contracts_no_fallback)} (${noFallbackPct}%)`} tone={noFallbackTone} />
          <Card label="Solo primary, depth=1" value={formatNumber(r.contracts_solo_primary_only)} tone="muted" />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">Rotation depth</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="Avg depth" value={Number(r.avg_rotation_depth).toFixed(2)} />
          <Card label="Median depth" value={Number(r.median_rotation_depth).toFixed(2)} />
          <Card label="Max depth" value={formatNumber(r.max_rotation_depth)} />
          <Card label="Distinct engineers rostered" value={formatNumber(r.distinct_engineers_rostered)} />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">Seats</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="Total seats" value={formatNumber(r.total_rotation_seats)} />
          <Card label="Active seats" value={formatNumber(r.active_rotation_seats)} tone="ok" />
          <Card label="Inactive seats (removed)" value={formatNumber(r.inactive_rotation_seats)} tone="muted" />
          <Card label="Seats added 7d / 30d" value={`${formatNumber(r.rotation_seats_added_7d)} / ${formatNumber(r.rotation_seats_added_30d)}`} />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">Engineer load</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="Overloaded (5+ contracts)" value={formatNumber(r.engineers_overloaded_5plus)} tone={overloadedTone} />
          <Card label="In single contract" value={formatNumber(r.engineers_in_single_contract)} tone="muted" />
          <Card label="Unverified in rotation" value={formatNumber(r.unverified_engineers_in_rotation)} tone={r.unverified_engineers_in_rotation === 0 ? "ok" : "danger"} />
          <Card label="Unavailable in rotation" value={formatNumber(r.unavailable_engineers_in_rotation)} tone={r.unavailable_engineers_in_rotation === 0 ? "ok" : "warn"} />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">Primary risk</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Card label="Primary unverified" value={formatNumber(r.contracts_primary_unverified)} tone={r.contracts_primary_unverified === 0 ? "ok" : "danger"} />
          <Card label="Primary unavailable" value={formatNumber(r.contracts_primary_unavailable)} tone={r.contracts_primary_unavailable === 0 ? "ok" : "warn"} />
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-xs font-medium uppercase tracking-wide text-[var(--color-muted)]">Top-loaded engineer</h2>
        <div className="rounded-md border border-[var(--color-border)] p-3 text-sm">
          {r.top_loaded_engineer_id ? (
            <>
              <span className="font-medium">{r.top_loaded_engineer_name ?? "(unnamed)"}</span>
              <span className="ml-2 text-[var(--color-muted)]">
                rostered on {formatNumber(r.top_loaded_active_contract_count)} active contract{r.top_loaded_active_contract_count === 1 ? "" : "s"}
              </span>
            </>
          ) : (
            <span className="text-[var(--color-muted)]">No engineers rostered yet.</span>
          )}
        </div>
      </section>
    </div>
  );
}
