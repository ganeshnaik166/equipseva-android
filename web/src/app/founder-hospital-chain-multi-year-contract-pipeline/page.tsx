import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [contractsRes, progressRes, topValueRes, funnelRes, milestoneRes, trendRes, probRes] = await Promise.all([
    supabase.rpc('list_contracts_r2619'),
    supabase.rpc('list_progress_r2619'),
    supabase.rpc('top_value_focus_r2619'),
    supabase.rpc('status_funnel_r2619'),
    supabase.rpc('milestone_distribution_r2619'),
    supabase.rpc('monthly_pipeline_trend_r2619'),
    supabase.rpc('win_probability_summary_r2619'),
  ]);

  const contracts: any[] = contractsRes.data ?? [];
  const progress: any[] = progressRes.data ?? [];
  const topValue: any[] = topValueRes.data ?? [];
  const funnel: any[] = funnelRes.data ?? [];
  const milestone: any[] = milestoneRes.data ?? [];
  const trend: any[] = trendRes.data ?? [];
  const prob: any[] = probRes.data ?? [];

  const fmtDateTime = (s: string | null) => (s ? new Date(s).toLocaleString('en-IN') : '-');
  const fmtRupees = (n: number | null) => {
    if (n === null || n === undefined) return '-';
    const lakhs = n / 100000;
    if (lakhs >= 100) return `Rs ${(lakhs / 100).toFixed(2)} Cr`;
    return `Rs ${lakhs.toFixed(2)} L`;
  };

  const contractCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'contract_term_years', header: 'Term (yrs)', render: (r: any) => r.contract_term_years },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'escalator_pct', header: 'Escalator %', render: (r: any) => `${r.escalator_pct}%` },
    { key: 'win_probability_pct', header: 'Win %', render: (r: any) => `${r.win_probability_pct}%` },
    { key: 'weighted_value_rupees', header: 'Weighted', render: (r: any) => fmtRupees(r.weighted_value_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const progressCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'progress_at', header: 'When', render: (r: any) => fmtDateTime(r.progress_at) },
    { key: 'milestone_kind', header: 'Milestone', render: (r: any) => r.milestone_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topValueCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'total_value_rupees', header: 'Total', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'win_probability_pct', header: 'Win %', render: (r: any) => `${r.win_probability_pct}%` },
    { key: 'weighted_value_rupees', header: 'Weighted', render: (r: any) => fmtRupees(r.weighted_value_rupees) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'total', header: 'Count', render: (r: any) => r.total },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'weighted_value_rupees', header: 'Weighted', render: (r: any) => fmtRupees(r.weighted_value_rupees) },
  ];

  const milestoneCols: Column<any>[] = [
    { key: 'milestone_kind', header: 'Milestone', render: (r: any) => r.milestone_kind },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'pending_count', header: 'Pending', render: (r: any) => r.pending_count },
  ];

  const trendCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'contracts_added', header: 'Added', render: (r: any) => r.contracts_added },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'weighted_value_rupees', header: 'Weighted', render: (r: any) => fmtRupees(r.weighted_value_rupees) },
  ];

  const probCols: Column<any>[] = [
    { key: 'probability_band', header: 'Band', render: (r: any) => r.probability_band },
    { key: 'total', header: 'Count', render: (r: any) => r.total },
    { key: 'total_value_rupees', header: 'Total Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'weighted_value_rupees', header: 'Weighted', render: (r: any) => fmtRupees(r.weighted_value_rupees) },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Hospital Chain Multi-Year Contract Pipeline</h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Track 2-5 year chain AMC deals =&gt; lock-in clauses, escalators, win probability, weighted pipeline.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top weighted value focus</h2>
        <DataTable
          rows={topValue}
          columns={topValueCols}
          emptyMessage="No active pipeline contracts."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All multi-year contracts</h2>
        <DataTable
          rows={contracts}
          columns={contractCols}
          emptyMessage="No contracts yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Progress milestones</h2>
        <DataTable
          rows={progress}
          columns={progressCols}
          emptyMessage="No progress logged."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status funnel</h2>
        <DataTable
          rows={funnel}
          columns={funnelCols}
          emptyMessage="No funnel data."
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Win probability bands</h2>
        <DataTable
          rows={prob}
          columns={probCols}
          emptyMessage="No probability data."
          rowKey={(r: any, i: number) => String(r.probability_band ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Milestone distribution</h2>
        <DataTable
          rows={milestone}
          columns={milestoneCols}
          emptyMessage="No milestones yet."
          rowKey={(r: any, i: number) => String(r.milestone_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Monthly pipeline trend</h2>
        <DataTable
          rows={trend}
          columns={trendCols}
          emptyMessage="No trend data."
          rowKey={(r: any, i: number) => String(r.month_label ?? i)}
        />
      </section>
    </div>
  );
}
