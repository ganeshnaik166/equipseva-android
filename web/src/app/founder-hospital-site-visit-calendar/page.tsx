import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';
import type { ReactNode } from 'react';

export const dynamic = 'force-dynamic';
export const revalidate = 0;

function Kpi({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="rounded-lg border border-neutral-200 bg-white p-3">
      <div className="text-xs text-neutral-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-neutral-900">{value}</div>
    </div>
  );
}

function fmtINR(rupees: number | null | undefined): string {
  const n = Number(rupees ?? 0);
  if (!Number.isFinite(n)) return "-";
  return new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 }).format(n);
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return "-";
  try { return new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }); } catch { return String(s); }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [kpisRes, upcomingRes, recentRes, perHospRes, redlineRes, outcomesRes, followupsRes] = await Promise.all([
    sb.rpc('founder_site_visit_kpis'),
    sb.rpc('founder_site_visit_upcoming', { p_limit: 100 }),
    sb.rpc('founder_site_visit_recent_completed', { p_limit: 100 }),
    sb.rpc('founder_site_visit_per_hospital'),
    sb.rpc('founder_site_visit_redline_90d'),
    sb.rpc('founder_site_visit_outcomes_by_kind'),
    sb.rpc('founder_site_visit_followups_due'),
  ]);

  const k: any = kpisRes.data ?? {};
  const upcoming: any[] = (upcomingRes.data as any[]) ?? [];
  const recent: any[] = (recentRes.data as any[]) ?? [];
  const perHosp: any[] = (perHospRes.data as any[]) ?? [];
  const redline: any[] = (redlineRes.data as any[]) ?? [];
  const outcomes: any[] = (outcomesRes.data as any[]) ?? [];
  const followups: any[] = (followupsRes.data as any[]) ?? [];

  const upcomingCols: Column<any>[] = [
    { key: 'scheduled_at',  header: 'Scheduled',  render: (r: any) => fmtDate(r.scheduled_at) },
    { key: 'hospital_name', header: 'Hospital',   render: (r: any) => r.hospital_name ?? "-" },
    { key: 'visitor_email', header: 'Visitor',    render: (r: any) => r.visitor_email ?? "-" },
    { key: 'visitor_role',  header: 'Role',       render: (r: any) => r.visitor_role ?? "-" },
    { key: 'purpose',       header: 'Purpose',    render: (r: any) => r.purpose ?? "-" },
    { key: 'days_until',    header: 'Days until', render: (r: any) => r.days_until ?? "-" },
  ];

  const recentCols: Column<any>[] = [
    { key: 'visited_at',      header: 'Visited',   render: (r: any) => fmtDate(r.visited_at) },
    { key: 'hospital_name',   header: 'Hospital',  render: (r: any) => r.hospital_name ?? "-" },
    { key: 'visitor_email',   header: 'Visitor',   render: (r: any) => r.visitor_email ?? "-" },
    { key: 'visitor_role',    header: 'Role',      render: (r: any) => r.visitor_role ?? "-" },
    { key: 'purpose',         header: 'Purpose',   render: (r: any) => r.purpose ?? "-" },
    { key: 'outcome_kind',    header: 'Outcome',   render: (r: any) => r.outcome_kind ?? "-" },
    { key: 'arr_impact_rupees', header: 'ARR impact (Rs)', render: (r: any) => fmtINR(r.arr_impact_rupees) },
  ];

  const perHospCols: Column<any>[] = [
    { key: 'hospital_name',     header: 'Hospital',      render: (r: any) => r.hospital_name ?? "-" },
    { key: 'total_visits',      header: 'Total visits',  render: (r: any) => r.total_visits ?? 0 },
    { key: 'last_visited_at',   header: 'Last visited',  render: (r: any) => fmtDate(r.last_visited_at) },
    { key: 'days_since_last',   header: 'Days since',    render: (r: any) => r.days_since_last ?? "never" },
    { key: 'next_scheduled_at', header: 'Next scheduled', render: (r: any) => fmtDate(r.next_scheduled_at) },
    { key: 'redline',           header: 'Redline 90d',   render: (r: any) => r.redline ? 'YES' : 'no' },
  ];

  const redlineCols: Column<any>[] = [
    { key: 'hospital_name',   header: 'Hospital',       render: (r: any) => r.hospital_name ?? "-" },
    { key: 'last_visited_at', header: 'Last visited',   render: (r: any) => fmtDate(r.last_visited_at) },
    { key: 'days_since_last', header: 'Days since',     render: (r: any) => r.days_since_last ?? "never" },
    { key: 'has_active_amc',  header: 'Active AMC',     render: (r: any) => r.has_active_amc ? 'yes' : 'no' },
  ];

  const outcomesCols: Column<any>[] = [
    { key: 'outcome_kind',     header: 'Outcome kind',    render: (r: any) => r.outcome_kind ?? "-" },
    { key: 'n',                header: 'Count',           render: (r: any) => r.n ?? 0 },
    { key: 'arr_total_rupees', header: 'ARR total (Rs)',  render: (r: any) => fmtINR(r.arr_total_rupees) },
    { key: 'last_recorded_at', header: 'Last recorded',   render: (r: any) => fmtDate(r.last_recorded_at) },
  ];

  const followupCols: Column<any>[] = [
    { key: 'hospital_name',   header: 'Hospital',         render: (r: any) => r.hospital_name ?? "-" },
    { key: 'outcome_kind',    header: 'Outcome',          render: (r: any) => r.outcome_kind ?? "-" },
    { key: 'followup_due_at', header: 'Follow-up due',    render: (r: any) => fmtDate(r.followup_due_at) },
    { key: 'days_overdue',    header: 'Days overdue',     render: (r: any) => r.days_overdue ?? 0 },
    { key: 'notes',           header: 'Notes',            render: (r: any) => r.notes ?? "-" },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-6 px-4 py-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold text-neutral-900">Hospital site-visit calendar</h1>
        <p className="text-sm text-neutral-600">
          Founder, CTO and sales in-person visits to hospital orgs. Visit-purpose taxonomy plus outcome ledger.
          Per-hospital last-visited surface with cadence redline at over 90 days.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 sm:grid-cols-4">
        <Kpi label="Total visits"               value={k.total_visits ?? 0} />
        <Kpi label="Visits last 30d"            value={k.visits_30d ?? 0} />
        <Kpi label="Visits last 90d"            value={k.visits_90d ?? 0} />
        <Kpi label="Completed last 30d"         value={k.visits_completed_30d ?? 0} />
        <Kpi label="Upcoming scheduled"         value={k.visits_scheduled_upcoming ?? 0} />
        <Kpi label="No-shows last 90d"          value={k.visits_no_show_90d ?? 0} />
        <Kpi label="Cancelled last 90d"         value={k.visits_cancelled_90d ?? 0} />
        <Kpi label="Hospitals visited 90d"      value={k.hospitals_visited_90d ?? 0} />
        <Kpi label="Hospitals never visited"    value={k.hospitals_never_visited ?? 0} />
        <Kpi label="Redline (over 90d)"         value={k.hospitals_redline_90d ?? 0} />
        <Kpi label="Outcomes recorded 90d"      value={k.outcomes_recorded_90d ?? 0} />
        <Kpi label="ARR won 90d (Rs)"           value={fmtINR(k.arr_won_90d_rupees)} />
        <Kpi label="ARR lost 90d (Rs)"          value={fmtINR(k.arr_lost_90d_rupees)} />
        <Kpi label="Follow-ups overdue"         value={k.followups_overdue ?? 0} />
        <Kpi label="Avg days between visits"    value={k.avg_days_between_visits ?? 0} />
        <Kpi label="Distinct visitors 90d"      value={k.distinct_visitors_90d ?? 0} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Upcoming visits</h2>
        <DataTable<any>
          rows={upcoming}
          columns={upcomingCols}
          rowKey={(r: any) => r.id}
          emptyMessage="No upcoming visits scheduled."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Recent completed visits</h2>
        <DataTable<any>
          rows={recent}
          columns={recentCols}
          rowKey={(r: any) => r.id}
          emptyMessage="No completed visits yet."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Per-hospital last-visited surface</h2>
        <DataTable<any>
          rows={perHosp}
          columns={perHospCols}
          rowKey={(r: any) => r.hospital_org_id}
          emptyMessage="No hospital orgs found."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Cadence redline (over 90 days)</h2>
        <DataTable<any>
          rows={redline}
          columns={redlineCols}
          rowKey={(r: any) => r.hospital_org_id}
          emptyMessage="No hospitals past 90-day cadence."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Outcomes by kind</h2>
        <DataTable<any>
          rows={outcomes}
          columns={outcomesCols}
          rowKey={(r: any) => r.outcome_kind}
          emptyMessage="No outcomes recorded yet."
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold text-neutral-900">Follow-ups overdue</h2>
        <DataTable<any>
          rows={followups}
          columns={followupCols}
          rowKey={(r: any) => r.visit_id}
          emptyMessage="No overdue follow-ups."
        />
      </section>
    </main>
  );
}
