import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [issuesRes, actionsRes, chainsRes, rootCauseRes, arrRiskRes, trendRes, calendarRes] =
    await Promise.all([
      supabase.rpc('list_issues_r2463'),
      supabase.rpc('list_kill_actions_r2463'),
      supabase.rpc('top_recurring_by_chain_r2463'),
      supabase.rpc('root_cause_breakdown_r2463'),
      supabase.rpc('top_arr_at_risk_r2463'),
      supabase.rpc('monthly_hit_trend_r2463'),
      supabase.rpc('this_week_action_calendar_r2463'),
    ]);

  const issues = (issuesRes.data ?? []) as any[];
  const actions = (actionsRes.data ?? []) as any[];
  const chains = (chainsRes.data ?? []) as any[];
  const rootCause = (rootCauseRes.data ?? []) as any[];
  const arrRisk = (arrRiskRes.data ?? []) as any[];
  const trend = (trendRes.data ?? []) as any[];
  const calendar = (calendarRes.data ?? []) as any[];

  const fmtRupees = (n: number | null | undefined) =>
    n == null ? '-' : `Rs ${Number(n).toLocaleString('en-IN')}`;
  const fmtDate = (s: string | null | undefined) =>
    s ? new Date(s).toLocaleString('en-IN') : '-';

  const issueCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'issue_signature', header: 'Signature', render: (r: any) => r.issue_signature },
    { key: 'issue_kind', header: 'Kind', render: (r: any) => r.issue_kind },
    { key: 'hit_count', header: 'Hits', render: (r: any) => r.hit_count },
    { key: 'last_hit_at', header: 'Last Hit', render: (r: any) => fmtDate(r.last_hit_at) },
    { key: 'root_cause_kind', header: 'Root Cause', render: (r: any) => r.root_cause_kind ?? '-' },
    { key: 'arr_risk_rupees', header: 'ARR Risk', render: (r: any) => fmtRupees(r.arr_risk_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const actionCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'action_summary', header: 'Summary', render: (r: any) => r.action_summary },
    { key: 'action_at', header: 'Acted', render: (r: any) => fmtDate(r.action_at) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => fmtDate(r.follow_up_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'open_issues', header: 'Open Issues', render: (r: any) => r.open_issues },
    { key: 'total_hits', header: 'Total Hits', render: (r: any) => r.total_hits },
    { key: 'total_arr_risk_rupees', header: 'ARR Risk', render: (r: any) => fmtRupees(r.total_arr_risk_rupees) },
  ];

  const rootCauseCols: Column<any>[] = [
    { key: 'root_cause_kind', header: 'Root Cause', render: (r: any) => r.root_cause_kind },
    { key: 'issue_count', header: 'Issues', render: (r: any) => r.issue_count },
    { key: 'total_hits', header: 'Hits', render: (r: any) => r.total_hits },
    { key: 'arr_risk_rupees', header: 'ARR Risk', render: (r: any) => fmtRupees(r.arr_risk_rupees) },
  ];

  const arrRiskCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'issue_signature', header: 'Signature', render: (r: any) => r.issue_signature },
    { key: 'hit_count', header: 'Hits', render: (r: any) => r.hit_count },
    { key: 'arr_risk_rupees', header: 'ARR Risk', render: (r: any) => fmtRupees(r.arr_risk_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'last_hit_at', header: 'Last Hit', render: (r: any) => fmtDate(r.last_hit_at) },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_start', header: 'Month', render: (r: any) => fmtDate(r.month_start) },
    { key: 'issues_opened', header: 'Opened', render: (r: any) => r.issues_opened },
    { key: 'total_hits', header: 'Hits', render: (r: any) => r.total_hits },
    { key: 'arr_risk_rupees', header: 'ARR Risk', render: (r: any) => fmtRupees(r.arr_risk_rupees) },
  ];

  const calCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'action_summary', header: 'Summary', render: (r: any) => r.action_summary },
    { key: 'follow_up_at', header: 'Follow-up', render: (r: any) => fmtDate(r.follow_up_at) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  return (
    <main style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Chain Recurring Issue Tracker</h1>
        <p style={{ color: '#666' }}>r2463 — chain & recurring issue & hit count & root cause & kill action & ARR risk</p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top ARR at Risk</h2>
        <DataTable
          rows={arrRisk}
          columns={arrRiskCols}
          emptyMessage="No open issues at risk."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>This Week Action Calendar</h2>
        <DataTable
          rows={calendar}
          columns={calCols}
          emptyMessage="No follow-ups due this week."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top Recurring by Chain</h2>
        <DataTable
          rows={chains}
          columns={chainCols}
          emptyMessage="No chains tracked yet."
          rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Root Cause Breakdown</h2>
        <DataTable
          rows={rootCause}
          columns={rootCauseCols}
          emptyMessage="No root cause data."
          rowKey={(r: any, i: number) => String(r.root_cause_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly Hit Trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_start ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Recurring Issues</h2>
        <DataTable
          rows={issues}
          columns={issueCols}
          emptyMessage="No recurring issues logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All Kill Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No kill actions logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
