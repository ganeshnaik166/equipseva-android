import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string | number };

async function safeRpc(sb: any, name: string, args: any = {}) {
  try {
    const { data, error } = await sb.rpc(name, args);
    if (error) return [];
    return data ?? [];
  } catch {
    return [];
  }
}

export default async function FounderEngineerCertCalendarPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const kpiRows = await safeRpc(sb, 'founder_cert_calendar_kpis');
  const lapses = await safeRpc(sb, 'founder_cert_upcoming_lapses');
  const perEng = await safeRpc(sb, 'founder_cert_per_engineer_summary');
  const queue = await safeRpc(sb, 'founder_cert_reminder_queue');
  const authBreak = await safeRpc(sb, 'founder_cert_authority_breakdown');

  const k = (Array.isArray(kpiRows) && kpiRows[0]) || {};

  const kpis: Kpi[] = [
    { label: 'Total certs', value: k.total_certs ?? '—' },
    { label: 'Active', value: k.active_certs ?? '—' },
    { label: 'Expired', value: k.expired_certs ?? '—' },
    { label: 'Revoked', value: k.revoked_certs ?? '—' },
    { label: 'Expiring 30d', value: k.expiring_30d ?? '—' },
    { label: 'Expiring 60d', value: k.expiring_60d ?? '—' },
    { label: 'Expiring 90d', value: k.expiring_90d ?? '—' },
    { label: 'Lapsed unrenewed', value: k.lapsed_unrenewed ?? '—' },
    { label: 'Unique engineers', value: k.unique_engineers ?? '—' },
    { label: 'Unique authorities', value: k.unique_authorities ?? '—' },
    { label: 'Reminders queued', value: k.reminders_queued ?? '—' },
    { label: 'Reminders sent 30d', value: k.reminders_sent_30d ?? '—' },
    { label: 'Reminders failed 30d', value: k.reminders_failed_30d ?? '—' },
    { label: 'Avg days to expiry', value: k.avg_days_to_expiry ?? '—' },
    { label: 'Pct active', value: k.pct_active != null ? `${k.pct_active}%` : '—' },
    { label: 'Next expiry (days)', value: k.next_expiry_in_days ?? '—' },
  ];

  const lapseCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'cert_name', header: 'Cert', render: (r: any) => r.cert_name ?? '—' },
    { key: 'cert_authority', header: 'Authority', render: (r: any) => r.cert_authority ?? '—' },
    { key: 'expires_on', header: 'Expires', render: (r: any) => r.expires_on ?? '—' },
    { key: 'days_remaining', header: 'Days left', render: (r: any) => r.days_remaining ?? '—' },
    { key: 'window_bucket', header: 'Window', render: (r: any) => r.window_bucket ?? '—' },
  ];

  const engCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'cached_tier', header: 'Tier', render: (r: any) => r.cached_tier ?? '—' },
    { key: 'total_certs', header: 'Total', render: (r: any) => r.total_certs ?? '—' },
    { key: 'active_certs', header: 'Active', render: (r: any) => r.active_certs ?? '—' },
    { key: 'expiring_90d', header: 'Expiring 90d', render: (r: any) => r.expiring_90d ?? '—' },
    { key: 'expired_certs', header: 'Expired', render: (r: any) => r.expired_certs ?? '—' },
    { key: 'next_expiry', header: 'Next expiry', render: (r: any) => r.next_expiry ?? '—' },
  ];

  const queueCols: Column<any>[] = [
    { key: 'engineer_name', header: 'Engineer', render: (r: any) => r.engineer_name ?? '—' },
    { key: 'cert_name', header: 'Cert', render: (r: any) => r.cert_name ?? '—' },
    { key: 'reminder_window', header: 'Window', render: (r: any) => `${r.reminder_window ?? '—'}d` },
    { key: 'scheduled_for', header: 'Scheduled', render: (r: any) => r.scheduled_for ?? '—' },
    { key: 'dispatch_status', header: 'Status', render: (r: any) => r.dispatch_status ?? '—' },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
    { key: 'dispatched_at', header: 'Dispatched', render: (r: any) => r.dispatched_at ?? '—' },
  ];

  const authCols: Column<any>[] = [
    { key: 'cert_authority', header: 'Authority', render: (r: any) => r.cert_authority ?? '—' },
    { key: 'total_certs', header: 'Total', render: (r: any) => r.total_certs ?? '—' },
    { key: 'active_certs', header: 'Active', render: (r: any) => r.active_certs ?? '—' },
    { key: 'expiring_90d', header: 'Expiring 90d', render: (r: any) => r.expiring_90d ?? '—' },
    { key: 'expired_certs', header: 'Expired', render: (r: any) => r.expired_certs ?? '—' },
    { key: 'pct_active', header: 'Pct active', render: (r: any) => (r.pct_active != null ? `${r.pct_active}%` : '—') },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Engineer Certification Calendar</h1>
        <p className="text-sm text-gray-500">Per-engineer certifications, expiry schedule, and 30/60/90-day reminder pipeline.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        {kpis.map((kp) => (
          <div key={kp.label} className="rounded-lg border p-3">
            <div className="text-xs text-gray-500">{kp.label}</div>
            <div className="text-lg font-semibold">{kp.value}</div>
          </div>
        ))}
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming lapses (next 90 days)</h2>
        <DataTable
          rows={lapses as any[]}
          columns={lapseCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Per-engineer summary</h2>
        <DataTable
          rows={perEng as any[]}
          columns={engCols}
          rowKey={(r: any) => r.engineer_id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Reminder queue</h2>
        <DataTable
          rows={queue as any[]}
          columns={queueCols}
          rowKey={(r: any) => r.id}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Authority breakdown</h2>
        <DataTable
          rows={authBreak as any[]}
          columns={authCols}
          rowKey={(r: any) => r.cert_authority}
        />
      </section>
    </div>
  );
}
