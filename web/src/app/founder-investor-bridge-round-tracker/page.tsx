import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined) {
  if (!s) return '—';
  try { return new Date(s).toLocaleDateString('en-IN'); } catch { return String(s); }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [bridgesRes, totalsRes, recentRes] = await Promise.all([
    sb.rpc('list_bridges_r1853'),
    sb.rpc('total_bridge_volume_r1853'),
    sb.rpc('recent_closes_r1853'),
  ]);

  const bridges: any[] = Array.isArray(bridgesRes.data) ? bridgesRes.data : [];
  const totalsRow: any = Array.isArray(totalsRes.data) && totalsRes.data.length > 0 ? totalsRes.data[0] : {};
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const bridgeCols: Column<any>[] = [
    { key: 'bridge_label', header: 'Bridge', render: (r: any) => <span className="font-medium">{r.bridge_label}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-sm uppercase">{r.status}</span> },
    { key: 'target', header: 'Target', render: (r: any) => <span>{rupees(r.target_amount_rupees)}</span> },
    { key: 'raised', header: 'Raised', render: (r: any) => <span>{rupees(r.raised_amount_rupees)}</span> },
    { key: 'pct', header: 'Pct', render: (r: any) => {
      const t = Number(r.target_amount_rupees ?? 0);
      const ra = Number(r.raised_amount_rupees ?? 0);
      const pct = t > 0 ? Math.round((ra / t) * 100) : 0;
      return <span>{pct}%</span>;
    } },
    { key: 'cap', header: 'Val Cap', render: (r: any) => <span>{r.valuation_cap_rupees ? rupees(r.valuation_cap_rupees) : '—'}</span> },
    { key: 'discount', header: 'Discount', render: (r: any) => <span>{r.discount_pct ? `${r.discount_pct}%` : '—'}</span> },
    { key: 'started', header: 'Started', render: (r: any) => <span>{fmtDate(r.started_at)}</span> },
    { key: 'close', header: 'Expected Close', render: (r: any) => <span>{fmtDate(r.expected_close)}</span> },
    { key: 'parts', header: 'Participants', render: (r: any) => <span>{Number(r.participant_count ?? 0)}</span> },
  ];

  const recentCols: Column<any>[] = [
    { key: 'bridge_label', header: 'Bridge', render: (r: any) => <span className="font-medium">{r.bridge_label}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="text-sm uppercase">{r.status}</span> },
    { key: 'raised', header: 'Raised', render: (r: any) => <span>{rupees(r.raised_amount_rupees)}</span> },
    { key: 'target', header: 'Target', render: (r: any) => <span>{rupees(r.target_amount_rupees)}</span> },
    { key: 'updated', header: 'Updated', render: (r: any) => <span>{fmtDate(r.updated_at)}</span> },
  ];

  return (
    <div className="p-6 space-y-8 max-w-7xl mx-auto">
      <header>
        <h1 className="text-2xl font-bold">Investor Bridge Round Tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track bridge financing rounds between priced rounds — commitments, funded amounts & status.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Total Target</div>
          <div className="text-xl font-semibold mt-1">{rupees(totalsRow?.total_target_rupees)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Total Raised</div>
          <div className="text-xl font-semibold mt-1">{rupees(totalsRow?.total_raised_rupees)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Open</div>
          <div className="text-xl font-semibold mt-1">{Number(totalsRow?.open_count ?? 0)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">In Progress</div>
          <div className="text-xl font-semibold mt-1">{Number(totalsRow?.in_progress_count ?? 0)}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Closed</div>
          <div className="text-xl font-semibold mt-1">{Number(totalsRow?.closed_count ?? 0)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">All Bridge Rounds</h2>
        <DataTable
          rows={bridges}
          columns={bridgeCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Closes & Extensions</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
