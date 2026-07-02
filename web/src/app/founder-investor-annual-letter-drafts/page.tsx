import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorAnnualLetterDraftsPage() {
  const sb = await getSupabaseServerClient();

  const [allLetters, recent, needsReview] = await Promise.all([
    sb.rpc('list_letters_r1905'),
    sb.rpc('recent_letters_r1905'),
    sb.rpc('letters_needing_review_r1905'),
  ]);

  const allRows: any[] = Array.isArray(allLetters.data) ? allLetters.data : [];
  const recentRows: any[] = Array.isArray(recent.data) ? recent.data : [];
  const reviewRows: any[] = Array.isArray(needsReview.data) ? needsReview.data : [];

  const allCols: Column<any>[] = [
    { key: 'year', header: 'Year', render: (r: any) => String(r.year ?? '') },
    { key: 'letter_title', header: 'Title', render: (r: any) => String(r.letter_title ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'target_send_date', header: 'Target Send', render: (r: any) => r.target_send_date ? String(r.target_send_date) : '—' },
    { key: 'drafted_at', header: 'Drafted At', render: (r: any) => r.drafted_at ? new Date(r.drafted_at).toLocaleString() : '—' },
    { key: 'drafted_by_email', header: 'Drafted By', render: (r: any) => String(r.drafted_by_email ?? '—') },
  ];

  const recentCols: Column<any>[] = [
    { key: 'year', header: 'Year', render: (r: any) => String(r.year ?? '') },
    { key: 'letter_title', header: 'Title', render: (r: any) => String(r.letter_title ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'drafted_at', header: 'Drafted At', render: (r: any) => r.drafted_at ? new Date(r.drafted_at).toLocaleString() : '—' },
  ];

  const reviewCols: Column<any>[] = [
    { key: 'year', header: 'Year', render: (r: any) => String(r.year ?? '') },
    { key: 'letter_title', header: 'Title', render: (r: any) => String(r.letter_title ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'target_send_date', header: 'Target Send', render: (r: any) => r.target_send_date ? String(r.target_send_date) : '—' },
    { key: 'drafted_at', header: 'Drafted At', render: (r: any) => r.drafted_at ? new Date(r.drafted_at).toLocaleString() : '—' },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>Investor Annual Letter Drafts</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Track annual letter drafts & revisions for investors. Founder-only console (r1905).
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Letters Needing Review ({reviewRows.length})
        </h2>
        <DataTable rows={reviewRows} columns={reviewCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          Recent Letters (last 180 days)
        </h2>
        <DataTable rows={recentRows} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>
          All Letters ({allRows.length})
        </h2>
        <DataTable rows={allRows} columns={allCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
