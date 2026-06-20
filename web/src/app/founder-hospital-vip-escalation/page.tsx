import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: number | null | undefined, digits = 0): string {
  if (n === null || n === undefined) return '—';
  return Number(n).toLocaleString('en-IN', { minimumFractionDigits: digits, maximumFractionDigits: digits });
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [overviewRes, listRes, byHospitalRes, slaRes, byCategoryRes, eventsRes, routingRes] = await Promise.all([
    sb.rpc('founder_vip_escalation_overview'),
    sb.rpc('founder_vip_escalation_list', { p_limit: 100 }),
    sb.rpc('founder_vip_escalation_by_hospital'),
    sb.rpc('founder_vip_escalation_sla_breaches'),
    sb.rpc('founder_vip_escalation_by_category'),
    sb.rpc('founder_vip_escalation_recent_events', { p_limit: 50 }),
    sb.rpc('founder_vip_escalation_routing_perf'),
  ]);

  const o: any = (overviewRes.data && overviewRes.data[0]) || {};
  const list: any[] = listRes.data || [];
  const byHospital: any[] = byHospitalRes.data || [];
  const sla: any[] = slaRes.data || [];
  const byCategory: any[] = byCategoryRes.data || [];
  const events: any[] = eventsRes.data || [];
  const routing: any[] = routingRes.data || [];

  const kpis: Kpi[] = [
    { label: 'Total Escalations', value: fmtNum(o.total_escalations) },
    { label: 'Open', value: fmtNum(o.open_escalations) },
    { label: 'Resolved', value: fmtNum(o.resolved_escalations) },
    { label: 'P0 Open', value: fmtNum(o.p0_open) },
    { label: 'P1 Open', value: fmtNum(o.p1_open) },
    { label: 'Avg Response (min)', value: fmtNum(o.avg_response_minutes, 1) },
    { label: 'Avg Resolution (hrs)', value: fmtNum(o.avg_resolution_hours, 2) },
    { label: 'SLA Response Breaches', value: fmtNum(o.sla_response_breaches) },
    { label: 'SLA Resolution Breaches', value: fmtNum(o.sla_resolution_breaches) },
    { label: 'Avg Satisfaction', value: fmtNum(o.avg_satisfaction, 2) },
    { label: 'Satisfaction Responses', value: fmtNum(o.satisfaction_responses) },
    { label: 'Routed Founder', value: fmtNum(o.routed_founder) },
    { label: 'Routed CTO', value: fmtNum(o.routed_cto) },
    { label: 'Tier A+', value: fmtNum(o.tier_a_plus_count) },
    { label: 'Strategic', value: fmtNum(o.strategic_count) },
    { label: 'Last 7d', value: fmtNum(o.last_7d_count) },
  ];

  const listCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'vip_tier', header: 'Tier', render: (r: any) => r.vip_tier ?? '—' },
    { key: 'routed_to', header: 'Routed', render: (r: any) => r.routed_to ?? '—' },
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'severity', header: 'Sev', render: (r: any) => r.severity ?? '—' },
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'response_minutes', header: 'Resp (m)', render: (r: any) => fmtNum(r.response_minutes, 1) },
    { key: 'resolution_hours', header: 'Resol (h)', render: (r: any) => fmtNum(r.resolution_hours, 2) },
    { key: 'satisfaction_score', header: 'CSAT', render: (r: any) => r.satisfaction_score ?? '—' },
  ];

  const byHospitalCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'total_escalations', header: 'Total', render: (r: any) => fmtNum(r.total_escalations) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtNum(r.open_count) },
    { key: 'resolved_count', header: 'Resolved', render: (r: any) => fmtNum(r.resolved_count) },
    { key: 'avg_response_minutes', header: 'Avg Resp (m)', render: (r: any) => fmtNum(r.avg_response_minutes, 1) },
    { key: 'avg_resolution_hours', header: 'Avg Resol (h)', render: (r: any) => fmtNum(r.avg_resolution_hours, 2) },
    { key: 'avg_satisfaction', header: 'Avg CSAT', render: (r: any) => fmtNum(r.avg_satisfaction, 2) },
    { key: 'last_escalation_at', header: 'Last', render: (r: any) => r.last_escalation_at ? new Date(r.last_escalation_at).toLocaleString('en-IN') : '—' },
  ];

  const slaCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'title', header: 'Title', render: (r: any) => r.title ?? '—' },
    { key: 'severity', header: 'Sev', render: (r: any) => r.severity ?? '—' },
    { key: 'breach_type', header: 'Breach', render: (r: any) => r.breach_type ?? '—' },
    { key: 'minutes_over', header: 'Min Over', render: (r: any) => fmtNum(r.minutes_over, 1) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'opened_at', header: 'Opened', render: (r: any) => r.opened_at ? new Date(r.opened_at).toLocaleString('en-IN') : '—' },
  ];

  const categoryCols: Column<any>[] = [
    { key: 'category', header: 'Category', render: (r: any) => r.category ?? '—' },
    { key: 'total', header: 'Total', render: (r: any) => fmtNum(r.total) },
    { key: 'open_count', header: 'Open', render: (r: any) => fmtNum(r.open_count) },
    { key: 'avg_response_minutes', header: 'Avg Resp (m)', render: (r: any) => fmtNum(r.avg_response_minutes, 1) },
    { key: 'avg_resolution_hours', header: 'Avg Resol (h)', render: (r: any) => fmtNum(r.avg_resolution_hours, 2) },
    { key: 'avg_satisfaction', header: 'Avg CSAT', render: (r: any) => fmtNum(r.avg_satisfaction, 2) },
  ];

  const eventCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => r.created_at ? new Date(r.created_at).toLocaleString('en-IN') : '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'title', header: 'Escalation', render: (r: any) => r.title ?? '—' },
    { key: 'event_type', header: 'Event', render: (r: any) => r.event_type ?? '—' },
    { key: 'note', header: 'Note', render: (r: any) => r.note ?? '—' },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold tracking-tight">Hospital VIP Escalation Routing</h1>
        <p className="text-sm text-gray-600 mt-1">Tier-A hospitals routed to founder/CTO. SLA, response, resolution, satisfaction.</p>
      </header>

      <section>
        <div className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-4 gap-3">
          {kpis.map((k) => (
            <div key={k.label} className="rounded-lg border border-gray-200 bg-white p-4">
              <div className="text-xs uppercase tracking-wide text-gray-500">{k.label}</div>
              <div className="mt-1 text-xl font-semibold text-gray-900">{k.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">SLA breaches (active)</h2>
        <DataTable columns={slaCols} rows={sla} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent escalations</h2>
        <DataTable columns={listCols} rows={list} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">By hospital</h2>
        <DataTable columns={byHospitalCols} rows={byHospital} rowKey={(r: any) => r.hospital_org_id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">By category</h2>
        <DataTable columns={categoryCols} rows={byCategory} rowKey={(r: any) => r.category} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Routing performance</h2>
        <DataTable
          columns={[
            { key: 'routed_to', header: 'Routed', render: (r: any) => r.routed_to ?? '—' },
            { key: 'total', header: 'Total', render: (r: any) => fmtNum(r.total) },
            { key: 'resolved', header: 'Resolved', render: (r: any) => fmtNum(r.resolved) },
            { key: 'avg_response_minutes', header: 'Avg Resp (m)', render: (r: any) => fmtNum(r.avg_response_minutes, 1) },
            { key: 'avg_resolution_hours', header: 'Avg Resol (h)', render: (r: any) => fmtNum(r.avg_resolution_hours, 2) },
            { key: 'avg_satisfaction', header: 'Avg CSAT', render: (r: any) => fmtNum(r.avg_satisfaction, 2) },
            { key: 'sla_response_breaches', header: 'SLA Breaches', render: (r: any) => fmtNum(r.sla_response_breaches) },
          ]}
          rows={routing}
          rowKey={(r: any) => r.routed_to}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent events</h2>
        <DataTable columns={eventCols} rows={events} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
