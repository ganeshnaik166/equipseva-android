import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderPressOutreachTrackerPage() {
  const sb = await getSupabaseServerClient();

  const [outreachRes, summaryRes, outletsRes] = await Promise.all([
    sb.rpc('r1770_list_outreach'),
    sb.rpc('r1770_response_rate_summary'),
    sb.rpc('r1770_top_outlets'),
  ]);

  const outreach: any[] = Array.isArray(outreachRes.data) ? outreachRes.data : [];
  const summaryRow: any = Array.isArray(summaryRes.data) ? (summaryRes.data[0] ?? null) : null;
  const outlets: any[] = Array.isArray(outletsRes.data) ? outletsRes.data : [];

  const outreachCols: Column<any>[] = [
    { key: 'pitched_at', header: 'Pitched', render: (r: any) => r.pitched_at ? new Date(r.pitched_at).toLocaleDateString() : '—' },
    { key: 'outlet_name', header: 'Outlet', render: (r: any) => r.outlet_name ?? '—' },
    { key: 'journalist_name', header: 'Journalist', render: (r: any) => r.journalist_name ?? '—' },
    { key: 'journalist_email', header: 'Email', render: (r: any) => r.journalist_email ?? '—' },
    { key: 'pitch_subject', header: 'Subject', render: (r: any) => r.pitch_subject ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => <span className="font-mono text-xs uppercase">{r.outcome ?? '—'}</span> },
    { key: 'response_received', header: 'Replied', render: (r: any) => r.response_received ? 'yes' : 'no' },
    { key: 'published_at', header: 'Published', render: (r: any) => r.published_at ? new Date(r.published_at).toLocaleDateString() : '—' },
    { key: 'story_url', header: 'Story', render: (r: any) => r.story_url ? <a className="text-blue-600 underline" href={r.story_url} target="_blank" rel="noreferrer">link</a> : '—' },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'total_pitched', header: 'Total Pitched', render: (r: any) => r.total_pitched ?? 0 },
    { key: 'responded', header: 'Responded', render: (r: any) => r.responded ?? 0 },
    { key: 'in_review', header: 'In Review', render: (r: any) => r.in_review ?? 0 },
    { key: 'passed', header: 'Passed', render: (r: any) => r.passed ?? 0 },
    { key: 'published', header: 'Published', render: (r: any) => r.published ?? 0 },
    { key: 'response_rate_pct', header: 'Reply Rate %', render: (r: any) => r.response_rate_pct != null ? `${r.response_rate_pct}%` : '—' },
  ];

  const outletCols: Column<any>[] = [
    { key: 'outlet_name', header: 'Outlet', render: (r: any) => r.outlet_name ?? '—' },
    { key: 'pitches', header: 'Pitches', render: (r: any) => r.pitches ?? 0 },
    { key: 'published_count', header: 'Published', render: (r: any) => r.published_count ?? 0 },
    { key: 'in_review_count', header: 'In Review', render: (r: any) => r.in_review_count ?? 0 },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-8 p-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">Press Outreach Tracker</h1>
        <p className="text-sm text-gray-600">
          Track media outlets pitched and their outcomes. Monitor reply rate, in-review pipeline, and published stories.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Response Rate Summary</h2>
        <p className="text-xs text-gray-500">
          Reply rate is responded divided by total pitches. Aim for response rate &gt;= 20%.
        </p>
        <DataTable
          rows={summaryRow ? [summaryRow] : []}
          columns={summaryCols}
          rowKey={(r: any, i: number) => String(i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Top Outlets</h2>
        <p className="text-xs text-gray-500">
          Outlets ranked by number of pitches sent. Published &gt; in-review &gt; passed &gt; no-response.
        </p>
        <DataTable
          rows={outlets}
          columns={outletCols}
          rowKey={(r: any, i: number) => String(r.outlet_name ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">All Pitches (latest 200)</h2>
        <p className="text-xs text-gray-500">
          Newest pitch first. Outcome cycles from no_response → in_review → published (or passed).
        </p>
        <DataTable
          rows={outreach}
          columns={outreachCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
