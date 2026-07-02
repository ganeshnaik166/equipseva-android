import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type InstallRow = {
  id: string;
  chain_name: string;
  equipment_label: string;
  equipment_kind: string;
  install_date: string | null;
  age_years: number;
  value_rupees: number;
  under_warranty: boolean;
  upsell_kind: string;
  upsell_pipeline_rupees: number;
  owner_email: string | null;
  status: string;
  notes: string | null;
};

type ActionRow = {
  id: string;
  install_id: string;
  chain_name: string;
  equipment_label: string;
  action_at: string;
  action_kind: string;
  outcome: string;
  owner_email: string | null;
  status: string;
  notes: string | null;
};

type TopRow = {
  chain_name: string;
  total_pipeline_rupees: number;
  install_count: number;
};

type KindRow = {
  equipment_kind: string;
  install_count: number;
  total_value_rupees: number;
  total_pipeline_rupees: number;
};

type WarrantyRow = {
  warranty_state: string;
  install_count: number;
  total_value_rupees: number;
  total_pipeline_rupees: number;
};

type MonthRow = {
  month_label: string;
  action_count: number;
  positive_count: number;
  negative_count: number;
};

type AgeRow = {
  age_bucket: string;
  install_count: number;
  total_value_rupees: number;
  total_pipeline_rupees: number;
};

