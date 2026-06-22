import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [rightsRes, decisionsRes, expiringRes, recentRes] = await Promise.all([
    sb.rpc('list_pro_rata_rights_v2_r1901'),
    sb.rpc('list_pro_rata_decisions_v2_r1901'),
    sb.rpc('expiring_pro_rata_rights_v2_r1901'),
    sb.rpc('recent_pro_rata_decisions_v2_r1901'),
  ]);

  const rights = (rightsRes.data ?? []) as any[];
  const decisions = (decisionsRes.data ?? []) as any[];
  const expiring = (expiringRes.data ?? []) as any[];
  const recent = (recentRes.data ?? []) as any[];

  const rightsCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '—'}</span> },
    { key: 'round_label', header: 'Round', render: (r: any) => <span>{r.round_label}</span> },
    { key: 'max_pro_rata_pct', header: 'Max %', render: (r: any) => <span>{Number(r.max_pro_rata_pct ?? 0).toFixed(2)}%</span> },
    { key: 'pro_rata_share_count', header: 'Shares', render: (r: any) => <span>{r.pro_rata_share_count ?? 0}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="font-mono text-xs">{r.status}</span> },
    { key: 'expiry_date', header: 'Expiry', render: (r: any) => <span>{r.expiry_date ?? '—'}</span> },
    { key: 'decided_at', header: 'Decided', render: (r: any) => <span>{r.decided_at ? new Date(r.decided_at).toLocaleDateString() : '—'}</span> },
  ];

  const decisionCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '—'}</span> },
    { key: 'round_label', header: 'Round', render: (r: any) => <span>{r.round_label ?? '—'}</span> },
    { key: 'decision', header: 'Decision', render: (r: any) => <span className="font-mono text-xs">{r.decision}</span> },
    { key: 'decision_at', header: 'When', render: (r: any) => <span>{new Date(r.decision_at).toLocaleString()}</span> },
    { key: 'decision_note', header: 'Note', render: (r: any) => <span className="text-xs">{r.decision_note ?? '—'}</span> },
    { key: 'founder_action_taken', header: 'Founder Action', render: (r: any) => <span className="text-xs">{r.founder_action_taken ?? '—'}</span> },
  ];

  const expiringCols: Column<any>[] = [
    { key: 'investor_email', header: 'Investor', render: (r: any) => <span>{r.investor_email ?? '—'}</span> },
    { key: 'round_label', header: 'Round', render: (r: any) => <span>{r.round_label}</span> },
    { key: 'max_pro_rata_pct', header: 'Max %', render: (r: any) => <span>{Number(r.max_pro_rata_pct ?? 0).toFixed(2)}%</span> },
    { key: 'expiry_date', header: 'Expiry', render: (r: any) => <span>{r.expiry_date}</span> },
    { key: 'days_left', header: 'Days Left', render: (r: any) => <span className={Number(r.days_left) <= 7 ? 'text-red-600 font-semibold' : ''}>{r.days_left}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="font-mono text-xs">{r.status}</span> },
  ];

  const recentCols: Column<any>[] = [
    { key: 'decision', header: 'Decision', render: (r: any) => <span className="font-mono text-xs">{r.decision}</span> },
    { key: 'decision_count', header: 'Count (30d)', render: (r: any) => <span>{r.decision_count}</span> },
    { key: 'last_decision_at', header: 'Last At', render: (r: any) => <span>{r.last_decision_at ? new Date(r.last_decision_at).toLocaleString() : '—'}</span> },
  ];

  const activeCount = rights.filter((r) => r.status === 'active').length;
  const exercisedCount = rights.filter((r) => r.status === 'exercised').length;
  const waivedCount = rights.filter((r) => r.status === 'waived').length;

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Pro Rata Right Tracker v2</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track pro-rata rights exercise per investor across rounds. Active & expiring rights surface for follow-up.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs uppercase text-gray-500">Total Rights</div>
          <div className="text-2xl font-semibold">{rights.length}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs uppercase text-gray-500">Active</div>
          <div className="text-2xl font-semibold">{activeCount}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs uppercase text-gray-500">Exercised</div>
          <div className="text-2xl font-semibold">{exercisedCount}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs uppercase text-gray-500">Waived</div>
          <div className="text-2xl font-semibold">{waivedCount}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Expiring Soon (next 30 days)</h2>
        <DataTable rows={expiring} columns={expiringCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Pro Rata Rights</h2>
        <DataTable rows={rights} columns={rightsCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Decisions Summary (30d)</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.decision ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decision Log</h2>
        <DataTable rows={decisions} columns={decisionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
