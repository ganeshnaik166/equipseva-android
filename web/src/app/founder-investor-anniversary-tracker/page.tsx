import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [allRes, upcomingRes, missedRes, outreachRes] = await Promise.all([
    sb.rpc('list_anniversaries_r1725'),
    sb.rpc('upcoming_anniversaries_this_month_r1725'),
    sb.rpc('missed_anniversaries_r1725'),
    sb.rpc('list_outreach_r1725', { p_anniversary_id: null }),
  ]);

  const all: any[] = Array.isArray(allRes.data) ? allRes.data : [];
  const upcoming: any[] = Array.isArray(upcomingRes.data) ? upcomingRes.data : [];
  const missed: any[] = Array.isArray(missedRes.data) ? missedRes.data : [];
  const outreach: any[] = Array.isArray(outreachRes.data) ? outreachRes.data : [];

  const annivCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'first_check_date', header: 'First Check', render: (r: any) => r.first_check_date ?? '—' },
    { key: 'date', header: 'Anniv Date', render: (r: any) => `${r.anniversary_month}/${r.anniversary_day}` },
    { key: 'total_invested_rupees', header: 'Invested (Rs)', render: (r: any) => Number(r.total_invested_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'last_thanked_at', header: 'Last Thanked', render: (r: any) => r.last_thanked_at ? new Date(r.last_thanked_at).toLocaleDateString() : 'never' },
    { key: 'founder_note', header: 'Note', render: (r: any) => r.founder_note ?? '—' },
  ];

  const upcomingCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'day', header: 'Day', render: (r: any) => String(r.anniversary_day) },
    { key: 'total_invested_rupees', header: 'Invested (Rs)', render: (r: any) => Number(r.total_invested_rupees ?? 0).toLocaleString('en-IN') },
    { key: 'last_thanked_at', header: 'Last Thanked', render: (r: any) => r.last_thanked_at ? new Date(r.last_thanked_at).toLocaleDateString() : 'never' },
    { key: 'founder_note', header: 'Note', render: (r: any) => r.founder_note ?? '—' },
  ];

  const missedCols: Column<any>[] = [
    { key: 'investor_id', header: 'Investor', render: (r: any) => String(r.investor_id ?? '').slice(0, 8) },
    { key: 'date', header: 'Anniv', render: (r: any) => `${r.anniversary_month}/${r.anniversary_day}` },
    { key: 'last_thanked_at', header: 'Last Thanked', render: (r: any) => r.last_thanked_at ? new Date(r.last_thanked_at).toLocaleDateString() : 'never' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'founder_note', header: 'Note', render: (r: any) => r.founder_note ?? '—' },
  ];

  const outreachCols: Column<any>[] = [
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '—' },
    { key: 'outreach_type', header: 'Type', render: (r: any) => String(r.outreach_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'response_received', header: 'Response?', render: (r: any) => r.response_received ? 'yes' : 'no' },
    { key: 'anniversary_id', header: 'Anniv', render: (r: any) => String(r.anniversary_id ?? '').slice(0, 8) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'system-ui' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 16 }}>
        Investor Anniversary Tracker
      </h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Track investor check anniversaries. Send thank-you outreach. Catch missed anniversaries before they hurt relationships.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          This Month ({upcoming.length})
        </h2>
        <DataTable rows={upcoming} columns={upcomingCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Missed / Overdue ({missed.length})
        </h2>
        <p style={{ color: '#888', fontSize: 13, marginBottom: 8 }}>
          Not thanked in the last 365 days.
        </p>
        <DataTable rows={missed} columns={missedCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          All Anniversaries ({all.length})
        </h2>
        <DataTable rows={all} columns={annivCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>
          Outreach Log ({outreach.length})
        </h2>
        <DataTable rows={outreach} columns={outreachCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