function fmtRupees(n: number | null | undefined) {
  if (n == null) return '-';
  return '₹ ' + Number(n).toLocaleString('en-IN');
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [installsRes, actionsRes, topRes, kindRes, warrantyRes, monthRes, ageRes] = await Promise.all([
    sb.rpc('list_installed_base_r2575'),
    sb.rpc('list_upsell_actions_r2575'),
    sb.rpc('top_upsell_pipeline_r2575'),
    sb.rpc('equipment_kind_breakdown_r2575'),
    sb.rpc('under_warranty_summary_r2575'),
    sb.rpc('monthly_action_trend_r2575'),
    sb.rpc('age_distribution_r2575'),
  ]);

  const installs: InstallRow[] = (installsRes.data as InstallRow[] | null) ?? [];
  const actions: ActionRow[] = (actionsRes.data as ActionRow[] | null) ?? [];
  const top: TopRow[] = (topRes.data as TopRow[] | null) ?? [];
  const kinds: KindRow[] = (kindRes.data as KindRow[] | null) ?? [];
  const warranty: WarrantyRow[] = (warrantyRes.data as WarrantyRow[] | null) ?? [];
  const months: MonthRow[] = (monthRes.data as MonthRow[] | null) ?? [];
  const ages: AgeRow[] = (ageRes.data as AgeRow[] | null) ?? [];

  const totalPipeline = installs.reduce((s, r) => s + (Number(r.upsell_pipeline_rupees) || 0), 0);
  const totalValue = installs.reduce((s, r) => s + (Number(r.value_rupees) || 0), 0);
  const underWarrantyCount = installs.filter((r) => r.under_warranty).length;

  const installCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'install_date', header: 'Installed', render: (r: any) => r.install_date ?? '-' },
    { key: 'age_years', header: 'Age (y)', render: (r: any) => Number(r.age_years).toFixed(1) },
    { key: 'value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.value_rupees) },
    { key: 'under_warranty', header: 'Warranty', render: (r: any) => (r.under_warranty ? 'Yes' : 'No') },
    { key: 'upsell_kind', header: 'Upsell', render: (r: any) => r.upsell_kind },
    { key: 'upsell_pipeline_rupees', header: 'Pipeline', render: (r: any) => fmtRupees(r.upsell_pipeline_rupees) },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const actionCols: Column<any>[] = [
    { key: 'action_at', header: 'When', render: (r: any) => new Date(r.action_at).toLocaleString() },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'equipment_label', header: 'Equipment', render: (r: any) => r.equipment_label },
    { key: 'action_kind', header: 'Action', render: (r: any) => r.action_kind },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '-' },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? '-' },
  ];

  const topCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'install_count', header: 'Installs', render: (r: any) => r.install_count },
    { key: 'total_pipeline_rupees', header: 'Total Pipeline', render: (r: any) => fmtRupees(r.total_pipeline_rupees) },
  ];

  const kindCols: Column<any>[] = [
    { key: 'equipment_kind', header: 'Kind', render: (r: any) => r.equipment_kind },
    { key: 'install_count', header: 'Installs', render: (r: any) => r.install_count },
    { key: 'total_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'total_pipeline_rupees', header: 'Pipeline', render: (r: any) => fmtRupees(r.total_pipeline_rupees) },
  ];

  const warrantyCols: Column<any>[] = [
    { key: 'warranty_state', header: 'Warranty', render: (r: any) => r.warranty_state },
    { key: 'install_count', header: 'Installs', render: (r: any) => r.install_count },
    { key: 'total_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'total_pipeline_rupees', header: 'Pipeline', render: (r: any) => fmtRupees(r.total_pipeline_rupees) },
  ];

  const monthCols: Column<any>[] = [
    { key: 'month_label', header: 'Month', render: (r: any) => r.month_label },
    { key: 'action_count', header: 'Actions', render: (r: any) => r.action_count },
    { key: 'positive_count', header: 'Positive', render: (r: any) => r.positive_count },
    { key: 'negative_count', header: 'Negative', render: (r: any) => r.negative_count },
  ];

  const ageCols: Column<any>[] = [
    { key: 'age_bucket', header: 'Age Bucket', render: (r: any) => r.age_bucket },
    { key: 'install_count', header: 'Installs', render: (r: any) => r.install_count },
    { key: 'total_value_rupees', header: 'Value', render: (r: any) => fmtRupees(r.total_value_rupees) },
    { key: 'total_pipeline_rupees', header: 'Pipeline', render: (r: any) => fmtRupees(r.total_pipeline_rupees) },
  ];

  return (
    <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 600, margin: 0 }}>
          Hospital Chain Equipment — Installed-Base Inventory
        </h1>
        <p style={{ color: '#666', marginTop: 4 }}>
          Chain × equipment × install date × age × value × warranty × upsell pipeline
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(200px,1fr))', gap: 12 }}>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Installs</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{installs.length}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Total Value</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{fmtRupees(totalValue)}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Upsell Pipeline</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{fmtRupees(totalPipeline)}</div>
        </div>
        <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Under Warranty</div>
          <div style={{ fontSize: 22, fontWeight: 600 }}>{underWarrantyCount}</div>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>Installed Base</h2>
        <DataTable
          rows={installs}
          columns={installCols}
          emptyMessage="No installed base entries."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600 }}>Upsell Actions</h2>
        <DataTable
          rows={actions}
          columns={actionCols}
          emptyMessage="No upsell actions yet."
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit,minmax(360px,1fr))', gap: 24 }}>
        <div>
          <h2 style={{ fontSize: 16, fontWeight: 600 }}>Top Upsell Pipeline by Chain</h2>
          <DataTable
            rows={top}
            columns={topCols}
            emptyMessage="No pipeline data."
            rowKey={(r: any, i: number) => String(r.chain_name ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 16, fontWeight: 600 }}>Equipment Kind Breakdown</h2>
          <DataTable
            rows={kinds}
            columns={kindCols}
            emptyMessage="No equipment data."
            rowKey={(r: any, i: number) => String(r.equipment_kind ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 16, fontWeight: 600 }}>Under-Warranty Summary</h2>
          <DataTable
            rows={warranty}
            columns={warrantyCols}
            emptyMessage="No warranty data."
            rowKey={(r: any, i: number) => String(r.warranty_state ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 16, fontWeight: 600 }}>Monthly Action Trend</h2>
          <DataTable
            rows={months}
            columns={monthCols}
            emptyMessage="No action history."
            rowKey={(r: any, i: number) => String(r.month_label ?? i)}
          />
        </div>
        <div>
          <h2 style={{ fontSize: 16, fontWeight: 600 }}>Age Distribution</h2>
          <DataTable
            rows={ages}
            columns={ageCols}
            emptyMessage="No age data."
            rowKey={(r: any, i: number) => String(r.age_bucket ?? i)}
          />
        </div>
      </section>
    </div>
  );
}
