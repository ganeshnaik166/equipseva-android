import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [letters, active, recent] = await Promise.all([
    sb.rpc('list_letters_r2113'),
    sb.rpc('active_letters_r2113'),
    sb.rpc('recent_actions_r2113'),
  ]);

  const letterRows: any[] = (letters.data as any[]) ?? [];
  const activeRows: any[] = (active.data as any[]) ?? [];
  const recentRows: any[] = (recent.data as any[]) ?? [];

  const letterCols: Column<any>[] = [
    { key: 'side_letter_label', header: 'Label', render: (r: any) => String(r.side_letter_label ?? '') },
    { key: 'obligation_type', header: 'Obligation Type', render: (r: any) => String(r.obligation_type ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'signed_date', header: 'Signed', render: (r: any) => r.signed_date ? String(r.signed_date) : 'pending' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
    { key: 'key_obligation_md', header: 'Obligation', render: (r: any) => String(r.key_obligation_md ?? '').slice(0, 80) },
  ];

  const activeCols: Column<any>[] = [
    { key: 'side_letter_label', header: 'Label', render: (r: any) => String(r.side_letter_label ?? '') },
    { key: 'obligation_type', header: 'Type', render: (r: any) => String(r.obligation_type ?? '') },
    { key: 'signed_date', header: 'Signed', render: (r: any) => r.signed_date ? String(r.signed_date) : '' },
    { key: 'captured_at', header: 'Captured', render: (r: any) => r.captured_at ? new Date(r.captured_at).toLocaleString() : '' },
  ];

  const recentCols: Column<any>[] = [
    { key: 'action_type', header: 'Action', render: (r: any) => String(r.action_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '' },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 120) },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Investor Side-Letter Bookkeeping</h1>
        <p className="text-sm text-gray-600">
          Track all investor side letters and their key obligations across info rights, reporting, governance, financial, and operational categories.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Active Side Letters</h2>
        <DataTable rows={activeRows} columns={activeCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All Side Letters</h2>
        <DataTable rows={letterRows} columns={letterCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent Actions</h2>
        <DataTable rows={recentRows} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
