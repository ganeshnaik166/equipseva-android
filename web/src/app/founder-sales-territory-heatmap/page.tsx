import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";
import Link from "next/link";

export const metadata = { title: "Founder sales territory heatmap — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_active_cities: number;
  total_active_pincodes: number;
  top_city: string;
  top_city_jobs_90d: number;
  top_pincode: string;
  top_pincode_jobs_90d: number;
  cities_with_zero_jobs_30d: number;
  total_engineers_active: number;
  engineers_per_active_city_avg: number;
  demand_signal_strong_count: number;
  demand_signal_weak_count: number;
  generated_at: string;
};

type PincodeRow = {
  pincode: string;
  city: string;
  state: string;
  total_jobs_90d: number;
  unique_hospitals: number;
  engineers_assigned: number;
  amc_contracts_active: number;
  avg_minutes_to_response: number;
  demand_band: string;
};

type CityRow = {
  city: string;
  state: string;
  total_jobs_90d: number;
  unique_hospitals: number;
  engineers_assigned: number;
  amc_contracts_active: number;
  avg_minutes_to_response: number;
  demand_band: string;
};

function bandClass(band: string): string {
  switch (band) {
    case "strong": return "bg-green-100 text-[var(--color-ok)] font-semibold";
    case "medium": return "bg-blue-100 text-[var(--color-info)]";
    case "weak":   return "bg-yellow-100 text-[var(--color-warn)]";
    case "zero":   return "bg-red-100 text-[var(--color-danger)]";
    default:        return "text-[var(--color-muted)]";
  }
}

