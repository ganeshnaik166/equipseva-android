import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type Kpis = {
  trips_7d: number | null;
  trips_30d: number | null;
  trips_90d: number | null;
  active_engineers_30d: number | null;
  total_distance_km_30d: number | null;
  total_on_site_hours_30d: number | null;
  open_follow_ups: number | null;
  overdue_follow_ups: number | null;
  avg_rating_30d: number | null;
};

export default async function FounderEngineerTripReportPage() {
  const sb = await getSupabaseServerClient();

  const kpisRes = await sb.rpc("founder_engineer_trip_kpis");
  const recentRes = await sb.rpc("founder_engineer_trip_report_recent", { p_limit: 100 });
  const rollupRes = await sb.rpc("founder_engineer_trip_frequency_rollup", { p_days: 90 });
  const followupsRes = await sb.rpc("founder_engineer_trip_followups_pending");
  const byHospitalRes = await sb.rpc("founder_engineer_trip_by_hospital", { p_days: 90 });
  const dailyRes = await sb.rpc("founder_engineer_trip_daily_series", { p_days: 30 });

  const kpis: Kpis = (Array.isArray(kpisRes.data) ? kpisRes.data[0] : kpisRes.data) ?? {
    trips_7d: 0, trips_30d: 0, trips_90d: 0, active_engineers_30d: 0,
    total_distance_km_30d: 0, total_on_site_hours_30d: 0,
    open_follow_ups: 0, overdue_follow_ups: 0, avg_rating_30d: 0,
  };
  const recent: any[] = recentRes.data ?? [];
  const rollup: any[] = rollupRes.data ?? [];
  const followups: any[] = followupsRes.data ?? [];
  const byHospital: any[] = byHospitalRes.data ?? [];
  const daily: any[] = dailyRes.data ?? [];

  const recentCols: Column<any>[] = [
    { key: "visit_date", header: "Visit", render: (r: any) => r.visit_date ?? "—" },
    { key: "engineer_name", header: "Engineer", render: (r: any) => r.engineer_name ?? "—" },
    { key: "hospital_name", header: "Hospital", render: (r: any) => r.hospital_name ?? "—" },
    { key: "distance_km", header: "Distance (km)", render: (r: any) => r.distance_km ?? "—" },
    { key: "time_on_site_minutes", header: "On-site (min)", render: (r: any) => r.time_on_site_minutes ?? "—" },
    { key: "travel_minutes", header: "Travel (min)", render: (r: any) => r.travel_minutes ?? "—" },
    { key: "interaction_rating", header: "Rating", render: (r: any) => r.interaction_rating ?? "—" },
    { key: "follow_up_required", header: "Follow-up", render: (r: any) => (r.follow_up_required ? "yes" : "no") },
  ];

  const rollupCols: Column<any>[] = [
    { key: "engineer_name", header: "Engineer", render: (r: any) => r.engineer_name ?? "—" },
    { key: "tier", header: "Tier", render: (r: any) => r.tier ?? "—" },
    { key: "total_trips", header: "Trips (90d)", render: (r: any) => r.total_trips ?? "—" },
    { key: "trips_last_7d", header: "7d", render: (r: any) => r.trips_last_7d ?? "—" },
    { key: "trips_last_30d", header: "30d", render: (r: any) => r.trips_last_30d ?? "—" },
    { key: "total_distance_km", header: "Distance km", render: (r: any) => r.total_distance_km ?? "—" },
    { key: "total_on_site_hours", header: "On-site hrs", render: (r: any) => r.total_on_site_hours ?? "—" },
    { key: "avg_interaction_rating", header: "Avg rating", render: (r: any) => r.avg_interaction_rating ?? "—" },
    { key: "follow_ups_open", header: "Open f/u", render: (r: any) => r.follow_ups_open ?? "—" },
    { key: "last_visit_date", header: "Last visit", render: (r: any) => r.last_visit_date ?? "—" },
  ];

  const followupCols: Column<any>[] = [
    { key: "engineer_name", header: "Engineer", render: (r: any) => r.engineer_name ?? "—" },
    { key: "hospital_name", header: "Hospital", render: (r: any) => r.hospital_name ?? "—" },
    { key: "visit_date", header: "Visit", render: (r: any) => r.visit_date ?? "—" },
    { key: "follow_up_due_date", header: "Due", render: (r: any) => r.follow_up_due_date ?? "—" },
    { key: "days_until_due", header: "Days", render: (r: any) => r.days_until_due ?? "—" },
    { key: "follow_up_notes", header: "Notes", render: (r: any) => r.follow_up_notes ?? "—" },
  ];

  const hospitalCols: Column<any>[] = [
    { key: "hospital_name", header: "Hospital", render: (r: any) => r.hospital_name ?? "—" },
    { key: "state", header: "State", render: (r: any) => r.state ?? "—" },
    { key: "total_visits", header: "Visits", render: (r: any) => r.total_visits ?? "—" },
    { key: "distinct_engineers", header: "Engineers", render: (r: any) => r.distinct_engineers ?? "—" },
    { key: "total_on_site_hours", header: "On-site hrs", render: (r: any) => r.total_on_site_hours ?? "—" },
    { key: "avg_interaction_rating", header: "Avg rating", render: (r: any) => r.avg_interaction_rating ?? "—" },
    { key: "last_visit_date", header: "Last visit", render: (r: any) => r.last_visit_date ?? "—" },
  ];

  const dailyCols: Column<any>[] = [
    { key: "day", header: "Day", render: (r: any) => r.day ?? "—" },
    { key: "trips", header: "Trips", render: (r: any) => r.trips ?? "—" },
    { key: "distance_km", header: "Distance km", render: (r: any) => r.distance_km ?? "—" },
    { key: "on_site_hours", header: "On-site hrs", render: (r: any) => r.on_site_hours ?? "—" },
  ];

  return (
    <main className="mx-auto max-w-7xl px-6 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">Engineer Trip-Report Log</h1>
        <p className="text-sm text-gray-600">Post-visit trip logs and per-engineer trip-frequency rollup (r1659).</p>
      </header>

      <section className="mb-8 grid grid-cols-2 gap-3 md:grid-cols-5">
        <Kpi label="Trips 7d" value={kpis.trips_7d} />
        <Kpi label="Trips 30d" value={kpis.trips_30d} />
        <Kpi label="Trips 90d" value={kpis.trips_90d} />
        <Kpi label="Active engineers 30d" value={kpis.active_engineers_30d} />
        <Kpi label="Distance km 30d" value={kpis.total_distance_km_30d} />
        <Kpi label="On-site hrs 30d" value={kpis.total_on_site_hours_30d} />
        <Kpi label="Open follow-ups" value={kpis.open_follow_ups} />
        <Kpi label="Overdue follow-ups" value={kpis.overdue_follow_ups} />
        <Kpi label="Avg rating 30d" value={kpis.avg_rating_30d} />
      </section>

      <Section title="Per-engineer trip frequency (90d)">
        <DataTable
          columns={rollupCols}
          rows={rollup}
          rowKey={(r: any, i: number) => String(r.engineer_user_id ?? i)}
        />
      </Section>

      <Section title="Pending follow-ups">
        <DataTable
          columns={followupCols}
          rows={followups}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Recent trip reports">
        <DataTable
          columns={recentCols}
          rows={recent}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="By hospital (90d)">
        <DataTable
          columns={hospitalCols}
          rows={byHospital}
          rowKey={(r: any, i: number) => String(r.hospital_org_id ?? i)}
        />
      </Section>

      <Section title="Daily volume (30d)">
        <DataTable
          columns={dailyCols}
          rows={daily}
          rowKey={(r: any, i: number) => String(r.day ?? i)}
        />
      </Section>
    </main>
  );
}

function Kpi({ label, value }: { label: string; value: number | null | undefined }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold">{value ?? "—"}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section className="mb-8">
      <h2 className="mb-3 text-lg font-medium">{title}</h2>
      {children}
    </section>
  );
}
