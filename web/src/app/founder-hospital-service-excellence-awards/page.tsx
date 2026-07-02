import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type AwardRow = {
  id: string;
  award_year: number;
  award_category: string;
  recipient_user_id: string | null;
  recipient_name: string;
  citation_md: string;
  voted_by_count: number;
  announced_at: string | null;
  created_at: string;
};

type YearSummaryRow = {
  award_year: number;
  awards_count: number;
  categories_filled: number;
  total_nominations: number;
  total_votes: number;
};

type TopNomineeRow = {
  nominee_user_id: string | null;
  nominee_name: string;
  nomination_count: number;
  total_votes: number;
  last_nominated_at: string | null;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [awardsRes, yearSumRes, topNomRes] = await Promise.all([
    sb.rpc('list_excellence_awards_r1827'),
    sb.rpc('excellence_year_summary_r1827'),
    sb.rpc('excellence_top_nominees_r1827'),
  ]);

  const awards: AwardRow[] = (awardsRes.data as AwardRow[] | null) ?? [];
  const years: YearSummaryRow[] = (yearSumRes.data as YearSummaryRow[] | null) ?? [];
  const nominees: TopNomineeRow[] = (topNomRes.data as TopNomineeRow[] | null) ?? [];

  const awardCols: Column<AwardRow>[] = [
    { key: 'award_year', header: 'Year', render: (r: any) => r.award_year },
    { key: 'award_category', header: 'Category', render: (r: any) => r.award_category },
    { key: 'recipient_name', header: 'Recipient', render: (r: any) => r.recipient_name },
    { key: 'recipient_user_id', header: 'User', render: (r: any) => r.recipient_user_id ? String(r.recipient_user_id).slice(0, 8) : '—' },
    { key: 'voted_by_count', header: 'Votes', render: (r: any) => r.voted_by_count },
    { key: 'announced_at', header: 'Announced', render: (r: any) => r.announced_at ? String(r.announced_at).slice(0, 10) : '—' },
    { key: 'citation_md', header: 'Citation', render: (r: any) => String(r.citation_md ?? '').slice(0, 80) },
  ];

  const yearCols: Column<YearSummaryRow>[] = [
    { key: 'award_year', header: 'Year', render: (r: any) => r.award_year },
    { key: 'awards_count', header: 'Awards', render: (r: any) => r.awards_count },
    { key: 'categories_filled', header: 'Categories', render: (r: any) => r.categories_filled },
    { key: 'total_nominations', header: 'Nominations', render: (r: any) => r.total_nominations },
    { key: 'total_votes', header: 'Votes', render: (r: any) => r.total_votes },
  ];

  const nomineeCols: Column<TopNomineeRow>[] = [
    { key: 'nominee_name', header: 'Nominee', render: (r: any) => r.nominee_name || '—' },
    { key: 'nominee_user_id', header: 'User', render: (r: any) => r.nominee_user_id ? String(r.nominee_user_id).slice(0, 8) : '—' },
    { key: 'nomination_count', header: 'Nominations', render: (r: any) => r.nomination_count },
    { key: 'total_votes', header: 'Votes', render: (r: any) => r.total_votes },
    { key: 'last_nominated_at', header: 'Last', render: (r: any) => r.last_nominated_at ? String(r.last_nominated_at).slice(0, 10) : '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Service Excellence Awards</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Annual customer-service excellence awards for engineers and ops team. Categories: engineer_of_year, ops_lead, customer_champion, lifetime_impact.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All awards ({awards.length})</h2>
        <DataTable
          rows={awards}
          columns={awardCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Year summary ({years.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Per-year roll-up: awards presented, distinct categories filled, nominations received, total votes cast.
        </p>
        <DataTable
          rows={years}
          columns={yearCols}
          rowKey={(r: any, i: number) => String(r.award_year ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top nominees ({nominees.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Nominees ranked by total votes & nomination count across all award years.
        </p>
        <DataTable
          rows={nominees}
          columns={nomineeCols}
          rowKey={(r: any, i: number) => String(r.nominee_user_id ?? i)}
        />
      </section>
    </div>
  );
}
