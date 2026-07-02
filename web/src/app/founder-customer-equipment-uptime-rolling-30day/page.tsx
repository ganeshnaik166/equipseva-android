import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderCustomerEquipmentUptimeRolling30DayPage() {
  const supabase = await getSupabaseServerClient();

  const [
    uptimeRes,
    actionsRes,
    criticalRes,
    severityRes,
    trendRes,
    actionKindRes,
    hospitalSummaryRes,
  ] = await Promise.all([
    supabase.rpc('list_uptime_r2612'),
    supabase.rpc('list_breach_actions_r2612'),
    supabase.rpc('top_critical_focus_r2612'),
    supabase.rpc('severity_distribution_r2612'),
    supabase.rpc('monthly_uptime_trend_r2612'),
    supabase.rpc('action_kind_breakdown_r2612'),
    supabase.rpc('hospital_uptime_summary_r2612'),
  ]);

  const uptime = (uptimeRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const critical = (criticalRes.data ?? []) as any[];
  const severity = (severityRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const actionKind = (actionKindRes.data ?? []) as any[];
  const hospitalSummary = (hospitalSummaryRes.data ?? []) as any[];

  const fmtDate = (v: any) => (v ? new Date(v).toLocaleDateString('en-IN') : '-');
  const fmtDateTime = (v: any) => (v ? new Date(v).toLocaleString('en-IN') : '-');
  const fmtPct = (v: any) => (v == null ? '-' : `${Number(v).toFixed(2)}%`);

  const uptimeColumns: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'window_end_date', header: 'Window End', render: (r: any) => fmtDate(r.window_end_date) },
    { key: 'uptime_pct', header: 'Uptime', render: (r: any) => fmtPct(r.uptime_pct) },
    { key: 'downtime_minutes', header: 'Downtime (min)', render: (r: any) => String(r.downtime_minutes) },
    { key: 'slo_breach_count', header: 'Breaches', render: (r: any) => String(r.slo_breach_count) },
    { key: 'severity_kind', header: 'Severity', render: (r: any) => r.severity_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionsColumns: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'action_at', header: 'When', render: (r: any) => fmtDateTime(r.action_at) },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const criticalColumns: Column<any>[] = [
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'uptime_pct', header: 'Uptime', render: (r: any) => fmtPct(r.uptime_pct) },
    { key: 'downtime_minutes', header: 'Downtime (min)', render: (r: any) => String(r.downtime_minutes) },
    { key: 'severity_kind', header: 'Severity', render: (r: any) => r.severity_kind },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const severityColumns: Column<any>[] = [
    { key: 'severity_kind', header: 'Severity', render: (r: any) => r.severity_kind },
    { key: 'total_assets', header: 'Assets', render: (r: any) => String(r.total_assets) },
    { key: 'avg_uptime_pct', header: 'Avg Uptime', render: (r: any) => fmtPct(r.avg_uptime_pct) },
    { key: 'total_downtime_minutes', header: 'Total Downtime (min)', render: (r: any) => String(r.total_downtime_minutes) },
    { key: 'total_breaches', header: 'Total Breaches', render: (r: any) => String(r.total_breaches) },
  ];

  const trendColumns: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'assets_tracked', header: 'Assets', render: (r: any) => String(r.assets_tracked) },
    { key: 'avg_uptime_pct', header: 'Avg Uptime', render: (r: any) => fmtPct(r.avg_uptime_pct) },
    { key: 'total_downtime_minutes', header: 'Downtime (min)', render: (r: any) => String(r.total_downtime_minutes) },
    { key: 'total_breaches', header: 'Breaches', render: (r: any) => String(r.total_breaches) },
  ];

  const actionKindColumns: Column<any>[] = [
    { key: 'action_kind', header: 'Action Kind', render: (r: any) => r.action_kind },
    { key: 'total_actions', header: 'Total', render: (r: any) => String(r.total_actions) },
    { key: 'done_actions', header: 'Done', render: (r: any) => String(r.done_actions) },
    { key: 'positive_outcomes', header: 'Positive', render: (r: any) => String(r.positive_outcomes) },
    { key: 'open_actions', header: 'Open', render: (r: any) => String(r.open_actions) },
  ];

  const hospitalSummaryColumns: Column<any>[] = [
    { key: 'equipment_kind', header: 'Equipment Kind', render: (r: any) => r.equipment_kind },
    { key: 'total_assets', header: 'Assets', render: (r: any) => String(r.total_assets) },
    { key: 'avg_uptime_pct', header: 'Avg Uptime', render: (r: any) => fmtPct(r.avg_uptime_pct) },
    { key: 'critical_assets', header: 'Critical', render: (r: any) => String(r.critical_assets) },
    { key: 'red_assets', header: 'Red', render: (r: any) => String(r.red_assets) },
    { key: 'amber_assets', header: 'Amber', render: (r: any) => String(r.amber_assets) },
    { key: 'green_assets', header: 'Green', render: (r: any) => String(r.green_assets) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Customer Equipment Uptime — Rolling 30-day
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Rolling 30-day uptime per hospital equipment with SLO breach counts, severity
        ladder (green > amber > red > critical), and breach-action calendar.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Severity distribution
        </h2>
        <DataTable
          rows={severity}
          columns={severityColumns}
          emptyMessage="No severity rows yet."
          rowKey={(r: any, i: number) => String(r.severity_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Top critical focus — red & critical
        </h2>
        <DataTable
          rows={critical}
          columns={criticalColumns}
          emptyMessage="No critical assets. Nice."
          rowKey={(r: any, i: number) => String(r.equipment_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Hospital summary by equipment kind
        </h2>
        <DataTable
          rows={hospitalSummary}
          columns={hospitalSummaryColumns}
          emptyMessage="No hospital summary yet."
          rowKey={(r: any, i: number) => String(r.equipment_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Monthly uptime trend
        </h2>
        <DataTable
          rows={trend}
          columns={trendColumns}
          emptyMessage="No trend data yet."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Action kind breakdown
        </h2>
        <DataTable
          rows={actionKind}
          columns={actionKindColumns}
          emptyMessage="No action kinds yet."
          rowKey={(r: any, i: number) => String(r.action_kind ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          All uptime rows
        </h2>
        <DataTable
          rows={uptime}
          columns={uptimeColumns}
          emptyMessage="No uptime rows logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Breach action calendar
        </h2>
        <DataTable
          rows={actions}
          columns={actionsColumns}
          emptyMessage="No breach actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
