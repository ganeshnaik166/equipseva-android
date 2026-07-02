import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string | number };

async function safeRpc(sb: any, name: string, args?: any) {
  try {
    const { data, error } = await sb.rpc(name, args ?? {});
    if (error) return null;
    return data;
  } catch {
    return null;
  }
}

export default async function FounderInvestorIcpScorecardPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const kpisRaw = await safeRpc(sb, 'rpc_founder_icp_kpis');
  const top = (await safeRpc(sb, 'rpc_founder_icp_top_prospects', { p_limit: 25 })) ?? [];
  const breakdown = (await safeRpc(sb, 'rpc_founder_icp_score_breakdown')) ?? [];
  const stageDist = (await safeRpc(sb, 'rpc_founder_icp_stage_distribution')) ?? [];
  const pipeline = (await safeRpc(sb, 'rpc_founder_icp_pipeline_status')) ?? [];
  const uncontacted = (await safeRpc(sb, 'rpc_founder_icp_uncontacted_high_fit')) ?? [];
  const activity = (await safeRpc(sb, 'rpc_founder_icp_recent_activity')) ?? [];

  const k = kpisRaw ?? {};
  const kpis: Kpi[] = [
    { label: 'Total Profiles', value: k.total_profiles ?? 0 },
    { label: 'Scored', value: k.scored_count ?? 0 },
    { label: 'Avg Score', value: k.avg_score ?? 0 },
    { label: 'Top Score', value: k.top_score ?? 0 },
    { label: 'High-Fit (>=75)', value: k.high_fit_count ?? 0 },
    { label: 'Warm Intros', value: k.warm_intro_count ?? 0 },
    { label: 'Recent Health Invest', value: k.recent_health ?? 0 },
    { label: 'Meetings Booked', value: k.meetings ?? 0 },
    { label: 'In Diligence', value: k.in_diligence ?? 0 },
    { label: 'Term Sheets', value: k.term_sheets ?? 0 },
    { label: 'Passed', value: k.passed ?? 0 },
    { label: 'Contacted 30d', value: k.contacted_30d ?? 0 },
    { label: 'Seed Stage', value: k.stage_seed ?? 0 },
    { label: 'Series A Stage', value: k.stage_seriesa ?? 0 },
    { label: 'Check Size Match', value: k.target_check_match ?? 0 },
    { label: 'Uncontacted', value: k.uncontacted ?? 0 },
  ];

  const topCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? '—' },
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'composite_score', header: 'Score', render: (r: any) => r.composite_score ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'warm_intro', header: 'Warm', render: (r: any) => (r.warm_intro ? 'Yes' : 'No') },
    { key: 'partner_email', header: 'Partner', render: (r: any) => r.partner_email ?? '—' },
  ];

  const breakdownCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'stage_fit_score', header: 'Stage', render: (r: any) => r.stage_fit_score ?? '—' },
    { key: 'sector_fit_score', header: 'Sector', render: (r: any) => r.sector_fit_score ?? '—' },
    { key: 'geography_fit_score', header: 'Geo', render: (r: any) => r.geography_fit_score ?? '—' },
    { key: 'check_size_score', header: 'Check', render: (r: any) => r.check_size_score ?? '—' },
    { key: 'warm_intro_bonus', header: 'Warm Bonus', render: (r: any) => r.warm_intro_bonus ?? '—' },
    { key: 'composite_score', header: 'Composite', render: (r: any) => r.composite_score ?? '—' },
  ];

  const stageCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'prospect_count', header: 'Prospects', render: (r: any) => r.prospect_count ?? '—' },
    { key: 'avg_score', header: 'Avg Score', render: (r: any) => r.avg_score ?? '—' },
    { key: 'high_fit_count', header: 'High-Fit', render: (r: any) => r.high_fit_count ?? '—' },
  ];

  const pipelineCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'count_at_stage', header: 'Count', render: (r: any) => r.count_at_stage ?? '—' },
    { key: 'avg_fit_score', header: 'Avg Fit', render: (r: any) => r.avg_fit_score ?? '—' },
  ];

  const uncontactedCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '—' },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? '—' },
    { key: 'composite_score', header: 'Score', render: (r: any) => r.composite_score ?? '—' },
    { key: 'warm_intro', header: 'Warm', render: (r: any) => (r.warm_intro ? 'Yes' : 'No') },
    { key: 'partner_email', header: 'Partner', render: (r: any) => r.partner_email ?? '—' },
  ];

  return (
    <div style={{ padding: 24, fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Investor ICP Scorecard</h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Score prospects on stage, sector, geography, and check-size fit. Prioritize outreach by composite score.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((kpi) => (
          <div key={kpi.label} style={{ border: '1px solid #e5e5e5', borderRadius: 8, padding: 12 }}>
            <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase' }}>{kpi.label}</div>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 4 }}>{String(kpi.value)}</div>
          </div>
        ))}
      </div>

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Top Prospects</h2>
      <DataTable rows={top} columns={topCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Score Breakdown</h2>
      <DataTable rows={breakdown} columns={breakdownCols} rowKey={(r: any) => r.investor_id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Stage Distribution</h2>
      <DataTable rows={stageDist} columns={stageCols} rowKey={(r: any) => r.stage} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Pipeline Status</h2>
      <DataTable rows={pipeline} columns={pipelineCols} rowKey={(r: any) => r.status} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Uncontacted High-Fit</h2>
      <DataTable rows={uncontacted} columns={uncontactedCols} rowKey={(r: any) => r.investor_id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>Recent Activity</h2>
      <ul>
        {activity.map((a: any) => (
          <li key={a.investor_id} style={{ padding: '6px 0', borderBottom: '1px solid #f0f0f0' }}>
            <strong>{a.investor_name ?? '—'}</strong> · status {a.status ?? '—'} · score{' '}
            {a.composite_score ?? '—'} · {a.days_since_contact ?? '—'} days since contact
          </li>
        ))}
      </ul>
    </div>
  );
}
