import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderQuarterlyInvestorPortfolioCorrespondencePage() {
  const supabase = await getSupabaseServerClient();

  const [
    correspondenceRes,
    followUpsRes,
    stalledRes,
    commitmentRes,
    responseKindRes,
    trendRes,
    ownerLoadRes,
  ] = await Promise.all([
    supabase.rpc('list_correspondence_r2517'),
    supabase.rpc('list_follow_ups_r2517'),
    supabase.rpc('stalled_investors_focus_r2517'),
    supabase.rpc('commitment_distribution_r2517'),
    supabase.rpc('response_kind_summary_r2517'),
    supabase.rpc('quarterly_correspondence_trend_r2517'),
    supabase.rpc('owner_load_r2517'),
  ]);

  const correspondence = correspondenceRes.data ?? [];
  const followUps = followUpsRes.data ?? [];
  const stalled = stalledRes.data ?? [];
  const commitments = commitmentRes.data ?? [];
  const responseKinds = responseKindRes.data ?? [];
  const trend = trendRes.data ?? [];
  const ownerLoad = ownerLoadRes.data ?? [];

  const correspondenceCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? '—' },
    { key: 'update_sent_at', header: 'Update Sent', render: (r: any) => new Date(r.update_sent_at).toLocaleDateString() },
    { key: 'response_kind', header: 'Response', render: (r: any) => r.response_kind },
    { key: 'ask_text', header: 'Ask', render: (r: any) => r.ask_text ?? '—' },
    { key: 'commitment_kind', header: 'Commitment', render: (r: any) => r.commitment_kind },
    { key: 'commitment_realized', header: 'Realized', render: (r: any) => (r.commitment_realized ? 'yes' : 'no') },
    { key: 'stalled', header: 'Stalled', render: (r: any) => (r.stalled ? 'yes' : 'no') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'follow_up_count', header: 'Follow-ups', render: (r: any) => String(r.follow_up_count) },
  ];

  const followUpCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'follow_up_at', header: 'When', render: (r: any) => new Date(r.follow_up_at).toLocaleDateString() },
    { key: 'follow_up_kind', header: 'Kind', render: (r: any) => r.follow_up_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'next_step', header: 'Next Step', render: (r: any) => r.next_step ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const stalledCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? '—' },
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'days_since_update', header: 'Days Since', render: (r: any) => String(r.days_since_update) },
    { key: 'ask_text', header: 'Ask', render: (r: any) => r.ask_text ?? '—' },
    { key: 'open_follow_ups', header: 'Open Follow-ups', render: (r: any) => String(r.open_follow_ups) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
  ];

  const commitmentCols: Column<any>[] = [
    { key: 'commitment_kind', header: 'Kind', render: (r: any) => r.commitment_kind },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count) },
    { key: 'realized_count', header: 'Realized', render: (r: any) => String(r.realized_count) },
    { key: 'pending_count', header: 'Pending', render: (r: any) => String(r.pending_count) },
  ];

  const responseKindCols: Column<any>[] = [
    { key: 'response_kind', header: 'Response', render: (r: any) => r.response_kind },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count) },
    { key: 'stalled_count', header: 'Stalled', render: (r: any) => String(r.stalled_count) },
    { key: 'avg_response_hours', header: 'Avg Hours', render: (r: any) => (r.avg_response_hours == null ? '—' : String(r.avg_response_hours)) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'updates_sent', header: 'Updates Sent', render: (r: any) => String(r.updates_sent) },
    { key: 'responses_received', header: 'Responses', render: (r: any) => String(r.responses_received) },
    { key: 'positive_responses', header: 'Positive', render: (r: any) => String(r.positive_responses) },
    { key: 'stalled_count', header: 'Stalled', render: (r: any) => String(r.stalled_count) },
    { key: 'commitments_realized', header: 'Commits Realized', render: (r: any) => String(r.commitments_realized) },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'correspondence_count', header: 'Updates', render: (r: any) => String(r.correspondence_count) },
    { key: 'follow_up_count', header: 'Follow-ups', render: (r: any) => String(r.follow_up_count) },
    { key: 'open_follow_ups', header: 'Open', render: (r: any) => String(r.open_follow_ups) },
    { key: 'stalled_count', header: 'Stalled', render: (r: any) => String(r.stalled_count) },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Quarterly Investor Portfolio Correspondence</h1>
        <p className="text-sm text-gray-600">
          Track investor updates & responses across quarters — asks, commitments, follow-ups, and stalled signals.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Correspondence</h2>
        <DataTable
          rows={correspondence}
          columns={correspondenceCols}
          emptyMessage="No correspondence logged yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Stalled Investors — Focus List</h2>
        <DataTable
          rows={stalled}
          columns={stalledCols}
          emptyMessage="No stalled investors."
          rowKey={(r: any, i: number) => String(r.investor_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-ups</h2>
        <DataTable
          rows={followUps}
          columns={followUpCols}
          emptyMessage="No follow-ups recorded."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Commitment Distribution</h2>
        <DataTable
          rows={commitments}
          columns={commitmentCols}
          emptyMessage="No commitments tracked."
          rowKey={(r: any, i: number) => String(r.commitment_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Response Kind Summary</h2>
        <DataTable
          rows={responseKinds}
          columns={responseKindCols}
          emptyMessage="No responses to summarize."
          rowKey={(r: any, i: number) => String(r.response_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Quarterly Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No quarter trend data."
          rowKey={(r: any, i: number) => String(r.quarter_label ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Owner Load</h2>
        <DataTable
          rows={ownerLoad}
          columns={ownerCols}
          emptyMessage="No owner activity."
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>
    </main>
  );
}
