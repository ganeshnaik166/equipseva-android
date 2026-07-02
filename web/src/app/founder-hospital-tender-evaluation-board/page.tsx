import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [tendersRes, wonRes, recentRes] = await Promise.all([
    sb.rpc('list_tenders_r2019'),
    sb.rpc('won_tenders_r2019'),
    sb.rpc('recent_actions_r2019'),
  ]);

  const tenders: any[] = Array.isArray(tendersRes.data) ? tendersRes.data : [];
  const won: any[] = Array.isArray(wonRes.data) ? wonRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const totalValue = tenders.reduce((s, t) => s + Number(t.tender_value_rupees || 0), 0);
  const wonValue = won.reduce((s, t) => s + Number(t.tender_value_rupees || 0), 0);
  const lostValue = tenders.reduce((s, t) => s + Number(t.value_lost_rupees || 0), 0);

  const tenderCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '—') },
    { key: 'tender_label', header: 'Tender', render: (r: any) => String(r.tender_label ?? '') },
    { key: 'tender_value_rupees', header: 'Value', render: (r: any) => '₹' + Number(r.tender_value_rupees || 0).toLocaleString('en-IN') },
    { key: 'submitted_date', header: 'Submitted', render: (r: any) => r.submitted_date ? String(r.submitted_date) : '—' },
    { key: 'evaluation_status', header: 'Status', render: (r: any) => String(r.evaluation_status ?? '') },
    { key: 'competition_count', header: 'Competitors', render: (r: any) => String(r.competition_count ?? 0) },
    { key: 'value_lost_rupees', header: 'Value Lost', render: (r: any) => r.value_lost_rupees ? '₹' + Number(r.value_lost_rupees).toLocaleString('en-IN') : '—' },
  ];

  const wonCols: Column<any>[] = [
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => String(r.hospital_name ?? '—') },
    { key: 'tender_label', header: 'Tender', render: (r: any) => String(r.tender_label ?? '') },
    { key: 'tender_value_rupees', header: 'Value', render: (r: any) => '₹' + Number(r.tender_value_rupees || 0).toLocaleString('en-IN') },
    { key: 'won_at', header: 'Won At', render: (r: any) => r.won_at ? new Date(r.won_at).toLocaleDateString('en-IN') : '—' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'tender_label', header: 'Tender', render: (r: any) => String(r.tender_label ?? '—') },
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'taken_at', header: 'When', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString('en-IN') : '—' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '—') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Hospital Tender Evaluation Board</h1>
        <p className="text-sm text-gray-600">Track hospital tenders we evaluate, bid on, win, or decline. Round r2019.</p>
      </header>

      <section className="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Total Tenders</div>
          <div className="text-2xl font-semibold">{tenders.length}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Pipeline Value</div>
          <div className="text-2xl font-semibold">₹{totalValue.toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Won Value</div>
          <div className="text-2xl font-semibold">₹{wonValue.toLocaleString('en-IN')}</div>
        </div>
        <div className="rounded border p-4">
          <div className="text-xs uppercase text-gray-500">Lost Value</div>
          <div className="text-2xl font-semibold">₹{lostValue.toLocaleString('en-IN')}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">All Tenders</h2>
        <DataTable rows={tenders} columns={tenderCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Won Tenders</h2>
        <DataTable rows={won} columns={wonCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-semibold">Recent Actions</h2>
        <DataTable rows={recent} columns={actionCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
