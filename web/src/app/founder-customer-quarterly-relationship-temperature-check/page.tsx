import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [temps, actions, coldFocus, dist, funnel, trend, ownerLoad] = await Promise.all([
    supabase.rpc('list_temperature_r2652'),
    supabase.rpc('list_intervention_actions_r2652'),
    supabase.rpc('top_cold_focus_r2652'),
    supabase.rpc('temperature_distribution_r2652'),
    supabase.rpc('status_funnel_r2652'),
    supabase.rpc('quarterly_temperature_trend_r2652'),
    supabase.rpc('owner_load_r2652'),
  ]);

  const tempRows = (temps.data as any[]) ?? [];
  const actionRows = (actions.data as any[]) ?? [];
  const coldRows = (coldFocus.data as any[]) ?? [];
  const distRows = (dist.data as any[]) ?? [];
  const funnelRows = (funnel.data as any[]) ?? [];
  const trendRows = (trend.data as any[]) ?? [];
  const ownerRows = (ownerLoad.data as any[]) ?? [];

  const tempCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'temperature_kind', header: 'Temp', render: (r: any) => r.temperature_kind },
    { key: 'top_signals_md', header: 'Top signals', render: (r: any) => r.top_signals_md ?? '' },
    { key: 'action_required', header: 'Action?', render: (r: any) => (r.action_required ? 'yes' : 'no') },
    { key: 'action_owner_email', header: 'Action owner', render: (r: any) => r.action_owner_email ?? '' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '' },
    { key: 'temperature_kind', header: 'Temp', render: (r: any) => r.temperature_kind ?? '' },
    { key: 'action_at', header: 'When', render: (r: any) => r.action_at },
    { key: 'action_kind', header: 'Kind', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '' },
  ];

  const coldCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'temperature_kind', header: 'Temp', render: (r: any) => r.temperature_kind },
    { key: 'top_signals_md', header: 'Signals', render: (r: any) => r.top_signals_md ?? '' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
  ];

  const distCols: Column<any>[] = [
    { key: 'temperature_kind', header: 'Temp', render: (r: any) => r.temperature_kind },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'action_required_count', header: 'Action required', render: (r: any) => r.action_required_count },
  ];

  const funnelCols: Column<any>[] = [
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
  ];

  const trendCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label },
    { key: 'temperature_kind', header: 'Temp', render: (r: any) => r.temperature_kind },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
  ];

  const ownerCols: Column<any>[] = [
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email },
    { key: 'total', header: 'Total', render: (r: any) => r.total },
    { key: 'open_actions', header: 'Open actions', render: (r: any) => r.open_actions },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 32 }}>
      <header>
        <h1 style={{ fontSize: 24, fontWeight: 700 }}>Customer Quarterly Relationship Temperature Check</h1>
        <p style={{ color: '#555', marginTop: 4 }}>
          Founder pulse on hospital relationships > cold & cool accounts get owner-assigned interventions.
        </p>
      </header>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Top cold & cool focus</h2>
        <DataTable
          rows={coldRows}
          columns={coldCols}
          emptyMessage="No cold or cool accounts in focus"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Temperature distribution</h2>
        <DataTable
          rows={distRows}
          columns={distCols}
          emptyMessage="No temperature data"
          rowKey={(r: any, i: number) => String(r.temperature_kind ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Status funnel</h2>
        <DataTable
          rows={funnelRows}
          columns={funnelCols}
          emptyMessage="No status data"
          rowKey={(r: any, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Quarterly trend</h2>
        <DataTable
          rows={trendRows}
          columns={trendCols}
          emptyMessage="No trend data"
          rowKey={(r: any, i: number) => `${r.quarter_label}-${r.temperature_kind}-${i}`}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Owner load</h2>
        <DataTable
          rows={ownerRows}
          columns={ownerCols}
          emptyMessage="No owner data"
          rowKey={(r: any, i: number) => String(r.owner_email ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>All temperature checks</h2>
        <DataTable
          rows={tempRows}
          columns={tempCols}
          emptyMessage="No temperature checks yet"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Intervention actions</h2>
        <DataTable
          rows={actionRows}
          columns={actionCols}
          emptyMessage="No interventions logged"
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
