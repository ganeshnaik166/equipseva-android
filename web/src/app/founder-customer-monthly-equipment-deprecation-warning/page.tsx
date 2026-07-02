import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_warnings: number;
  critical_count: number;
  high_count: number;
  ack_rate_pct: number;
  replacement_capex_lakhs: number;
  avg_age_years: number;
};

type CriticalRow = {
  id: string;
  hospital_name: string;
  equipment_model: string;
  install_age_years: number;
  spares_availability_pct: number;
  replacement_capex_lakhs: number;
  decision: string;
  customer_acknowledged: boolean;
};

type CategoryRow = {
  equipment_category: string;
  units: number;
  avg_age: number;
  avg_spares_pct: number;
  total_capex_lakhs: number;
};

type EolRow = {
  manufacturer_eol_status: string;
  units: number;
  avg_failure_rate: number;
  avg_lead_time_days: number;
};

type DecisionRow = {
  decision: string;
  units: number;
  capex_lakhs: number;
};

type ActionRow = {
  id: string;
  hospital_name: string;
  equipment_model: string;
  action_taken: string;
  owner: string;
  due_date: string;
  outcome: string;
};

type WindowRow = {
  window_bucket: string;
  units: number;
  capex_lakhs: number;
};

type UnackRow = {
  id: string;
  hospital_name: string;
  equipment_model: string;
  risk_band: string;
  warning_sent_at: string | null;
  days_since_sent: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, critRes, catRes, eolRes, decRes, actRes, winRes, unackRes] = await Promise.all([
    supabase.rpc('r2692_kpi_summary'),
    supabase.rpc('r2692_critical_warnings'),
    supabase.rpc('r2692_by_category'),
    supabase.rpc('r2692_eol_status_breakdown'),
    supabase.rpc('r2692_decision_funnel'),
    supabase.rpc('r2692_action_pipeline'),
    supabase.rpc('r2692_replacement_window'),
    supabase.rpc('r2692_unacknowledged_warnings'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_warnings: 0,
    critical_count: 0,
    high_count: 0,
    ack_rate_pct: 0,
    replacement_capex_lakhs: 0,
    avg_age_years: 0,
  };
  const critical: CriticalRow[] = (critRes.data as CriticalRow[]) ?? [];
  const categories: CategoryRow[] = (catRes.data as CategoryRow[]) ?? [];
  const eol: EolRow[] = (eolRes.data as EolRow[]) ?? [];
  const decisions: DecisionRow[] = (decRes.data as DecisionRow[]) ?? [];
  const actions: ActionRow[] = (actRes.data as ActionRow[]) ?? [];
  const windowBuckets: WindowRow[] = (winRes.data as WindowRow[]) ?? [];
  const unack: UnackRow[] = (unackRes.data as UnackRow[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Customer Monthly Equipment Deprecation Warning</h1>
        <p className="text-sm text-gray-600">
          Round r2692 — equipment age, spares risk, replacement window, decision & action tracker
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <KpiCard label="Total warnings" value={String(kpi.total_warnings)} />
        <KpiCard label="Critical" value={String(kpi.critical_count)} tone="red" />
        <KpiCard label="High" value={String(kpi.high_count)} tone="orange" />
        <KpiCard label="Ack rate %" value={`${kpi.ack_rate_pct}%`} />
        <KpiCard label="Capex (L)" value={`Rs ${kpi.replacement_capex_lakhs}L`} />
        <KpiCard label="Avg age (yrs)" value={String(kpi.avg_age_years)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Critical & High Warnings</h2>
        <DataTable
          rows={critical}
          columns={[
            { key: 'hospital_name', header: 'Hospital', render: (r: CriticalRow) => r.hospital_name },
            { key: 'equipment_model', header: 'Model', render: (r: CriticalRow) => r.equipment_model },
            { key: 'install_age_years', header: 'Age (yrs)', render: (r: CriticalRow) => String(r.install_age_years) },
            { key: 'spares_availability_pct', header: 'Spares %', render: (r: CriticalRow) => `${r.spares_availability_pct}%` },
            { key: 'replacement_capex_lakhs', header: 'Capex (L)', render: (r: CriticalRow) => `Rs ${r.replacement_capex_lakhs}L` },
            { key: 'decision', header: 'Decision', render: (r: CriticalRow) => r.decision },
            { key: 'customer_acknowledged', header: 'Ack', render: (r: CriticalRow) => (r.customer_acknowledged ? 'yes' : 'no') },
          ]}
          emptyMessage="No data"
          rowKey={(r: CriticalRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Equipment Category</h2>
        <DataTable
          rows={categories}
          columns={[
            { key: 'equipment_category', header: 'Category', render: (r: CategoryRow) => r.equipment_category },
            { key: 'units', header: 'Units', render: (r: CategoryRow) => String(r.units) },
            { key: 'avg_age', header: 'Avg age (yrs)', render: (r: CategoryRow) => String(r.avg_age) },
            { key: 'avg_spares_pct', header: 'Avg spares %', render: (r: CategoryRow) => `${r.avg_spares_pct}%` },
            { key: 'total_capex_lakhs', header: 'Capex (L)', render: (r: CategoryRow) => `Rs ${r.total_capex_lakhs}L` },
          ]}
          emptyMessage="No data"
          rowKey={(r: CategoryRow, i: number) => String(r.equipment_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Manufacturer EOL Status</h2>
        <DataTable
          rows={eol}
          columns={[
            { key: 'manufacturer_eol_status', header: 'EOL status', render: (r: EolRow) => r.manufacturer_eol_status },
            { key: 'units', header: 'Units', render: (r: EolRow) => String(r.units) },
            { key: 'avg_failure_rate', header: 'Avg failure/mo', render: (r: EolRow) => String(r.avg_failure_rate) },
            { key: 'avg_lead_time_days', header: 'Avg lead (days)', render: (r: EolRow) => String(r.avg_lead_time_days) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EolRow, i: number) => String(r.manufacturer_eol_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Decision Funnel</h2>
        <DataTable
          rows={decisions}
          columns={[
            { key: 'decision', header: 'Decision', render: (r: DecisionRow) => r.decision },
            { key: 'units', header: 'Units', render: (r: DecisionRow) => String(r.units) },
            { key: 'capex_lakhs', header: 'Capex (L)', render: (r: DecisionRow) => `Rs ${r.capex_lakhs}L` },
          ]}
          emptyMessage="No data"
          rowKey={(r: DecisionRow, i: number) => String(r.decision ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Replacement Window Buckets</h2>
        <DataTable
          rows={windowBuckets}
          columns={[
            { key: 'window_bucket', header: 'Window', render: (r: WindowRow) => r.window_bucket },
            { key: 'units', header: 'Units', render: (r: WindowRow) => String(r.units) },
            { key: 'capex_lakhs', header: 'Capex (L)', render: (r: WindowRow) => `Rs ${r.capex_lakhs}L` },
          ]}
          emptyMessage="No data"
          rowKey={(r: WindowRow, i: number) => String(r.window_bucket ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Action Pipeline</h2>
        <DataTable
          rows={actions}
          columns={[
            { key: 'hospital_name', header: 'Hospital', render: (r: ActionRow) => r.hospital_name },
            { key: 'equipment_model', header: 'Model', render: (r: ActionRow) => r.equipment_model },
            { key: 'action_taken', header: 'Action', render: (r: ActionRow) => r.action_taken },
            { key: 'owner', header: 'Owner', render: (r: ActionRow) => r.owner },
            { key: 'due_date', header: 'Due', render: (r: ActionRow) => r.due_date },
            { key: 'outcome', header: 'Outcome', render: (r: ActionRow) => r.outcome },
          ]}
          emptyMessage="No data"
          rowKey={(r: ActionRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Unacknowledged Warnings (chase list)</h2>
        <DataTable
          rows={unack}
          columns={[
            { key: 'hospital_name', header: 'Hospital', render: (r: UnackRow) => r.hospital_name },
            { key: 'equipment_model', header: 'Model', render: (r: UnackRow) => r.equipment_model },
            { key: 'risk_band', header: 'Risk', render: (r: UnackRow) => r.risk_band },
            { key: 'warning_sent_at', header: 'Sent at', render: (r: UnackRow) => (r.warning_sent_at ? new Date(r.warning_sent_at).toLocaleString() : '-') },
            { key: 'days_since_sent', header: 'Days since', render: (r: UnackRow) => String(r.days_since_sent) },
          ]}
          emptyMessage="No data"
          rowKey={(r: UnackRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function KpiCard({ label, value, tone }: { label: string; value: string; tone?: 'red' | 'orange' }) {
  const toneClass = tone === 'red' ? 'border-red-300 bg-red-50' : tone === 'orange' ? 'border-orange-300 bg-orange-50' : 'border-gray-200 bg-white';
  return (
    <div className={`border rounded p-3 ${toneClass}`}>
      <div className="text-xs uppercase text-gray-500">{label}</div>
      <div className="text-xl font-semibold">{value}</div>
    </div>
  );
}
