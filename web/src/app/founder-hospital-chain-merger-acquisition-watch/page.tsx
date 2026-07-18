import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

function formatDate(ts: string | null | undefined): string {
  if (!ts) return '—';
  const d = new Date(ts);
  return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function strengthPill(s: string): string {
  switch (s) {
    case 'confirmed': return 'bg-red-100 text-red-800';
    case 'strong': return 'bg-orange-100 text-orange-800';
    case 'moderate': return 'bg-yellow-100 text-yellow-800';
    case 'weak': return 'bg-gray-100 text-gray-700';
    default: return 'bg-gray-100 text-gray-700';
  }
}

function statusPill(s: string): string {
  switch (s) {
    case 'escalated': return 'bg-red-100 text-red-800';
    case 'monitoring': return 'bg-blue-100 text-blue-800';
    case 'open': return 'bg-yellow-100 text-yellow-800';
    case 'closed': return 'bg-gray-200 text-gray-700';
    case 'in_progress': return 'bg-blue-100 text-blue-800';
    case 'done': return 'bg-green-100 text-green-800';
    case 'dropped': return 'bg-gray-200 text-gray-700';
    default: return 'bg-gray-100 text-gray-700';
  }
}

function outcomePill(o: string): string {
  switch (o) {
    case 'positive': return 'bg-green-100 text-green-800';
    case 'neutral': return 'bg-gray-100 text-gray-700';
    case 'negative': return 'bg-red-100 text-red-800';
    case 'pending': return 'bg-yellow-100 text-yellow-800';
    default: return 'bg-gray-100 text-gray-700';
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [signalsRes, plansRes, focusRes, kindRes, topRes, trendRes, funnelRes] = await Promise.all([
    sb.rpc('list_ma_signals_r2531'),
    sb.rpc('list_renegotiation_plans_r2531'),
    sb.rpc('confirmed_signals_focus_r2531'),
    sb.rpc('signal_kind_breakdown_r2531'),
    sb.rpc('top_at_risk_chains_r2531'),
    sb.rpc('monthly_signal_trend_r2531'),
    sb.rpc('renegotiation_status_funnel_r2531'),
  ]);

  const signals: any[] = (signalsRes.data ?? []) as any[];
  const plans: any[] = (plansRes.data ?? []) as any[];
  const focus: any[] = (focusRes.data ?? []) as any[];
  const kinds: any[] = (kindRes.data ?? []) as any[];
  const topChains: any[] = (topRes.data ?? []) as any[];
  const trend: any[] = (trendRes.data ?? []) as any[];
  const funnel: any[] = (funnelRes.data ?? []) as any[];

  const totalSignals = signals.length;
  const confirmed = signals.filter((s: any) => s.signal_strength === 'confirmed').length;
  const escalated = signals.filter((s: any) => s.status === 'escalated').length;
  const openPlans = plans.filter((p: any) => p.status === 'open' || p.status === 'in_progress').length;

  const signalCols: Column<any>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => <span className="font-medium text-gray-900">{r.chain_name}</span> },
    { key: 'kind', header: 'Signal kind', render: (r: any) => <span className="text-sm">{r.signal_kind.replace(/_/g, ' ')}</span> },
    { key: 'strength', header: 'Strength', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${strengthPill(r.signal_strength)}`}>{r.signal_strength}</span>
    ) },
    { key: 'signal_at', header: 'Signal at', render: (r: any) => <span className="text-sm">{formatDate(r.signal_at)}</span> },
    { key: 'status', header: 'Status', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${statusPill(r.status)}`}>{r.status}</span>
    ) },
    { key: 'owner', header: 'Owner', render: (r: any) => <span className="text-xs text-gray-600">{r.owner_email ?? '—'}</span> },
    { key: 'source', header: 'Source', render: (r: any) => <span className="text-xs text-gray-600">{r.source ?? '—'}</span> },
    { key: 'notes', header: 'Notes', render: (r: any) => <span className="text-xs text-gray-700">{r.notes ?? '—'}</span> },
  ];

  const planCols: Column<any>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => <span className="font-medium text-gray-900">{r.chain_name}</span> },
    { key: 'kind', header: 'Renegotiation', render: (r: any) => <span className="text-sm">{r.renegotiation_kind.replace(/_/g, ' ')}</span> },
    { key: 'outcome_md', header: 'Expected outcome', render: (r: any) => <span className="text-xs text-gray-700">{r.expected_outcome_md ?? '—'}</span> },
    { key: 'due', header: 'Due', render: (r: any) => {
      const overdue = r.action_due_at && new Date(r.action_due_at) < new Date() && r.status !== 'done' && r.status !== 'dropped';
      return <span className={overdue ? 'text-red-700 font-semibold text-sm' : 'text-sm'}>{formatDate(r.action_due_at)}{overdue ? ' (overdue)' : ''}</span>;
    } },
    { key: 'status', header: 'Status', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${statusPill(r.status)}`}>{r.status.replace(/_/g, ' ')}</span>
    ) },
    { key: 'outcome', header: 'Outcome', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${outcomePill(r.outcome)}`}>{r.outcome}</span>
    ) },
    { key: 'owner', header: 'Owner', render: (r: any) => <span className="text-xs text-gray-600">{r.owner_email ?? '—'}</span> },
  ];

  const focusCols: Column<any>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => <span className="font-medium text-gray-900">{r.chain_name}</span> },
    { key: 'kind', header: 'Kind', render: (r: any) => <span className="text-sm">{r.signal_kind.replace(/_/g, ' ')}</span> },
    { key: 'strength', header: 'Strength', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${strengthPill(r.signal_strength)}`}>{r.signal_strength}</span>
    ) },
    { key: 'status', header: 'Status', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${statusPill(r.status)}`}>{r.status}</span>
    ) },
    { key: 'days', header: 'Days since', render: (r: any) => <span className="font-mono text-sm">{r.days_since_signal}d</span> },
    { key: 'owner', header: 'Owner', render: (r: any) => <span className="text-xs text-gray-600">{r.owner_email ?? '—'}</span> },
  ];

  const kindCols: Column<any>[] = [
    { key: 'kind', header: 'Signal kind', render: (r: any) => <span className="text-sm">{r.signal_kind.replace(/_/g, ' ')}</span> },
    { key: 'count', header: 'Total', render: (r: any) => <span className="font-mono text-sm">{r.signal_count}</span> },
    { key: 'strong', header: 'Strong/confirmed', render: (r: any) => <span className="font-mono text-sm text-red-700">{r.strong_or_confirmed}</span> },
    { key: 'open', header: 'Open/escalated', render: (r: any) => <span className="font-mono text-sm">{r.open_or_escalated}</span> },
  ];

  const topCols: Column<any>[] = [
    { key: 'chain', header: 'Chain', render: (r: any) => <span className="font-medium text-gray-900">{r.chain_name}</span> },
    { key: 'signals', header: 'Signals', render: (r: any) => <span className="font-mono text-sm">{r.signal_count}</span> },
    { key: 'strong', header: 'Strong/confirmed', render: (r: any) => <span className="font-mono text-sm text-red-700">{r.strong_or_confirmed}</span> },
    { key: 'reneg', header: 'Open renegs', render: (r: any) => <span className="font-mono text-sm">{r.open_renegotiations}</span> },
    { key: 'latest', header: 'Latest signal', render: (r: any) => <span className="text-sm">{formatDate(r.latest_signal_at)}</span> },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month', header: 'Month', render: (r: any) => <span className="font-mono text-sm">{r.month_label}</span> },
    { key: 'count', header: 'Signals', render: (r: any) => <span className="font-mono text-sm">{r.signal_count}</span> },
    { key: 'strong', header: 'Strong/confirmed', render: (r: any) => <span className="font-mono text-sm text-red-700">{r.strong_or_confirmed}</span> },
    { key: 'esc', header: 'Escalated', render: (r: any) => <span className="font-mono text-sm">{r.escalated_count}</span> },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => (
      <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${statusPill(r.status)}`}>{r.status.replace(/_/g, ' ')}</span>
    ) },
    { key: 'plans', header: 'Plans', render: (r: any) => <span className="font-mono text-sm">{r.plan_count}</span> },
    { key: 'pos', header: 'Positive', render: (r: any) => <span className="font-mono text-sm text-green-700">{r.positive_outcome}</span> },
    { key: 'neu', header: 'Neutral', render: (r: any) => <span className="font-mono text-sm">{r.neutral_outcome}</span> },
    { key: 'neg', header: 'Negative', render: (r: any) => <span className="font-mono text-sm text-red-700">{r.negative_outcome}</span> },
    { key: 'pend', header: 'Pending', render: (r: any) => <span className="font-mono text-sm text-yellow-700">{r.pending_outcome}</span> },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Hospital chain M&A watch</h1>
        <p className="text-sm text-gray-600 mt-1">
          Track IPO chatter, PE stakes, strategic acquirers, board & CFO changes across customer chains =&gt; trigger contract renegotiation before ownership flips.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Total signals</div>
          <div className="text-2xl font-bold text-gray-900 mt-1">{totalSignals}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Confirmed</div>
          <div className="text-2xl font-bold text-red-700 mt-1">{confirmed}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Escalated</div>
          <div className="text-2xl font-bold text-orange-700 mt-1">{escalated}</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Open renegotiations</div>
          <div className="text-2xl font-bold text-blue-700 mt-1">{openPlans}</div>
        </div>
      </section>

      <section className="bg-white border rounded-lg mb-8">
        <div className="px-4 py-3 border-b">
          <h2 className="font-semibold text-gray-900">All M&A signals</h2>
          <p className="text-xs text-gray-500 mt-0.5">Latest first. Strength weak =&lt; confirmed; status open =&gt; monitoring =&gt; escalated =&gt; closed.</p>
        </div>
        <DataTable<any>
          columns={signalCols}
          rows={signals}
          emptyMessage="No signals logged yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="bg-white border rounded-lg mb-8">
        <div className="px-4 py-3 border-b">
          <h2 className="font-semibold text-gray-900">Renegotiation plans</h2>
          <p className="text-xs text-gray-500 mt-0.5">Pre-ownership-change leverage actions =&gt; price lock, change-of-control, walkaway, expand scope.</p>
        </div>
        <DataTable<any>
          columns={planCols}
          rows={plans}
          emptyMessage="No renegotiation plans yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div className="bg-white border rounded-lg">
          <div className="px-4 py-3 border-b">
            <h2 className="font-semibold text-gray-900">Confirmed/strong open signals</h2>
            <p className="text-xs text-gray-500 mt-0.5">Aging queue =&gt; act before deal closes.</p>
          </div>
          <DataTable<any>
            columns={focusCols}
            rows={focus}
            emptyMessage="No high-strength open signals"
            rowKey={(r: any, i: number) => String(r.id ?? i)}
          />
        </div>
        <div className="bg-white border rounded-lg">
          <div className="px-4 py-3 border-b">
            <h2 className="font-semibold text-gray-900">Top at-risk chains</h2>
            <p className="text-xs text-gray-500 mt-0.5">Ranked by strong/confirmed signal volume.</p>
          </div>
          <DataTable<any>
            columns={topCols}
            rows={topChains}
            emptyMessage="No chains flagged"
            rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
          />
        </div>
      </section>

      <section className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <div className="bg-white border rounded-lg">
          <div className="px-4 py-3 border-b"><h2 className="font-semibold text-gray-900">Signal kind breakdown</h2></div>
          <DataTable<any>
            columns={kindCols}
            rows={kinds}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.signal_kind ?? i)}
          />
        </div>
        <div className="bg-white border rounded-lg">
          <div className="px-4 py-3 border-b"><h2 className="font-semibold text-gray-900">Monthly signal trend</h2></div>
          <DataTable<any>
            columns={trendCols}
            rows={trend}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.month_label ?? i)}
          />
        </div>
        <div className="bg-white border rounded-lg">
          <div className="px-4 py-3 border-b"><h2 className="font-semibold text-gray-900">Renegotiation status funnel</h2></div>
          <DataTable<any>
            columns={funnelCols}
            rows={funnel}
            emptyMessage="No data"
            rowKey={(r: any, i: number) => String(r.status ?? i)}
          />
        </div>
      </section>

      <section className="bg-white border rounded-lg p-4">
        <h3 className="font-semibold text-gray-900 mb-2">Playbook</h3>
        <ol className="text-sm text-gray-700 space-y-1 list-decimal pl-5">
          <li>Analyst logs signal (IPO chatter, PE stake, strategic acquirer, board/CFO change, divestment) with strength weak =&gt; confirmed.</li>
          <li>Founder reviews escalated rows =&gt; assigns owner for renegotiation plan.</li>
          <li>Choose action: contract review · price lock · ownership clause trigger · walkaway · scope expansion.</li>
          <li>Lock in pre-deal leverage before ownership transition removes our hand.</li>
          <li>Track outcome positive/neutral/negative once deal closes.</li>
        </ol>
      </section>
    </div>
  );
}
