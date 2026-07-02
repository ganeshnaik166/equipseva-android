import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

function fmtRupees(n: number | null | undefined): string {
  if (n == null) return "—";
  return "₹ " + n.toLocaleString('en-IN');
}

function fmtNum(n: number | null | undefined): string {
  if (n == null) return "—";
  return n.toLocaleString('en-IN');
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return "—";
  return new Date(s).toLocaleDateString('en-IN');
}

export default async function FounderInvestorCapitalCallQueuePage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let roster: any[] = [];
  let upcoming: any[] = [];
  let sendList: any[] = [];

  try {
    const r = await sb.rpc('founder_capital_call_kpis');
    kpis = (r.data && r.data[0]) || null;
  } catch (_e) {
    kpis = null;
  }

  try {
    const r = await sb.rpc('founder_capital_commitments_roster');
    roster = (r.data as any[]) || [];
  } catch (_e) {
    roster = [];
  }

  try {
    const r = await sb.rpc('founder_capital_call_queue_upcoming');
    upcoming = (r.data as any[]) || [];
  } catch (_e) {
    upcoming = [];
  }

  try {
    const r = await sb.rpc('founder_capital_call_send_list');
    sendList = (r.data as any[]) || [];
  } catch (_e) {
    sendList = [];
  }

  const cards: Kpi[] = [
    { label: 'Total Commitments', value: fmtNum(kpis?.total_commitments) },
    { label: 'Active', value: fmtNum(kpis?.active_commitments) },
    { label: 'Paused', value: fmtNum(kpis?.paused_commitments) },
    { label: 'Closed', value: fmtNum(kpis?.closed_commitments) },
    { label: 'Defaulted', value: fmtNum(kpis?.defaulted_commitments) },
    { label: 'Total Committed', value: fmtRupees(kpis?.total_committed_rupees) },
    { label: 'Total Called', value: fmtRupees(kpis?.total_called_rupees) },
    { label: 'Total Remaining', value: fmtRupees(kpis?.total_remaining_rupees) },
    { label: 'Total Funded', value: fmtRupees(kpis?.total_funded_rupees) },
    { label: 'Calls Queued', value: fmtNum(kpis?.calls_queued) },
    { label: 'Calls Sent', value: fmtNum(kpis?.calls_sent) },
    { label: 'Calls Acknowledged', value: fmtNum(kpis?.calls_acknowledged) },
    { label: 'Calls Funded', value: fmtNum(kpis?.calls_funded) },
    { label: 'Calls Overdue', value: fmtNum(kpis?.calls_overdue) },
    { label: 'Next Due Date', value: fmtDate(kpis?.next_due_date) },
    { label: 'Next Due Amount', value: fmtRupees(kpis?.next_due_amount_rupees) },
  ];

  const rosterColumns: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'investor_email', header: 'Email', render: (r: any) => r.investor_email ?? "—" },
    { key: 'investor_entity_type', header: 'Entity', render: (r: any) => r.investor_entity_type ?? "—" },
    { key: 'committed_amount_rupees', header: 'Committed', render: (r: any) => fmtRupees(r.committed_amount_rupees) },
    { key: 'called_amount_rupees', header: 'Called', render: (r: any) => fmtRupees(r.called_amount_rupees) },
    { key: 'remaining_amount_rupees', header: 'Remaining', render: (r: any) => fmtRupees(r.remaining_amount_rupees) },
    { key: 'pct_called', header: '% Called', render: (r: any) => (r.pct_called != null ? r.pct_called + '%' : "—") },
    { key: 'open_calls', header: 'Open Calls', render: (r: any) => fmtNum(r.open_calls) },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
  ];

  const upcomingColumns: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'call_number', header: 'Call #', render: (r: any) => fmtNum(r.call_number) },
    { key: 'call_amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.call_amount_rupees) },
    { key: 'due_date', header: 'Due', render: (r: any) => fmtDate(r.due_date) },
    { key: 'days_until_due', header: 'Days', render: (r: any) => fmtNum(r.days_until_due) },
    { key: 'purpose', header: 'Purpose', render: (r: any) => r.purpose ?? "—" },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? "—" },
    { key: 'reminder_count', header: 'Reminders', render: (r: any) => fmtNum(r.reminder_count) },
  ];

  const sendColumns: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? "—" },
    { key: 'investor_email', header: 'Email', render: (r: any) => r.investor_email ?? "—" },
    { key: 'call_number', header: 'Call #', render: (r: any) => fmtNum(r.call_number) },
    { key: 'call_amount_rupees', header: 'Amount', render: (r: any) => fmtRupees(r.call_amount_rupees) },
    { key: 'due_date', header: 'Due', render: (r: any) => fmtDate(r.due_date) },
    { key: 'purpose', header: 'Purpose', render: (r: any) => r.purpose ?? "—" },
    { key: 'remaining_commitment_rupees', header: 'Remaining', render: (r: any) => fmtRupees(r.remaining_commitment_rupees) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Investor Capital Call Queue</h1>
        <p className="text-sm text-gray-600">Upcoming drawdowns from committed funds. Per-investor commitments, called amount, remaining, and send list.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-4 gap-3">
        {cards.map((c, i) => (
          <div key={i} className="rounded-lg border p-3 bg-white">
            <div className="text-xs text-gray-500">{c.label}</div>
            <div className="text-lg font-semibold">{c.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Commitment Roster</h2>
        <DataTable columns={rosterColumns} rows={roster} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Upcoming Capital Call Queue</h2>
        <DataTable columns={upcomingColumns} rows={upcoming} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Founder Send List (Queued)</h2>
        <DataTable columns={sendColumns} rows={sendList as any[]} rowKey={(r: any) => r.call_id} />
      </section>
    </main>
  );
}
