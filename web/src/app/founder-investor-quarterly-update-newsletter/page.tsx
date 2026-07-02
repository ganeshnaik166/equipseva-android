import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Newsletter = {
  id: string;
  fiscal_quarter: string;
  headline: string;
  status: string;
  drafted_at: string | null;
  sent_at: string | null;
  sent_to_count: number;
  audience_segments: string[] | null;
  created_at: string;
};

type SendLog = {
  id: string;
  newsletter_id: string;
  recipient_email: string;
  sent_at: string;
  opened_at: string | null;
  clicked: boolean;
  reply_received: boolean;
};

type OpenRate = {
  newsletter_id: string;
  fiscal_quarter: string;
  headline: string;
  total_sent: number;
  total_opened: number;
  total_clicked: number;
  total_replied: number;
  open_rate_pct: number;
};

function fmt(ts: string | null | undefined): string {
  if (!ts) return '-';
  try {
    return new Date(ts).toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });
  } catch {
    return String(ts);
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [nlRes, orRes] = await Promise.all([
    sb.rpc('list_newsletters_r1873'),
    sb.rpc('open_rate_summary_r1873'),
  ]);

  const newsletters: Newsletter[] = (nlRes.data as Newsletter[] | null) ?? [];
  const openRates: OpenRate[] = (orRes.data as OpenRate[] | null) ?? [];

  const latestId = newsletters[0]?.id;
  let sendLog: SendLog[] = [];
  if (latestId) {
    const slRes = await sb.rpc('list_send_log_r1873', { p_newsletter_id: latestId });
    sendLog = (slRes.data as SendLog[] | null) ?? [];
  }

  const totalNewsletters = newsletters.length;
  const draftCount = newsletters.filter((n) => n.status === 'draft').length;
  const sentCount = newsletters.filter((n) => n.status === 'sent').length;
  const totalRecipients = newsletters.reduce((a, n) => a + (n.sent_to_count ?? 0), 0);

  const nlCols: Column<Newsletter>[] = [
    { key: 'fiscal_quarter', header: 'Quarter', render: (r: any) => <span className="font-mono">{r.fiscal_quarter}</span> },
    { key: 'headline', header: 'Headline', render: (r: any) => <span>{r.headline}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span className="uppercase text-xs">{r.status}</span> },
    { key: 'audience_segments', header: 'Audience', render: (r: any) => <span>{Array.isArray(r.audience_segments) ? r.audience_segments.join(', ') : '-'}</span> },
    { key: 'sent_to_count', header: 'Sent To', render: (r: any) => <span>{r.sent_to_count ?? 0}</span> },
    { key: 'drafted_at', header: 'Drafted', render: (r: any) => <span>{fmt(r.drafted_at)}</span> },
    { key: 'sent_at', header: 'Sent', render: (r: any) => <span>{fmt(r.sent_at)}</span> },
  ];

  const orCols: Column<OpenRate>[] = [
    { key: 'fiscal_quarter', header: 'Quarter', render: (r: any) => <span className="font-mono">{r.fiscal_quarter}</span> },
    { key: 'headline', header: 'Headline', render: (r: any) => <span>{r.headline}</span> },
    { key: 'total_sent', header: 'Sent', render: (r: any) => <span>{r.total_sent}</span> },
    { key: 'total_opened', header: 'Opened', render: (r: any) => <span>{r.total_opened}</span> },
    { key: 'total_clicked', header: 'Clicked', render: (r: any) => <span>{r.total_clicked}</span> },
    { key: 'total_replied', header: 'Replied', render: (r: any) => <span>{r.total_replied}</span> },
    { key: 'open_rate_pct', header: 'Open %', render: (r: any) => <span>{r.open_rate_pct}%</span> },
  ];

  const slCols: Column<SendLog>[] = [
    { key: 'recipient_email', header: 'Recipient', render: (r: any) => <span className="font-mono text-xs">{r.recipient_email}</span> },
    { key: 'sent_at', header: 'Sent', render: (r: any) => <span>{fmt(r.sent_at)}</span> },
    { key: 'opened_at', header: 'Opened', render: (r: any) => <span>{fmt(r.opened_at)}</span> },
    { key: 'clicked', header: 'Clicked', render: (r: any) => <span>{r.clicked ? 'yes' : 'no'}</span> },
    { key: 'reply_received', header: 'Replied', render: (r: any) => <span>{r.reply_received ? 'yes' : 'no'}</span> },
  ];

  return (
    <main className="p-6 space-y-8">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Investor Quarterly Update Newsletter</h1>
        <p className="text-sm text-gray-600">
          Draft, finalize & track quarterly investor updates. All sends & opens captured in audit log.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total Newsletters</div>
          <div className="text-xl font-semibold">{totalNewsletters}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Drafts</div>
          <div className="text-xl font-semibold">{draftCount}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Sent</div>
          <div className="text-xl font-semibold">{sentCount}</div>
        </div>
        <div className="rounded border p-3">
          <div className="text-xs text-gray-500">Total Recipients</div>
          <div className="text-xl font-semibold">{totalRecipients}</div>
        </div>
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Newsletters</h2>
        <DataTable
          rows={newsletters}
          columns={nlCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">Open-Rate Summary</h2>
        <DataTable
          rows={openRates}
          columns={orCols}
          rowKey={(r: any, i: number) => String(r.newsletter_id ?? i)}
        />
      </section>

      <section className="space-y-2">
        <h2 className="text-lg font-medium">
          Send Log {latestId ? <span className="text-xs text-gray-500">(latest newsletter)</span> : null}
        </h2>
        <DataTable
          rows={sendLog}
          columns={slCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <footer className="text-xs text-gray-500">
        r1873 · founder-only · reads & writes gated by is_founder()
      </footer>
    </main>
  );
}
