import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderInvestorQuarterlyLetterComposerPage() {
  const sb = await getSupabaseServerClient();

  const [lettersRes, sendsRes, recentLettersRes, recentSendsRes] = await Promise.all([
    sb.rpc('list_letters_r2017', { p_limit: 100 }),
    sb.rpc('list_sends_r2017', { p_limit: 100 }),
    sb.rpc('recent_letters_r2017', { p_days: 90 }),
    sb.rpc('recent_sends_r2017', { p_days: 30 }),
  ]);

  const letters: any[] = (lettersRes.data as any[]) || [];
  const sends: any[] = (sendsRes.data as any[]) || [];
  const recentLetters: any[] = (recentLettersRes.data as any[]) || [];
  const recentSends: any[] = (recentSendsRes.data as any[]) || [];

  const lettersColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'letter_title', header: 'Title', render: (r: any) => String(r.letter_title ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'drafted_at', header: 'Drafted', render: (r: any) => r.drafted_at ? new Date(r.drafted_at).toLocaleString() : '' },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : 'pending' },
    { key: 'sent_count', header: 'Recipients', render: (r: any) => String(r.sent_count ?? 0) },
  ];

  const sendsColumns: Column<any>[] = [
    { key: 'letter_id', header: 'Letter', render: (r: any) => String(r.letter_id ?? '').slice(0, 8) },
    { key: 'send_type', header: 'Type', render: (r: any) => String(r.send_type ?? '') },
    { key: 'recipient_count', header: 'Recipients', render: (r: any) => String(r.recipient_count ?? 0) },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'notes_md', header: 'Notes', render: (r: any) => String(r.notes_md ?? '').slice(0, 80) },
  ];

  const recentLettersColumns: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => String(r.quarter_label ?? '') },
    { key: 'letter_title', header: 'Title', render: (r: any) => String(r.letter_title ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'drafted_at', header: 'Drafted', render: (r: any) => r.drafted_at ? new Date(r.drafted_at).toLocaleDateString() : '' },
    { key: 'sent_count', header: 'Recipients', render: (r: any) => String(r.sent_count ?? 0) },
  ];

  const recentSendsColumns: Column<any>[] = [
    { key: 'letter_id', header: 'Letter', render: (r: any) => String(r.letter_id ?? '').slice(0, 8) },
    { key: 'send_type', header: 'Type', render: (r: any) => String(r.send_type ?? '') },
    { key: 'recipient_count', header: 'Recipients', render: (r: any) => String(r.recipient_count ?? 0) },
    { key: 'sent_at', header: 'Sent', render: (r: any) => r.sent_at ? new Date(r.sent_at).toLocaleString() : '' },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
  ];

  const totalLetters = letters.length;
  const draftCount = letters.filter((l) => l.status === 'draft').length;
  const reviewCount = letters.filter((l) => l.status === 'review').length;
  const sentCount = letters.filter((l) => l.status === 'sent').length;
  const archivedCount = letters.filter((l) => l.status === 'archived').length;
  const totalRecipients = letters.reduce((acc, l) => acc + (l.sent_count || 0), 0);
  const sendsLast30 = recentSends.length;

  return (
    <div style={{ padding: '2rem', maxWidth: '1200px', margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <header style={{ marginBottom: '2rem' }}>
        <h1 style={{ fontSize: '2rem', fontWeight: 700, marginBottom: '0.5rem' }}>
          Investor Quarterly Letter Composer
        </h1>
        <p style={{ color: '#666', fontSize: '0.95rem' }}>
          Compose, review, and dispatch quarterly investor letters. Track broadcast, personalized, and special announcement sends.
        </p>
      </header>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '1rem' }}>Summary</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '1rem' }}>
          <div style={{ padding: '1rem', background: '#f5f5f5', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.85rem', color: '#666' }}>Total letters</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{totalLetters}</div>
          </div>
          <div style={{ padding: '1rem', background: '#fff7e6', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.85rem', color: '#666' }}>Draft</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{draftCount}</div>
          </div>
          <div style={{ padding: '1rem', background: '#e6f4ff', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.85rem', color: '#666' }}>In review</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{reviewCount}</div>
          </div>
          <div style={{ padding: '1rem', background: '#e6ffed', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.85rem', color: '#666' }}>Sent</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{sentCount}</div>
          </div>
          <div style={{ padding: '1rem', background: '#f0f0f0', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.85rem', color: '#666' }}>Archived</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{archivedCount}</div>
          </div>
          <div style={{ padding: '1rem', background: '#fff0f6', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.85rem', color: '#666' }}>Total recipients</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{totalRecipients}</div>
          </div>
          <div style={{ padding: '1rem', background: '#f9f0ff', borderRadius: '8px' }}>
            <div style={{ fontSize: '0.85rem', color: '#666' }}>Sends last 30d</div>
            <div style={{ fontSize: '1.5rem', fontWeight: 700 }}>{sendsLast30}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '1rem' }}>All letters</h2>
        <DataTable
          rows={letters}
          columns={lettersColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '1rem' }}>Recent letters (90 days)</h2>
        <DataTable
          rows={recentLetters}
          columns={recentLettersColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '1rem' }}>Send log</h2>
        <DataTable
          rows={sends}
          columns={sendsColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: '1.25rem', fontWeight: 600, marginBottom: '1rem' }}>Recent sends (30 days)</h2>
        <DataTable
          rows={recentSends}
          columns={recentSendsColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <footer style={{ marginTop: '3rem', paddingTop: '1rem', borderTop: '1px solid #eee', color: '#888', fontSize: '0.85rem' }}>
        Round 2017 — founder console. Letters flow draft to review to sent. Send types: broadcast, personalized, special announce.
      </footer>
    </div>
  );
}
