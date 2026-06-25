import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_records: number;
  total_breaches: number;
  critical_breaches: number;
  avg_uptime_pct: number;
  total_credits_inr: number;
  credits_at_risk: number;
};

type BreachRecord = {
  id: string;
  customer_name: string;
  equipment_label: string;
  equipment_category: string;
  measurement_month: string;
  uptime_pct: number;
  sla_target_pct: number;
  breach_severity: string;
  downtime_minutes: number;
  monthly_fee_rupees: number;
  credit_issued_rupees: number;
};

type CategorySummary = {
  equipment_category: string;
  record_count: number;
  avg_uptime: number;
  breach_count: number;
  total_credit: number;
};

type PendingAction = {
  id: string;
  customer_name: string;
  equipment_label: string;
  action_type: string;
  action_status: string;
  owner_name: string;
  due_date: string;
  notes: string;
};

type Offender = {
  customer_name: string;
  equipment_label: string;
  uptime_pct: number;
  sla_target_pct: number;
  gap_pct: number;
  breach_severity: string;
  credit_issued_inr: number;
};

type SeverityRow = {
  breach_severity: string;
  record_count: number;
  total_downtime: number;
  total_credit: number;
};

type ExposureRow = {
  customer_name: string;
  monthly_fee_inr: number;
  credit_issued_inr: number;
  effective_pct: number;
  status_flag: string;
};

