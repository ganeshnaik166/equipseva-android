import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type LetterRow = {
  id: string;
  investor_id: string;
  letter_title: string;
  executed_on: string;
  expiry_date: string | null;
  status: string;
  obligation_count: number;
  open_obligation_count: number;
};

type OverdueRow = {
  id: string;
  letter_id: string;
  letter_title: string;
  investor_id: string;
  obligation_text: string;
  due_date: string | null;
  days_overdue: number;
  status: string;
};

type SummaryRow = {
  investor_id: string;
  active_letters: number;
  expired_letters: number;
  superseded_letters: number;
  total_obligations: number;
  open_obligations: number;
  overdue_obligations: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [lettersRes, overdueRes, summaryRes] = await Promise.all([
    sb.rpc('list_letters_r1709'),
    sb.rpc('overdue_obligations_r1709'),
    sb.rpc('letter_summary_per_investor_r1709'),
  ]);

  const letters: LetterRow[] = (lettersRes.data as LetterRow[] | null) ?? [];
  const overdue: OverdueRow[] = (overdueRes.data as OverdueRow[] | null) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[] | null) ?? [];

  const letterCols: Column<LetterRow>[] = [
    { key: 'letter_title', header: 'Title', render: (r: any) => r.letter_title },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id).slice(0, 8) },
    { key: 'executed_on', header: 'Executed', render: (r: any) => r.executed_on ?? '—' },
    { key: 'expiry_date', header: 'Expiry', render: (r: any) => r.expiry_date ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'obligation_count', header: 'Obligations', render: (r: any) => r.obligation_count },
    { key: 'open_obligation_count', header: 'Open', render: (r: any) => r.open_obligation_count },
  ];

  const overdueCols: Column<OverdueRow>[] = [
    { key: 'letter_title', header: 'Letter', render: (r: any) => r.letter_title },
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id).slice(0, 8) },
    { key: 'obligation_text', header: 'Obligation', render: (r: any) => r.obligation_text },
    { key: 'due_date', header: 'Due', render: (r: any) => r.due_date ?? '—' },
    { key: 'days_overdue', header: 'Days overdue', render: (r: any) => r.days_overdue },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id).slice(0, 8) },
    { key: 'active_letters', header: 'Active', render: (r: any) => r.active_letters },
    { key: 'expired_letters', header: 'Expired', render: (r: any) => r.expired_letters },
    { key: 'superseded_letters', header: 'Superseded', render: (r: any) => r.superseded_letters },
    { key: 'total_obligations', header: 'Total obligations', render: (r: any) => r.total_obligations },
    { key: 'open_obligations', header: 'Open', render: (r: any) => r.open_obligations },
    { key: 'overdue_obligations', header: 'Overdue', render: (r: any) => r.overdue_obligations },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Side-Letter Tracker</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-investor side letters with custom commitments. Track active vs expired vs superseded letters, plus obligation status per letter.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All side letters ({letters.length})</h2>
        <DataTable
          rows={letters}
          columns={letterCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Overdue obligations ({overdue.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Obligations with due_date &lt; today and status not yet met.
        </p>
        <DataTable
          rows={overdue}
          columns={overdueCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary per investor ({summary.length})</h2>
        <DataTable
          rows={summary}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(r.investor_id ?? i)}
        />
      </section>
    </div>
  );
}
