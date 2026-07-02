import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorVotingRightsTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [rightsRes, eventsRes, tallyRes, seatRes, abstainRes] = await Promise.all([
    sb.rpc('list_voting_rights_r1701'),
    sb.rpc('list_vote_events_r1701'),
    sb.rpc('voting_tally_per_topic_r1701'),
    sb.rpc('board_seat_summary_r1701'),
    sb.rpc('abstainers_recent_r1701'),
  ]);

  const rights = (rightsRes.data ?? []) as any[];
  const events = (eventsRes.data ?? []) as any[];
  const tally = (tallyRes.data ?? []) as any[];
  const seats = (seatRes.data ?? []) as any[];
  const abstainers = (abstainRes.data ?? []) as any[];

  const totalInvestors = rights.length;
  const totalVotesAll = rights.reduce((acc: number, r: any) => acc + Number(r.total_votes ?? 0), 0);
  const totalSeatsAll = rights.reduce((acc: number, r: any) => acc + Number(r.board_seats ?? 0), 0);
  const totalEvents = events.length;

  const fmtNum = (n: number | null | undefined) =>
    n == null ? '—' : Number(n).toLocaleString('en-IN');

  const rightsColumns: Column<any>[] = [
    {
      key: 'investor_email',
      header: 'Investor',
      render: (r: any) => r.investor_email ?? r.investor_id?.slice(0, 8) ?? '—',
    },
    { key: 'voting_class', header: 'Class', render: (r: any) => r.voting_class ?? '—' },
    { key: 'total_votes', header: 'Total Votes', render: (r: any) => fmtNum(r.total_votes) },
    { key: 'board_seats', header: 'Board Seats', render: (r: any) => fmtNum(r.board_seats) },
    { key: 'since_date', header: 'Since', render: (r: any) => r.since_date ?? '—' },
    { key: 'events_count', header: 'Vote Events', render: (r: any) => fmtNum(r.events_count) },
  ];

  const eventsColumns: Column<any>[] = [
    { key: 'vote_date', header: 'Date', render: (r: any) => r.vote_date ?? '—' },
    {
      key: 'investor_email',
      header: 'Investor',
      render: (r: any) => r.investor_email ?? '—',
    },
    { key: 'voting_class', header: 'Class', render: (r: any) => r.voting_class ?? '—' },
    { key: 'vote_topic', header: 'Topic', render: (r: any) => r.vote_topic ?? '—' },
    { key: 'vote_cast', header: 'Cast', render: (r: any) => r.vote_cast ?? '—' },
    { key: 'vote_weight', header: 'Weight', render: (r: any) => fmtNum(r.vote_weight) },
    { key: 'founder_note', header: 'Note', render: (r: any) => r.founder_note ?? '—' },
  ];

  const tallyColumns: Column<any>[] = [
    { key: 'vote_topic', header: 'Topic', render: (r: any) => r.vote_topic ?? '—' },
    { key: 'events_count', header: 'Events', render: (r: any) => fmtNum(r.events_count) },
    { key: 'yes_weight', header: 'Yes', render: (r: any) => fmtNum(r.yes_weight) },
    { key: 'no_weight', header: 'No', render: (r: any) => fmtNum(r.no_weight) },
    { key: 'abstain_weight', header: 'Abstain', render: (r: any) => fmtNum(r.abstain_weight) },
    { key: 'absent_weight', header: 'Absent', render: (r: any) => fmtNum(r.absent_weight) },
    { key: 'total_weight', header: 'Total', render: (r: any) => fmtNum(r.total_weight) },
    { key: 'last_vote_date', header: 'Last Vote', render: (r: any) => r.last_vote_date ?? '—' },
  ];

  const seatColumns: Column<any>[] = [
    { key: 'voting_class', header: 'Class', render: (r: any) => r.voting_class ?? '—' },
    { key: 'investors_count', header: 'Investors', render: (r: any) => fmtNum(r.investors_count) },
    { key: 'total_votes_sum', header: 'Votes Sum', render: (r: any) => fmtNum(r.total_votes_sum) },
    { key: 'board_seats_sum', header: 'Board Seats Sum', render: (r: any) => fmtNum(r.board_seats_sum) },
  ];

  const abstainColumns: Column<any>[] = [
    { key: 'vote_date', header: 'Date', render: (r: any) => r.vote_date ?? '—' },
    {
      key: 'investor_email',
      header: 'Investor',
      render: (r: any) => r.investor_email ?? '—',
    },
    { key: 'voting_class', header: 'Class', render: (r: any) => r.voting_class ?? '—' },
    { key: 'vote_topic', header: 'Topic', render: (r: any) => r.vote_topic ?? '—' },
    { key: 'vote_cast', header: 'Cast', render: (r: any) => r.vote_cast ?? '—' },
    { key: 'vote_weight', header: 'Weight', render: (r: any) => fmtNum(r.vote_weight) },
    { key: 'founder_note', header: 'Note', render: (r: any) => r.founder_note ?? '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Investor Voting Rights Tracker</h1>
      <p style={{ color: '#6b7280', marginBottom: 24 }}>
        Per-investor voting rights, vote events, and abstention trail (last 180d).
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Summary</h2>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
            gap: 12,
          }}
        >
          <Card label="Investors" value={String(totalInvestors)} />
          <Card label="Total Votes" value={fmtNum(totalVotesAll)} />
          <Card label="Board Seats" value={fmtNum(totalSeatsAll)} />
          <Card label="Vote Events" value={fmtNum(totalEvents)} />
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Voting Rights</h2>
        <DataTable
          rows={rights}
          columns={rightsColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Board Seat Summary (by Class)</h2>
        <DataTable
          rows={seats}
          columns={seatColumns}
          rowKey={(r: any, i: number) => String(r.voting_class ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Voting Tally per Topic</h2>
        <DataTable
          rows={tally}
          columns={tallyColumns}
          rowKey={(r: any, i: number) => String(r.vote_topic ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>
          Recent Abstainers / Absent (last 180d)
        </h2>
        <DataTable
          rows={abstainers}
          columns={abstainColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent Vote Events</h2>
        <DataTable
          rows={events}
          columns={eventsColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function Card({ label, value }: { label: string; value: string }) {
  return (
    <div
      style={{
        background: '#f9fafb',
        border: '1px solid #e5e7eb',
        borderRadius: 8,
        padding: 16,
      }}
    >
      <div style={{ fontSize: 12, color: '#6b7280', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
