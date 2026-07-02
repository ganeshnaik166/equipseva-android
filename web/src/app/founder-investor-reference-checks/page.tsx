import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

type Kpi = { label: string; value: string };

export const dynamic = 'force-dynamic';

export default async function FounderInvestorReferenceChecksPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpiRow: any = {};
  let prospects: any[] = [];
  let refs: any[] = [];
  let dims: any[] = [];
  let stages: any[] = [];
  let redFlags: any[] = [];
  let channels: any[] = [];

  try {
    const { data } = await sb.rpc('founder_investor_prospects_kpis');
    kpiRow = (data && data[0]) || {};
  } catch {
    kpiRow = {};
  }
  try {
    const { data } = await sb.rpc('founder_investor_prospects_list');
    prospects = data || [];
  } catch {
    prospects = [];
  }
  try {
    const { data } = await sb.rpc('founder_investor_references_recent');
    refs = data || [];
  } catch {
    refs = [];
  }
  try {
    const { data } = await sb.rpc('founder_investor_reference_dimensions');
    dims = data || [];
  } catch {
    dims = [];
  }
  try {
    const { data } = await sb.rpc('founder_investor_stage_breakdown');
    stages = data || [];
  } catch {
    stages = [];
  }
  try {
    const { data } = await sb.rpc('founder_investor_red_flags');
    redFlags = data || [];
  } catch {
    redFlags = [];
  }
  try {
    const { data } = await sb.rpc('founder_investor_channel_breakdown');
    channels = data || [];
  } catch {
    channels = [];
  }

  const kpis: Kpi[] = [
    { label: 'Total prospects', value: String(kpiRow.total_prospects ?? 0) },
    { label: 'Pending', value: String(kpiRow.pending_count ?? 0) },
    { label: 'Go', value: String(kpiRow.go_count ?? 0) },
    { label: 'No-go', value: String(kpiRow.no_go_count ?? 0) },
    { label: 'Parked', value: String(kpiRow.parked_count ?? 0) },
    { label: 'Total refs', value: String(kpiRow.total_refs ?? 0) },
    { label: 'Refs completed', value: String(kpiRow.refs_completed ?? 0) },
    { label: 'Avg refs / prospect', value: String(kpiRow.avg_refs_per_prospect ?? 0) },
    { label: 'Avg rating overall', value: String(kpiRow.avg_rating_overall ?? 0) },
    { label: 'Avg gut score', value: String(kpiRow.avg_gut_score ?? 0) },
    { label: 'Proposed total (lakhs)', value: String(kpiRow.total_proposed_lakhs ?? 0) },
    { label: 'Go-decision lakhs', value: String(kpiRow.go_proposed_lakhs ?? 0) },
    { label: 'Red-flag entries', value: String(redFlags.length) },
    { label: 'Dimensions tracked', value: String(dims.length) },
    { label: 'Channels used', value: String(channels.length) },
    { label: 'Stages covered', value: String(stages.length) },
  ];

  const prospectCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '-' },
    { key: 'firm_name', header: 'Firm', render: (r: any) => r.firm_name ?? '-' },
    { key: 'fund_stage', header: 'Stage', render: (r: any) => r.fund_stage ?? '-' },
    { key: 'proposed_ticket_lakhs', header: 'Ticket (L)', render: (r: any) => String(r.proposed_ticket_lakhs ?? 0) },
    { key: 'decision', header: 'Decision', render: (r: any) => r.decision ?? 'pending' },
    { key: 'refs_completed', header: 'Refs', render: (r: any) => String(r.refs_completed ?? 0) },
    { key: 'avg_rating', header: 'Avg rating', render: (r: any) => String(r.avg_rating ?? 0) },
    { key: 'founder_gut_score', header: 'Gut', render: (r: any) => String(r.founder_gut_score ?? '-') },
  ];

  const refCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '-' },
    { key: 'portfolio_founder_name', header: 'Portfolio founder', render: (r: any) => r.portfolio_founder_name ?? '-' },
    { key: 'portfolio_company', header: 'Company', render: (r: any) => r.portfolio_company ?? '-' },
    { key: 'contact_channel', header: 'Channel', render: (r: any) => r.contact_channel ?? '-' },
    { key: 'avg_rating', header: 'Avg', render: (r: any) => String(r.avg_rating ?? 0) },
    { key: 'red_flag_notes', header: 'Red flag', render: (r: any) => r.red_flag_notes ?? '-' },
  ];

  const dimCols: Column<any>[] = [
    { key: 'dimension', header: 'Dimension', render: (r: any) => r.dimension ?? '-' },
    { key: 'avg_rating', header: 'Avg rating', render: (r: any) => String(r.avg_rating ?? 0) },
    { key: 'samples', header: 'Samples', render: (r: any) => String(r.samples ?? 0) },
  ];

  const stageCols: Column<any>[] = [
    { key: 'fund_stage', header: 'Stage', render: (r: any) => r.fund_stage ?? '-' },
    { key: 'prospects', header: 'Prospects', render: (r: any) => String(r.prospects ?? 0) },
    { key: 'go_decisions', header: 'Go decisions', render: (r: any) => String(r.go_decisions ?? 0) },
    { key: 'avg_ticket_lakhs', header: 'Avg ticket (L)', render: (r: any) => String(r.avg_ticket_lakhs ?? 0) },
    { key: 'avg_rating', header: 'Avg rating', render: (r: any) => String(r.avg_rating ?? 0) },
  ];

  const redFlagCols: Column<any>[] = [
    { key: 'investor_name', header: 'Investor', render: (r: any) => r.investor_name ?? '-' },
    { key: 'portfolio_founder_name', header: 'Source founder', render: (r: any) => r.portfolio_founder_name ?? '-' },
    { key: 'red_flag_notes', header: 'Red flag', render: (r: any) => r.red_flag_notes ?? '-' },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Investor reference checks</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>Back-channel calls with portfolio founders. Per-investor 360 rating. Go / no-go.</p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
            <div style={{ color: '#6b7280', fontSize: 12 }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '16px 0 8px' }}>Investor prospects</h2>
      <DataTable rows={prospects} columns={prospectCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Recent reference calls</h2>
      <DataTable rows={refs} columns={refCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Rating dimensions</h2>
      <DataTable rows={dims} columns={dimCols} rowKey={(r: any) => r.dimension} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Stage breakdown</h2>
      <DataTable rows={stages} columns={stageCols} rowKey={(r: any) => r.fund_stage} />

      <h2 style={{ fontSize: 18, fontWeight: 600, margin: '24px 0 8px' }}>Red flags</h2>
      <DataTable rows={redFlags} columns={redFlagCols} rowKey={(r: any) => r.id} />
    </div>
  );
}