function Card({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="rounded border border-[var(--color-border)] bg-white p-3">
      <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-xl font-semibold tabular-nums">{value}</div>
      {sub ? <div className="mt-0.5 text-[10px] text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

function fmtMin(n: number | null | undefined): string {
  if (n == null || Number(n) <= 0) return "—";
  const v = Number(n);
  if (v >= 60) return `${(v / 60).toFixed(1)} h`;
  return `${v.toFixed(0)} m`;
}

export default async function FounderSalesTerritoryHeatmapPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [sumRes, pinRes, cityRes] = await Promise.all([
    supabase.rpc("founder_sales_territory_heatmap_summary"),
    supabase.rpc("founder_sales_territory_by_pincode", { p_limit: 100 }),
    supabase.rpc("founder_sales_territory_by_city",    { p_limit: 50 }),
  ]);

  if (sumRes.error)  throw new Error(`founder_sales_territory_heatmap_summary: ${sumRes.error.message}`);
  if (pinRes.error)  throw new Error(`founder_sales_territory_by_pincode: ${pinRes.error.message}`);
  if (cityRes.error) throw new Error(`founder_sales_territory_by_city: ${cityRes.error.message}`);

  const sumArr = (Array.isArray(sumRes.data) ? sumRes.data : []) as SummaryRow[];
  const s = sumArr[0];
  const pins = (Array.isArray(pinRes.data) ? pinRes.data : []) as PincodeRow[];
  const cities = (Array.isArray(cityRes.data) ? cityRes.data : []) as CityRow[];

  return (
    <main className="mx-auto max-w-7xl space-y-4 p-4">
      <header className="space-y-1">
        <div className="flex items-center justify-between gap-2">
          <h1 className="text-lg font-semibold">Founder sales territory heatmap</h1>
          <Link href="/ops-index" className="text-xs text-[var(--color-muted)] hover:underline">ops-index</Link>
        </div>
        <p className="text-xs text-[var(--color-muted)]">
          Jobs density by pincode + city · 90d window · assignment opportunities · sourced from repair_jobs JOIN organizations (city/state/pincode).
        </p>
      </header>

      <section className="grid grid-cols-2 gap-2 md:grid-cols-3 lg:grid-cols-6">
        <Card label="Active cities (90d)"         value={s ? formatNumber(s.total_active_cities)   : "—"} sub="with ≥1 job" />
        <Card label="Active pincodes (90d)"       value={s ? formatNumber(s.total_active_pincodes) : "—"} sub="with ≥1 job" />
        <Card label="Top city"                     value={s ? s.top_city : "—"}    sub={s ? `${formatNumber(s.top_city_jobs_90d)} jobs · 90d` : ""} />
        <Card label="Top pincode"                  value={s ? s.top_pincode : "—"} sub={s ? `${formatNumber(s.top_pincode_jobs_90d)} jobs · 90d` : ""} />
        <Card label="Cities w/ 0 jobs 30d"         value={s ? formatNumber(s.cities_with_zero_jobs_30d) : "—"} sub="cooling territories" />
        <Card label="Active engineers"             value={s ? formatNumber(s.total_engineers_active)     : "—"} sub="verified KYC" />
        <Card label="Engineers / active city avg"  value={s ? `${s.engineers_per_active_city_avg}` : "—"} sub="supply density" />
        <Card label="Strong-demand pincodes"       value={s ? formatNumber(s.demand_signal_strong_count) : "—"} sub="≥10 jobs · 90d" />
        <Card label="Weak-demand pincodes"         value={s ? formatNumber(s.demand_signal_weak_count)   : "—"} sub="1-3 jobs · 90d" />
        <Card label="Top-100 pincodes"             value={formatNumber(pins.length)}   sub="below table" />
        <Card label="Top-50 cities"                value={formatNumber(cities.length)} sub="below table" />
        <Card label="Generated"                    value={s ? new Date(s.generated_at).toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" }) : "—"} sub="IST" />
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white">
        <header className="border-b border-[var(--color-border)] px-3 py-2 text-sm font-semibold">
          Top-100 pincodes · jobs density (90d)
          <span className="ml-2 text-xs text-[var(--color-muted)]">({pins.length})</span>
        </header>
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead className="bg-[var(--color-bg-soft)] text-left text-[var(--color-muted)]">
              <tr>
                <th className="px-2 py-2">Pincode</th>
                <th className="px-2 py-2">City</th>
                <th className="px-2 py-2">State</th>
                <th className="px-2 py-2 text-right">Jobs 90d</th>
                <th className="px-2 py-2 text-right">Hospitals</th>
                <th className="px-2 py-2 text-right">Engineers</th>
                <th className="px-2 py-2 text-right">AMC active</th>
                <th className="px-2 py-2 text-right">Avg response</th>
                <th className="px-2 py-2">Demand</th>
              </tr>
            </thead>
            <tbody>
              {pins.length === 0 ? (
                <tr><td className="px-2 py-3 text-[var(--color-muted)]" colSpan={9}>No pincode activity in 90d.</td></tr>
              ) : pins.map((r, i) => (
                <tr key={`${r.pincode}-${i}`} className="border-t border-[var(--color-border)]">
                  <td className="px-2 py-2 font-mono font-medium">{r.pincode}</td>
                  <td className="px-2 py-2">{r.city || <span className="text-[var(--color-muted)]">—</span>}</td>
                  <td className="px-2 py-2 text-[var(--color-muted)]">{r.state || "—"}</td>
                  <td className="px-2 py-2 text-right tabular-nums font-medium">{formatNumber(r.total_jobs_90d)}</td>
                  <td className="px-2 py-2 text-right tabular-nums">{formatNumber(r.unique_hospitals)}</td>
                  <td className="px-2 py-2 text-right tabular-nums">{formatNumber(r.engineers_assigned)}</td>
                  <td className="px-2 py-2 text-right tabular-nums text-[var(--color-ok)]">{formatNumber(r.amc_contracts_active)}</td>
                  <td className="px-2 py-2 text-right tabular-nums">{fmtMin(r.avg_minutes_to_response)}</td>
                  <td className="px-2 py-2"><span className={`rounded px-1.5 py-0.5 text-[10px] ${bandClass(r.demand_band)}`}>{r.demand_band}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded border border-[var(--color-border)] bg-white">
        <header className="border-b border-[var(--color-border)] px-3 py-2 text-sm font-semibold">
          Top-50 cities · jobs density (90d)
          <span className="ml-2 text-xs text-[var(--color-muted)]">({cities.length})</span>
        </header>
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead className="bg-[var(--color-bg-soft)] text-left text-[var(--color-muted)]">
              <tr>
                <th className="px-2 py-2">City</th>
                <th className="px-2 py-2">State</th>
                <th className="px-2 py-2 text-right">Jobs 90d</th>
                <th className="px-2 py-2 text-right">Hospitals</th>
                <th className="px-2 py-2 text-right">Engineers</th>
                <th className="px-2 py-2 text-right">AMC active</th>
                <th className="px-2 py-2 text-right">Avg response</th>
                <th className="px-2 py-2">Demand</th>
              </tr>
            </thead>
            <tbody>
              {cities.length === 0 ? (
                <tr><td className="px-2 py-3 text-[var(--color-muted)]" colSpan={8}>No city activity in 90d.</td></tr>
              ) : cities.map((r, i) => (
                <tr key={`${r.city}-${i}`} className="border-t border-[var(--color-border)]">
                  <td className="px-2 py-2 font-medium">{r.city}</td>
                  <td className="px-2 py-2 text-[var(--color-muted)]">{r.state || "—"}</td>
                  <td className="px-2 py-2 text-right tabular-nums font-medium">{formatNumber(r.total_jobs_90d)}</td>
                  <td className="px-2 py-2 text-right tabular-nums">{formatNumber(r.unique_hospitals)}</td>
                  <td className="px-2 py-2 text-right tabular-nums">{formatNumber(r.engineers_assigned)}</td>
                  <td className="px-2 py-2 text-right tabular-nums text-[var(--color-ok)]">{formatNumber(r.amc_contracts_active)}</td>
                  <td className="px-2 py-2 text-right tabular-nums">{fmtMin(r.avg_minutes_to_response)}</td>
                  <td className="px-2 py-2"><span className={`rounded px-1.5 py-0.5 text-[10px] ${bandClass(r.demand_band)}`}>{r.demand_band}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded border border-[var(--color-border)] bg-[var(--color-bg-soft)] p-3 text-xs text-[var(--color-muted)] space-y-1">
        <div className="font-semibold text-[var(--color-fg)]">Reading the heatmap</div>
        <div>
          Use this to identify under-served pincodes for engineer recruitment + hospital outreach. AMC density divided by population gives true market penetration.
        </div>
        <div>
          Demand bands · pincode: <span className="text-[var(--color-ok)] font-semibold">strong</span> {">="} 10 jobs · <span className="text-[var(--color-info)]">medium</span> 4-9 · <span className="text-[var(--color-warn)]">weak</span> 1-3 · <span className="text-[var(--color-danger)]">zero</span> 0
        </div>
        <div>
          Demand bands · city: <span className="text-[var(--color-ok)] font-semibold">strong</span> {">="} 30 jobs · <span className="text-[var(--color-info)]">medium</span> 10-29 · <span className="text-[var(--color-warn)]">weak</span> 1-9 · <span className="text-[var(--color-danger)]">zero</span> 0
        </div>
        <div>
          Engineers count = DISTINCT engineer_id assigned to repair_jobs in window (assignment-side, not residency). Avg response = mean accepted_at − created_at across responded jobs.
        </div>
      </section>
    </main>
  );
}
