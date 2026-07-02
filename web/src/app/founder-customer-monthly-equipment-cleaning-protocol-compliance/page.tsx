import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { metric: string; value: number; label: string };
type Protocol = {
  id: string;
  customer_org_name: string;
  equipment_code: string;
  equipment_category: string;
  protocol_code: string;
  required_frequency: string;
  adherence_pct: number;
  audit_score: number;
  risk_tier: string;
  compliance_state: string;
};
type Category = {
  equipment_category: string;
  protocols: number;
  avg_adherence: number;
  avg_audit: number;
  red_count: number;
};
type Gap = {
  id: string;
  equipment_code: string;
  customer_org_name: string;
  gap_type: string;
  severity: string;
  owner_role: string;
  due_date: string;
  status: string;
  reopened_count: number;
};
type OwnerLoad = {
  owner_role: string;
  open_count: number;
  overdue_count: number;
  avg_hours_to_close: number | null;
};
type Scorecard = {
  customer_org_name: string;
  protocols: number;
  avg_adherence: number;
  open_gaps: number;
  critical_gaps: number;
};
type Red = {
  customer_org_name: string;
  equipment_code: string;
  adherence_pct: number;
  audit_score: number;
  notes: string | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, protoRes, catRes, gapRes, ownerRes, scoreRes, redRes] = await Promise.all([
    supabase.rpc('founder_r2748_kpi_summary'),
    supabase.rpc('founder_r2748_protocols_list'),
    supabase.rpc('founder_r2748_category_breakdown'),
    supabase.rpc('founder_r2748_gap_list'),
    supabase.rpc('founder_r2748_owner_load'),
    supabase.rpc('founder_r2748_customer_scorecard'),
    supabase.rpc('founder_r2748_red_protocols'),
  ]);

  const kpis: Kpi[] = (kpiRes.data as Kpi[]) ?? [];
  const protocols: Protocol[] = (protoRes.data as Protocol[]) ?? [];
  const categories: Category[] = (catRes.data as Category[]) ?? [];
  const gaps: Gap[] = (gapRes.data as Gap[]) ?? [];
  const ownerLoad: OwnerLoad[] = (ownerRes.data as OwnerLoad[]) ?? [];
  const scorecards: Scorecard[] = (scoreRes.data as Scorecard[]) ?? [];
  const reds: Red[] = (redRes.data as Red[]) ?? [];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Monthly Equipment Cleaning Protocol Compliance</h1>
        <p className="text-sm text-gray-600 mt-1">
          Customer-level equipment cleaning adherence: protocol &amp; cycle audit, gap detection, owner load, close-action tracker. Red states flagged when adherence &lt; 80% or audit score &lt;= 70.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">KPIs</h2>
        <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
          {kpis.map((k) => (
            <div key={k.metric} className="rounded-lg border p-4 bg-white">
              <div className="text-xs uppercase text-gray-500">{k.label}</div>
              <div className="text-2xl font-bold mt-1">{Number(k.value).toLocaleString()}</div>
            </div>
          ))}
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Protocols (risk-sorted)</h2>
        <DataTable
          rows={protocols}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: Protocol) => r.customer_org_name },
            { key: 'equipment_code', header: 'Equipment', render: (r: Protocol) => r.equipment_code },
            { key: 'equipment_category', header: 'Category', render: (r: Protocol) => r.equipment_category },
            { key: 'protocol_code', header: 'Protocol', render: (r: Protocol) => r.protocol_code },
            { key: 'required_frequency', header: 'Freq', render: (r: Protocol) => r.required_frequency },
            { key: 'adherence_pct', header: 'Adherence %', render: (r: Protocol) => `${r.adherence_pct}%` },
            { key: 'audit_score', header: 'Audit', render: (r: Protocol) => String(r.audit_score) },
            { key: 'risk_tier', header: 'Risk', render: (r: Protocol) => r.risk_tier },
            { key: 'compliance_state', header: 'State', render: (r: Protocol) => r.compliance_state },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Category breakdown</h2>
        <DataTable
          rows={categories}
          columns={[
            { key: 'equipment_category', header: 'Category', render: (r: Category) => r.equipment_category },
            { key: 'protocols', header: 'Protocols', render: (r: Category) => String(r.protocols) },
            { key: 'avg_adherence', header: 'Avg adherence %', render: (r: Category) => `${r.avg_adherence}%` },
            { key: 'avg_audit', header: 'Avg audit', render: (r: Category) => String(r.avg_audit) },
            { key: 'red_count', header: 'Red protocols', render: (r: Category) => String(r.red_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.equipment_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Open gap actions</h2>
        <DataTable
          rows={gaps}
          columns={[
            { key: 'equipment_code', header: 'Equipment', render: (r: Gap) => r.equipment_code },
            { key: 'customer_org_name', header: 'Customer', render: (r: Gap) => r.customer_org_name },
            { key: 'gap_type', header: 'Gap', render: (r: Gap) => r.gap_type },
            { key: 'severity', header: 'Severity', render: (r: Gap) => r.severity },
            { key: 'owner_role', header: 'Owner', render: (r: Gap) => r.owner_role },
            { key: 'due_date', header: 'Due', render: (r: Gap) => r.due_date },
            { key: 'status', header: 'Status', render: (r: Gap) => r.status },
            { key: 'reopened_count', header: 'Reopened', render: (r: Gap) => String(r.reopened_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Owner load</h2>
        <DataTable
          rows={ownerLoad}
          columns={[
            { key: 'owner_role', header: 'Owner', render: (r: OwnerLoad) => r.owner_role },
            { key: 'open_count', header: 'Open', render: (r: OwnerLoad) => String(r.open_count) },
            { key: 'overdue_count', header: 'Overdue', render: (r: OwnerLoad) => String(r.overdue_count) },
            { key: 'avg_hours_to_close', header: 'Avg hrs to close', render: (r: OwnerLoad) => r.avg_hours_to_close == null ? '-' : String(r.avg_hours_to_close) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.owner_role ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Customer scorecard</h2>
        <DataTable
          rows={scorecards}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: Scorecard) => r.customer_org_name },
            { key: 'protocols', header: 'Protocols', render: (r: Scorecard) => String(r.protocols) },
            { key: 'avg_adherence', header: 'Avg adherence %', render: (r: Scorecard) => `${r.avg_adherence}%` },
            { key: 'open_gaps', header: 'Open gaps', render: (r: Scorecard) => String(r.open_gaps) },
            { key: 'critical_gaps', header: 'Critical gaps', render: (r: Scorecard) => String(r.critical_gaps) },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(r.customer_org_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Red/breach protocols</h2>
        <DataTable
          rows={reds}
          columns={[
            { key: 'customer_org_name', header: 'Customer', render: (r: Red) => r.customer_org_name },
            { key: 'equipment_code', header: 'Equipment', render: (r: Red) => r.equipment_code },
            { key: 'adherence_pct', header: 'Adherence %', render: (r: Red) => `${r.adherence_pct}%` },
            { key: 'audit_score', header: 'Audit', render: (r: Red) => String(r.audit_score) },
            { key: 'notes', header: 'Notes', render: (r: Red) => r.notes ?? '-' },
          ]}
          emptyMessage="No data"
          rowKey={(r, i) => String(`${r.customer_org_name}-${r.equipment_code}` ?? i)}
        />
      </section>
    </div>
  );
}
