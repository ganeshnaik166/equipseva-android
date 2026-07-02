import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [rightsRes, packetsRes, dueRes, recentRes] = await Promise.all([
    sb.rpc('list_investor_info_rights_r1917'),
    sb.rpc('list_investor_info_packets_r1917'),
    sb.rpc('due_soon_investor_info_rights_r1917'),
    sb.rpc('recent_investor_info_packets_r1917'),
  ]);

  const rights: any[] = Array.isArray(rightsRes.data) ? rightsRes.data : [];
  const packets: any[] = Array.isArray(packetsRes.data) ? packetsRes.data : [];
  const due: any[] = Array.isArray(dueRes.data) ? dueRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalRights = rights.length;
  const activeRights = rights.filter((r) => r.status === 'active').length;
  const pausedRights = rights.filter((r) => r.status === 'paused').length;
  const expiredRights = rights.filter((r) => r.status === 'expired').length;
  const dueSoonCount = due.length;
  const totalPackets = packets.length;
  const recentPacketCount = recent.length;

  const rightCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_id ?? '').slice(0, 8)}</span> },
    { key: 'right_type', header: 'Right', render: (r: any) => <span>{String(r.right_type ?? '')}</span> },
    { key: 'frequency', header: 'Frequency', render: (r: any) => <span>{String(r.frequency ?? '')}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className={r.status === 'active' ? 'text-green-700' : r.status === 'paused' ? 'text-amber-700' : 'text-gray-500'}>{String(r.status ?? '')}</span> },
    { key: 'started_at', header: 'Started', render: (r: any) => <span className="text-xs">{r.started_at ? new Date(r.started_at).toLocaleDateString() : '-'}</span> },
    { key: 'expires_at', header: 'Expires', render: (r: any) => <span className="text-xs">{r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '-'}</span> },
    { key: 'notes', header: 'Notes', render: (r: any) => <span className="text-xs text-gray-600">{String(r.notes ?? '')}</span> },
  ];

  const dueCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_id ?? '').slice(0, 8)}</span> },
    { key: 'right_type', header: 'Right', render: (r: any) => <span>{String(r.right_type ?? '')}</span> },
    { key: 'frequency', header: 'Frequency', render: (r: any) => <span>{String(r.frequency ?? '')}</span> },
    { key: 'expires_at', header: 'Expires', render: (r: any) => <span className="text-xs">{r.expires_at ? new Date(r.expires_at).toLocaleDateString() : '-'}</span> },
    { key: 'days_until', header: 'Days until', render: (r: any) => <span className={Number(r.days_until ?? 0) <= 7 ? 'text-red-700 font-semibold' : 'text-amber-700'}>{String(r.days_until ?? 0)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{String(r.status ?? '')}</span> },
  ];

  const packetCols: Column<any>[] = [
    { key: 'sent_at', header: 'Sent at', render: (r: any) => <span className="text-xs">{r.sent_at ? new Date(r.sent_at).toLocaleString() : '-'}</span> },
    { key: 'investor_id', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_id ?? '').slice(0, 8)}</span> },
    { key: 'right_type', header: 'Right', render: (r: any) => <span>{String(r.right_type ?? '')}</span> },
    { key: 'packet_type', header: 'Packet type', render: (r: any) => <span>{String(r.packet_type ?? '')}</span> },
    { key: 'by_email', header: 'By email', render: (r: any) => <span className="text-xs">{String(r.by_email ?? '')}</span> },
    { key: 'packet_url', header: 'URL', render: (r: any) => r.packet_url ? <a className="text-blue-700 underline text-xs" href={String(r.packet_url)} target="_blank" rel="noreferrer">link</a> : <span className="text-gray-400">-</span> },
  ];

  const recentCols: Column<any>[] = [
    { key: 'sent_at', header: 'Sent at', render: (r: any) => <span className="text-xs">{r.sent_at ? new Date(r.sent_at).toLocaleString() : '-'}</span> },
    { key: 'investor_id', header: 'Investor', render: (r: any) => <span className="font-mono text-xs">{String(r.investor_id ?? '').slice(0, 8)}</span> },
    { key: 'right_type', header: 'Right', render: (r: any) => <span>{String(r.right_type ?? '')}</span> },
    { key: 'packet_type', header: 'Packet type', render: (r: any) => <span>{String(r.packet_type ?? '')}</span> },
    { key: 'by_email', header: 'By email', render: (r: any) => <span className="text-xs">{String(r.by_email ?? '')}</span> },
  ];

  return (
    <main className="p-6 space-y-8 max-w-7xl mx-auto">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Investor Information Rights Log</h1>
        <p className="text-sm text-gray-600">Track info rights per investor and when packets were sent.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total rights</div>
          <div className="text-xl font-semibold">{totalRights}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Active</div>
          <div className="text-xl font-semibold text-green-700">{activeRights}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Paused</div>
          <div className="text-xl font-semibold text-amber-700">{pausedRights}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Expired</div>
          <div className="text-xl font-semibold text-gray-500">{expiredRights}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Due within 30 days</div>
          <div className="text-xl font-semibold text-red-700">{dueSoonCount}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total packets sent</div>
          <div className="text-xl font-semibold">{totalPackets}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Packets last 14 days</div>
          <div className="text-xl font-semibold">{recentPacketCount}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Round</div>
          <div className="text-xl font-semibold">r1917</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Information rights</h2>
        <p className="text-xs text-gray-500">All known investor information rights, newest first.</p>
        <DataTable
          rows={rights}
          columns={rightCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Due soon (within 30 days)</h2>
        <p className="text-xs text-gray-500">Active rights with expiry less than 30 days away.</p>
        <DataTable
          rows={due}
          columns={dueCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent packets (last 14 days)</h2>
        <p className="text-xs text-gray-500">Packets sent in the last two weeks.</p>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All packet log</h2>
        <p className="text-xs text-gray-500">Full history of info packets sent to investors.</p>
        <DataTable
          rows={packets}
          columns={packetCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
