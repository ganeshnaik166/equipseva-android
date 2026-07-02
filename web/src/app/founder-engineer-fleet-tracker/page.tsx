import Link from "next/link";
import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatNumber, formatRelativeTime, shortId } from "@/lib/format";

export const metadata = { title: "Engineer Fleet Tracker — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  vehicles_total: number | null;
  vehicles_active: number | null;
  vehicles_maintenance: number | null;
  vehicles_retired: number | null;
  vehicles_damaged_lost: number | null;
  engineers_with_vehicle: number | null;
  company_owned_count: number | null;
  engineer_owned_count: number | null;
  rental_count: number | null;
  trips_total: number | null;
  trips_30d: number | null;
  trips_90d: number | null;
  total_distance_km: number | null;
  total_fuel_cost_rupees: number | null;
  insurance_expiring_30d: number | null;
  puc_expiring_30d: number | null;
};

type VehicleRow = {
  vehicle_id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  vehicle_kind: string | null;
  registration_number: string | null;
  make_model: string | null;
  ownership_kind: string | null;
  status: string | null;
  allotted_at: string | null;
  insurance_expiry: string | null;
  puc_expiry: string | null;
  last_service_at: string | null;
  total_odometer_km: number | null;
  created_at: string;
};

type TripRow = {
  trip_id: string;
  vehicle_id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  registration_number: string | null;
  trip_purpose: string | null;
  repair_job_id: string | null;
  distance_km: number | null;
  fuel_cost_rupees: number | null;
  started_at: string | null;
  ended_at: string | null;
  created_at: string;
};

type ExpiringDocRow = {
  vehicle_id: string;
  engineer_email: string | null;
  registration_number: string | null;
  make_model: string | null;
  doc_kind: string | null;
  expires_on: string | null;
  days_until_expiry: number | null;
};

function Kpi({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-white p-4">
      <div className="text-xs text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-2xl font-semibold tabular-nums">{value}</div>
      {hint && <div className="mt-1 text-xs text-[var(--color-muted)]">{hint}</div>}
    </div>
  );
}

export default async function FounderEngineerFleetTrackerPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [summaryRes, vehiclesRes, tripsRes, docsRes] = await Promise.all([
    supabase.rpc("founder_engineer_fleet_summary"),
    supabase.rpc("founder_engineer_fleet_vehicles_recent", { p_limit: 50 }),
    supabase.rpc("founder_engineer_fleet_trips_recent", { p_limit: 50 }),
    supabase.rpc("founder_engineer_fleet_expiring_docs", { p_days: 30 }),
  ]);
  if (summaryRes.error) throw new Error(`founder_engineer_fleet_summary: ${summaryRes.error.message}`);
  if (vehiclesRes.error) throw new Error(`founder_engineer_fleet_vehicles_recent: ${vehiclesRes.error.message}`);
  if (tripsRes.error) throw new Error(`founder_engineer_fleet_trips_recent: ${tripsRes.error.message}`);
  if (docsRes.error) throw new Error(`founder_engineer_fleet_expiring_docs: ${docsRes.error.message}`);

  const summaryArr = (summaryRes.data ?? []) as SummaryRow[];
  const s: SummaryRow = summaryArr[0] ?? {
    vehicles_total: 0, vehicles_active: 0, vehicles_maintenance: 0, vehicles_retired: 0,
    vehicles_damaged_lost: 0, engineers_with_vehicle: 0, company_owned_count: 0,
    engineer_owned_count: 0, rental_count: 0, trips_total: 0, trips_30d: 0, trips_90d: 0,
    total_distance_km: 0, total_fuel_cost_rupees: 0, insurance_expiring_30d: 0, puc_expiring_30d: 0,
  };
  const vehicles = (vehiclesRes.data ?? []) as VehicleRow[];
  const trips = (tripsRes.data ?? []) as TripRow[];
  const docs = (docsRes.data ?? []) as ExpiringDocRow[];

  const docsTotal = (s.insurance_expiring_30d ?? 0) + (s.puc_expiring_30d ?? 0);
  const fuelPerKm = (s.total_distance_km ?? 0) > 0
    ? (Number(s.total_fuel_cost_rupees ?? 0) / Number(s.total_distance_km ?? 1)).toFixed(2)
    : "0.00";

  const vehCols: Column<VehicleRow>[] = [
    { key: "when", header: "Registered", render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span> },
    { key: "eng", header: "Engineer", render: (r) => r.engineer_email ?? shortId(r.engineer_user_id) },
    { key: "kind", header: "Kind", render: (r) => r.vehicle_kind ?? "—" },
    { key: "reg", header: "Reg #", render: (r) => r.registration_number ?? "—" },
    { key: "model", header: "Make/Model", render: (r) => r.make_model ?? "—" },
    {
      key: "own",
      header: "Ownership",
      render: (r) => {
        const o = (r.ownership_kind ?? "").toLowerCase();
        const cls = o === "company_owned"
          ? "bg-blue-100 text-blue-700"
          : o.startsWith("rental")
            ? "bg-purple-100 text-purple-700"
            : "bg-gray-100 text-gray-700";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r.ownership_kind ?? "—"}</span>;
      },
    },
    {
      key: "status",
      header: "Status",
      render: (r) => {
        const st = (r.status ?? "").toLowerCase();
        const cls = st === "active"
          ? "bg-green-100 text-[var(--color-ok)]"
          : st === "maintenance"
            ? "bg-yellow-100 text-[var(--color-warn)]"
            : st === "damaged" || st === "lost"
              ? "bg-red-100 text-[var(--color-danger)]"
              : "bg-gray-100 text-gray-600";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r.status ?? "—"}</span>;
      },
    },
    { key: "ins", header: "Insurance", render: (r) => r.insurance_expiry ?? "—" },
    { key: "puc", header: "PUC", render: (r) => r.puc_expiry ?? "—" },
    { key: "odo", header: "Odometer", render: (r) => formatNumber(r.total_odometer_km ?? 0) + " km" },
  ];

  const tripCols: Column<TripRow>[] = [
    { key: "when", header: "Logged", render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span> },
    { key: "eng", header: "Engineer", render: (r) => r.engineer_email ?? shortId(r.engineer_user_id) },
    { key: "reg", header: "Vehicle", render: (r) => r.registration_number ?? shortId(r.vehicle_id) },
    {
      key: "purpose",
      header: "Purpose",
      render: (r) => {
        const p = (r.trip_purpose ?? "").toLowerCase();
        const cls = p === "site_visit"
          ? "bg-blue-100 text-blue-700"
          : p === "personal_use_logged"
            ? "bg-orange-100 text-orange-700"
            : "bg-gray-100 text-gray-700";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r.trip_purpose ?? "—"}</span>;
      },
    },
    { key: "dist", header: "Distance", render: (r) => formatNumber(Number(r.distance_km ?? 0)) + " km" },
    { key: "fuel", header: "Fuel", render: (r) => "Rs " + formatNumber(Number(r.fuel_cost_rupees ?? 0)) },
    { key: "started", header: "Started", render: (r) => r.started_at ? formatRelativeTime(r.started_at) : "—" },
  ];

  return (
    <div className="space-y-6 p-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-semibold">Engineer Fleet Tracker</h1>
          <p className="text-sm text-[var(--color-muted)]">
            Vehicles, ownership, trips, fuel cost, and expiring statutory documents.
          </p>
        </div>
        <Link href="/ops" className="text-sm text-[var(--color-link)] hover:underline">
          {"<"} Ops home
        </Link>
      </div>

      {docsTotal > 0 && (
        <div className="rounded-lg border border-yellow-300 bg-yellow-50 p-4">
          <div className="text-sm font-semibold text-yellow-900">
            {docsTotal} statutory documents expiring within 30 days
          </div>
          <div className="mt-1 text-xs text-yellow-800">
            {s.insurance_expiring_30d ?? 0} insurance · {s.puc_expiring_30d ?? 0} PUC. Renew before lapse to keep engineers road-legal.
          </div>
        </div>
      )}

      <section>
        <h2 className="mb-3 text-lg font-semibold">Fleet snapshot</h2>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <Kpi label="Vehicles total" value={formatNumber(s.vehicles_total ?? 0)} />
          <Kpi label="Active" value={formatNumber(s.vehicles_active ?? 0)} />
          <Kpi label="In maintenance" value={formatNumber(s.vehicles_maintenance ?? 0)} />
          <Kpi label="Retired" value={formatNumber(s.vehicles_retired ?? 0)} />
          <Kpi label="Damaged / lost" value={formatNumber(s.vehicles_damaged_lost ?? 0)} hint="incident review" />
          <Kpi label="Engineers w/ vehicle" value={formatNumber(s.engineers_with_vehicle ?? 0)} />
          <Kpi label="Company-owned" value={formatNumber(s.company_owned_count ?? 0)} />
          <Kpi label="Engineer-owned" value={formatNumber(s.engineer_owned_count ?? 0)} />
          <Kpi label="Rentals" value={formatNumber(s.rental_count ?? 0)} hint="monthly + per-visit" />
          <Kpi label="Trips total" value={formatNumber(s.trips_total ?? 0)} />
          <Kpi label="Trips 30d" value={formatNumber(s.trips_30d ?? 0)} />
          <Kpi label="Trips 90d" value={formatNumber(s.trips_90d ?? 0)} />
          <Kpi label="Total distance" value={formatNumber(Number(s.total_distance_km ?? 0)) + " km"} />
          <Kpi label="Total fuel cost" value={"Rs " + formatNumber(Number(s.total_fuel_cost_rupees ?? 0))} />
          <Kpi label="Insurance expiring 30d" value={formatNumber(s.insurance_expiring_30d ?? 0)} hint="renew soon" />
          <Kpi label="PUC expiring 30d" value={formatNumber(s.puc_expiring_30d ?? 0)} hint={"Rs " + fuelPerKm + " / km"} />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Expiring documents</h2>
        {docs.length === 0 ? (
          <div className="rounded-lg border border-[var(--color-border)] bg-white p-4 text-sm text-[var(--color-muted)]">
            No expiring documents in the next 30 days.
          </div>
        ) : (
          <DataTable
            rows={docs}
            rowKey={(r) => r.vehicle_id + ":" + (r.doc_kind ?? "")}
            columns={[
              { key: "doc", header: "Doc", render: (r) => r.doc_kind ?? "—" },
              { key: "eng", header: "Engineer", render: (r) => r.engineer_email ?? "—" },
              { key: "reg", header: "Vehicle", render: (r) => r.registration_number ?? "—" },
              { key: "model", header: "Make/Model", render: (r) => r.make_model ?? "—" },
              { key: "exp", header: "Expires", render: (r) => r.expires_on ?? "—" },
              {
                key: "days",
                header: "Days left",
                render: (r) => {
                  const d = r.days_until_expiry ?? 0;
                  const cls = d <= 7 ? "text-[var(--color-danger)]" : d <= 14 ? "text-[var(--color-warn)]" : "text-[var(--color-muted)]";
                  return <span className={cls}>{d}</span>;
                },
              },
            ]}
          />
        )}
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Vehicles (recent 50)</h2>
        <DataTable rows={vehicles} rowKey={(r) => r.vehicle_id} columns={vehCols} />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">Trips (recent 50)</h2>
        <DataTable rows={trips} rowKey={(r) => r.trip_id} columns={tripCols} />
      </section>
    </div>
  );
}
