import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any): string {
  if (n === null || n === undefined) return '—';
  const x = Number(n);
  if (Number.isNaN(x)) return '—';
  return x.toLocaleString('en-IN');
}

function fmtPct(n: any): string {
  if (n === null || n === undefined) return '—';
  return `${Number(n).toFixed(2)}%`;
}

function fmtDate(s: any): string {
  if (!s) return '—';
  try { return new Date(s).toLocaleString('en-IN'); } catch { return '—'; }
}

export default async function FounderHospitalChainExpansionPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = null;
  let chains: any[] = [];
  let targets: any[] = [];
  let touches: any[] = [];
  let templates: any[] = [];
  let funnel: any[] = [];

  try {
    const r = await sb.rpc('founder_chain_expansion_kpis');
    kpis = (r.data && r.data[0]) ? r.data[0] : null;
  } catch { kpis = null; }

  try {
    const r = await sb.rpc('founder_chain_expansion_active_chains');
    chains = (r.data ?? []) as any[];
  } catch { chains = []; }

  try {
    const r = await sb.rpc('founder_chain_expansion_targets_list');
    targets = (r.data ?? []) as any[];
  } catch { targets = []; }

  try {
    const r = await sb.rpc('founder_chain_expansion_recent_touches');
    touches = (r.data ?? []) as any[];
  } catch { touches = []; }

  try {
    const r = await sb.rpc('founder_chain_expansion_template_performance');
    templates = (r.data ?? []) as any[];
  } catch { templates = []; }

  try {
    const r = await sb.rpc('founder_chain_expansion_funnel');
    funnel = (r.data ?? []) as any[];
  } catch { funnel = []; }

  const cards: Kpi[] = [
    { label: 'Total Targets', value: fmtNum(kpis?.total_targets) },
    { label: 'Active Chains', value: fmtNum(kpis?.active_chains) },
    { label: 'Identified', value: fmtNum(kpis?.identified) },
    { label: 'Contacted', value: fmtNum(kpis?.contacted) },
    { label: 'Meeting Scheduled', value: fmtNum(kpis?.meeting_scheduled) },
    { label: 'Demo Done', value: fmtNum(kpis?.demo_done) },
    { label: 'Negotiating', value: fmtNum(kpis?.negotiating) },
    { label: 'Won', value: fmtNum(kpis?.won) },
    { label: 'Lost', value: fmtNum(kpis?.lost) },
    { label: 'Dormant', value: fmtNum(kpis?.dormant) },
    { label: 'Total Touches', value: fmtNum(kpis?.total_touches) },
    { label: 'Positive Touches', value: fmtNum(kpis?.positive_touches) },
    { label: 'Reply Rate', value: fmtPct(kpis?.reply_rate_pct) },
    { label: 'Conversion Rate', value: fmtPct(kpis?.conversion_rate_pct) },
    { label: 'Avg Days to Convert', value: fmtNum(kpis?.avg_days_to_convert) },
    { label: 'Overdue Touches', value: fmtNum(kpis?.overdue_touches) },
  ];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '—' },
    { key: 'anchor_hospital', header: 'Anchor', render: (r: any) => r.anchor_hospital ?? '—' },
    { key: 'total_locations', header: 'Locations', render: (r: any) => fmtNum(r.total_locations) },
    { key: 'identified', header: 'Identified', render: (r: any) => fmtNum(r.identified) },
    { key: 'won', header: 'Won', render: (r: any) => fmtNum(r.won) },
    { key: 'last_activity', header: 'Last Activity', render: (r: any) => fmtDate(r.last_activity) },
  ];

  const targetCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '—' },
    { key: 'target_hospital_name', header: 'Hospital', render: (r: any) => r.target_hospital_name ?? '—' },
    { key: 'target_city', header: 'City', render: (r: any) => r.target_city ?? '—' },
    { key: 'target_state', header: 'State', render: (r: any) => r.target_state ?? '—' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
    { key: 'current_step', header: 'Step', render: (r: any) => fmtNum(r.current_step) },
    { key: 'last_touch_at', header: 'Last Touch', render: (r: any) => fmtDate(r.last_touch_at) },
    { key: 'next_touch_due', header: 'Next Touch', render: (r: any) => fmtDate(r.next_touch_due) },
    { key: 'overdue', header: 'Overdue', render: (r: any) => r.overdue ? 'YES' : 'no' },
  ];

  const touchCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name ?? '—' },
    { key: 'target_hospital_name', header: 'Hospital', render: (r: any) => r.target_hospital_name ?? '—' },
    { key: 'step_number', header: 'Step', render: (r: any) => fmtNum(r.step_number) },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
    { key: 'touched_at', header: 'When', render: (r: any) => fmtDate(r.touched_at) },
  ];

  const templateCols: Column<any>[] = [
    { key: 'template_used', header: 'Template', render: (r: any) => r.template_used ?? '—' },
    { key: 'sent_count', header: 'Sent', render: (r: any) => fmtNum(r.sent_count) },
    { key: 'reply_count', header: 'Replies', render: (r: any) => fmtNum(r.reply_count) },
    { key: 'positive_count', header: 'Positive', render: (r: any) => fmtNum(r.positive_count) },
    { key: 'reply_rate_pct', header: 'Reply Rate', render: (r: any) => fmtPct(r.reply_rate_pct) },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'stage', header: 'Stage', render: (r: any) => r.stage ?? '—' },
    { key: 'cnt', header: 'Count', render: (r: any) => fmtNum(r.cnt) },
    { key: 'pct_of_total', header: 'Pct of Total', render: (r: any) => fmtPct(r.pct_of_total) },
  ];

  return (
    <div style={{ padding: 24 }}>
      <h1 style={{ fontSize: 22, fontWeight: 700, marginBottom: 4 }}>Hospital Chain Expansion Playbook</h1>
      <p style={{ color: '#666', marginBottom: 16 }}>
        When one hospital in a chain becomes active, surface the other locations. Templated outreach sequence with success-rate tracking.
      </p>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        {cards.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fff' }}>
            <div style={{ fontSize: 11, color: '#6b7280', textTransform: 'uppercase' }}>{k.label}</div>
            <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </div>

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '16px 0 8px' }}>Active Chains</h2>
      <DataTable<any> rows={chains} columns={chainCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Expansion Targets</h2>
      <DataTable<any> rows={targets} columns={targetCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Recent Outreach Touches</h2>
      <DataTable<any> rows={touches} columns={touchCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Template Performance</h2>
      <DataTable<any> rows={templates} columns={templateCols} rowKey={(r: any) => r.id} />

      <h2 style={{ fontSize: 16, fontWeight: 600, margin: '24px 0 8px' }}>Funnel</h2>
      <DataTable<any> rows={funnel} columns={funnelCols} rowKey={(r: any) => r.id} />
    </div>
  );
}