function inr(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function pct(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return v.toFixed(2) + '%';
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, recordsRes, catRes, actionsRes, offendersRes, sevRes, expRes] = await Promise.all([
    supabase.rpc('founder_r2684_kpis'),
    supabase.rpc('founder_r2684_breach_records'),
    supabase.rpc('founder_r2684_category_summary'),
    supabase.rpc('founder_r2684_pending_actions'),
    supabase.rpc('founder_r2684_top_offenders'),
    supabase.rpc('founder_r2684_severity_distribution'),
    supabase.rpc('founder_r2684_credit_exposure'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_records: 0,
    total_breaches: 0,
    critical_breaches: 0,
    avg_uptime_pct: 0,
    total_credits_inr: 0,
    credits_at_risk: 0,
  }) as Kpi;

  const records: BreachRecord[] = (recordsRes.data ?? []) as BreachRecord[];
  const cats: CategorySummary[] = (catRes.data ?? []) as CategorySummary[];
  const actions: PendingAction[] = (actionsRes.data ?? []) as PendingAction[];
  const offenders: Offender[] = (offendersRes.data ?? []) as Offender[];
  const severity: SeverityRow[] = (sevRes.data ?? []) as SeverityRow[];
  const exposure: ExposureRow[] = (expRes.data ?? []) as ExposureRow[];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Customer Monthly Uptime SLA Breach & Credit Tracker</h1>
        <p className="text-sm text-gray-600">
          Equipment uptime vs SLA target, breach severity, credit issued & remediation actions (r2684).
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3">
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Records</div>
          <div className="text-xl font-semibold">{kpi.total_records}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Breaches</div>
          <div className="text-xl font-semibold">{kpi.total_breaches}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Critical</div>
          <div className="text-xl font-semibold text-red-600">{kpi.critical_breaches}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Avg Uptime</div>
          <div className="text-xl font-semibold">{pct(kpi.avg_uptime_pct)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Credits Issued</div>
          <div className="text-xl font-semibold">{inr(kpi.total_credits_inr)}</div>
        </div>
        <div className="border rounded p-3">
          <div className="text-xs text-gray-500">Exposure at Risk</div>
          <div className="text-xl font-semibold text-amber-600">{inr(kpi.credits_at_risk)}</div>
        </div>
      </div>

      <section>
        <h2 className="text-lg font-semibold mb-2">SLA Records (uptime &lt; target = breach)</h2>
        <DataTable
          rows={records}
          columns={[
            { key: 'customer_name', header: 'Customer', render: (r: BreachRecord) => r.customer_name },
            { key: 'equipment_label', header: 'Equipment', render: (r: BreachRecord) => r.equipment_label },
            { key: 'equipment_category', header: 'Category', render: (r: BreachRecord) => r.equipment_category },
            { key: 'measurement_month', header: 'Month', render: (r: BreachRecord) => r.measurement_month },
            { key: 'uptime_pct', header: 'Uptime', render: (r: BreachRecord) => pct(r.uptime_pct) },
            { key: 'sla_target_pct', header: 'SLA Target', render: (r: BreachRecord) => pct(r.sla_target_pct) },
            { key: 'breach_severity', header: 'Severity', render: (r: BreachRecord) => r.breach_severity },
            { key: 'downtime_minutes', header: 'Downtime (min)', render: (r: BreachRecord) => String(r.downtime_minutes) },
            { key: 'monthly_fee_rupees', header: 'Monthly Fee', render: (r: BreachRecord) => inr(r.monthly_fee_rupees) },
            { key: 'credit_issued_rupees', header: 'Credit', render: (r: BreachRecord) => inr(r.credit_issued_rupees) },
          ]}
          emptyMessage="No data"
          rowKey={(r: BreachRecord, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Equipment Category</h2>
        <DataTable
          rows={cats}
          columns={[
            { key: 'equipment_category', header: 'Category', render: (r: CategorySummary) => r.equipment_category },
            { key: 'record_count', header: 'Records', render: (r: CategorySummary) => String(r.record_count) },
            { key: 'avg_uptime', header: 'Avg Uptime', render: (r: CategorySummary) => pct(r.avg_uptime) },
            { key: 'breach_count', header: 'Breaches', render: (r: CategorySummary) => String(r.breach_count) },
            { key: 'total_credit', header: 'Total Credit', render: (r: CategorySummary) => inr(r.total_credit) },
          ]}
          emptyMessage="No data"
          rowKey={(r: CategorySummary, i: number) => String(r.equipment_category ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Top Offenders (largest SLA gap)</h2>
        <DataTable
          rows={offenders}
          columns={[
            { key: 'customer_name', header: 'Customer', render: (r: Offender) => r.customer_name },
            { key: 'equipment_label', header: 'Equipment', render: (r: Offender) => r.equipment_label },
            { key: 'uptime_pct', header: 'Uptime', render: (r: Offender) => pct(r.uptime_pct) },
            { key: 'sla_target_pct', header: 'Target', render: (r: Offender) => pct(r.sla_target_pct) },
            { key: 'gap_pct', header: 'Gap', render: (r: Offender) => pct(r.gap_pct) },
            { key: 'breach_severity', header: 'Severity', render: (r: Offender) => r.breach_severity },
            { key: 'credit_issued_inr', header: 'Credit', render: (r: Offender) => inr(r.credit_issued_inr) },
          ]}
          emptyMessage="No data"
          rowKey={(r: Offender, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severity Distribution</h2>
        <DataTable
          rows={severity}
          columns={[
            { key: 'breach_severity', header: 'Severity', render: (r: SeverityRow) => r.breach_severity },
            { key: 'record_count', header: 'Records', render: (r: SeverityRow) => String(r.record_count) },
            { key: 'total_downtime', header: 'Total Downtime (min)', render: (r: SeverityRow) => String(r.total_downtime) },
            { key: 'total_credit', header: 'Total Credit', render: (r: SeverityRow) => inr(r.total_credit) },
          ]}
          emptyMessage="No data"
          rowKey={(r: SeverityRow, i: number) => String(r.breach_severity ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Credit Exposure</h2>
        <DataTable
          rows={exposure}
          columns={[
            { key: 'customer_name', header: 'Customer', render: (r: ExposureRow) => r.customer_name },
            { key: 'monthly_fee_inr', header: 'Monthly Fee', render: (r: ExposureRow) => inr(r.monthly_fee_inr) },
            { key: 'credit_issued_inr', header: 'Credit Issued', render: (r: ExposureRow) => inr(r.credit_issued_inr) },
            { key: 'effective_pct', header: 'Effective %', render: (r: ExposureRow) => pct(r.effective_pct) },
            { key: 'status_flag', header: 'Status', render: (r: ExposureRow) => r.status_flag },
          ]}
          emptyMessage="No data"
          rowKey={(r: ExposureRow, i: number) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pending & In-Progress Actions</h2>
        <DataTable
          rows={actions}
          columns={[
            { key: 'customer_name', header: 'Customer', render: (r: PendingAction) => r.customer_name },
            { key: 'equipment_label', header: 'Equipment', render: (r: PendingAction) => r.equipment_label },
            { key: 'action_type', header: 'Action', render: (r: PendingAction) => r.action_type },
            { key: 'action_status', header: 'Status', render: (r: PendingAction) => r.action_status },
            { key: 'owner_name', header: 'Owner', render: (r: PendingAction) => r.owner_name },
            { key: 'due_date', header: 'Due', render: (r: PendingAction) => r.due_date },
            { key: 'notes', header: 'Notes', render: (r: PendingAction) => r.notes },
          ]}
          emptyMessage="No data"
          rowKey={(r: PendingAction, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
