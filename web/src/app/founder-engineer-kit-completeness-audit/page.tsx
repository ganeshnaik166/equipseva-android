import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type RequiredItem = {
  id: string;
  item_code: string;
  item_name: string;
  category: string;
  is_mandatory: boolean;
  replacement_cost_rupees: number;
  notes: string | null;
};

type Audit = {
  id: string;
  engineer_user_id: string;
  engineer_email: string | null;
  auditor_email: string | null;
  audited_at: string;
  location_city: string | null;
  audit_kind: string;
  missing_item_codes: string[];
  total_missing: number;
  replacement_cost_rupees: number;
  passed: boolean;
  recovered_from_payout: boolean;
  notes: string | null;
};

type Summary = {
  total_audits: number;
  passed_count: number;
  failed_count: number;
  pass_pct: number;
  total_missing_items: number;
  total_replacement_cost_rupees: number;
  recovered_cost_rupees: number;
  unrecovered_cost_rupees: number;
  last_audit_at: string | null;
};

type Offender = {
  engineer_user_id: string;
  engineer_email: string | null;
  audit_count: number;
  failed_count: number;
  total_missing: number;
  total_cost_rupees: number;
  recovered_cost_rupees: number;
  last_audit_at: string | null;
};

type MissingFreq = {
  item_code: string;
  item_name: string;
  category: string;
  miss_count: number;
  replacement_cost_rupees: number;
  total_cost_exposure_rupees: number;
};

type MonthRow = {
  month_start: string;
  audit_count: number;
  failed_count: number;
  total_missing: number;
  total_cost_rupees: number;
};

type KindRow = {
  audit_kind: string;
  audit_count: number;
  failed_count: number;
  fail_pct: number;
  total_cost_rupees: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [itemsRes, auditsRes, summaryRes, offendersRes, missingRes, monthRes, kindRes] = await Promise.all([
    sb.rpc('list_required_items_r2310'),
    sb.rpc('list_audits_r2310'),
    sb.rpc('audit_summary_r2310'),
    sb.rpc('engineer_offenders_r2310'),
    sb.rpc('missing_item_frequency_r2310'),
    sb.rpc('audits_by_month_r2310'),
    sb.rpc('audits_by_kind_r2310'),
  ]);

  const items: RequiredItem[] = (itemsRes.data ?? []) as RequiredItem[];
  const audits: Audit[] = (auditsRes.data ?? []) as Audit[];
  const summary: Summary = ((summaryRes.data ?? [])[0] ?? {
    total_audits: 0,
    passed_count: 0,
    failed_count: 0,
    pass_pct: 0,
    total_missing_items: 0,
    total_replacement_cost_rupees: 0,
    recovered_cost_rupees: 0,
    unrecovered_cost_rupees: 0,
    last_audit_at: null,
  }) as Summary;
  const offenders: Offender[] = (offendersRes.data ?? []) as Offender[];
  const missing: MissingFreq[] = (missingRes.data ?? []) as MissingFreq[];
  const months: MonthRow[] = (monthRes.data ?? []) as MonthRow[];
  const kinds: KindRow[] = (kindRes.data ?? []) as KindRow[];

  const itemCols: Column<RequiredItem>[] = [
    { key: 'code', header: 'Code', render: (r) => r.item_code },
    { key: 'name', header: 'Item', render: (r) => r.item_name },
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'mandatory', header: 'Mandatory', render: (r) => (r.is_mandatory ? 'yes' : 'no') },
    { key: 'cost', header: 'Replace Rs', render: (r) => `Rs ${r.replacement_cost_rupees}` },
  ];

  const auditCols: Column<Audit>[] = [
    { key: 'when', header: 'Audited', render: (r) => new Date(r.audited_at).toLocaleString() },
    { key: 'engineer', header: 'Engineer', render: (r) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'auditor', header: 'Auditor', render: (r) => r.auditor_email ?? '—' },
    { key: 'city', header: 'City', render: (r) => r.location_city ?? '—' },
    { key: 'kind', header: 'Kind', render: (r) => r.audit_kind },
    { key: 'missing', header: 'Missing', render: (r) => String(r.total_missing) },
    { key: 'cost', header: 'Cost Rs', render: (r) => `Rs ${r.replacement_cost_rupees}` },
    { key: 'passed', header: 'Result', render: (r) => (r.passed ? 'pass' : 'FAIL') },
    { key: 'recovered', header: 'Recovered', render: (r) => (r.recovered_from_payout ? 'yes' : 'no') },
  ];

  const offenderCols: Column<Offender>[] = [
    { key: 'engineer', header: 'Engineer', render: (r) => r.engineer_email ?? String(r.engineer_user_id).slice(0, 8) },
    { key: 'count', header: 'Audits', render: (r) => String(r.audit_count) },
    { key: 'failed', header: 'Failed', render: (r) => String(r.failed_count) },
    { key: 'missing', header: 'Missing items', render: (r) => String(r.total_missing) },
    { key: 'cost', header: 'Total Rs', render: (r) => `Rs ${r.total_cost_rupees}` },
    { key: 'recovered', header: 'Recovered Rs', render: (r) => `Rs ${r.recovered_cost_rupees}` },
    { key: 'last', header: 'Last audit', render: (r) => (r.last_audit_at ? new Date(r.last_audit_at).toLocaleDateString() : '—') },
  ];

  const missingCols: Column<MissingFreq>[] = [
    { key: 'code', header: 'Code', render: (r) => r.item_code },
    { key: 'name', header: 'Item', render: (r) => r.item_name },
    { key: 'category', header: 'Category', render: (r) => r.category },
    { key: 'misses', header: 'Times missed', render: (r) => String(r.miss_count) },
    { key: 'cost', header: 'Replace Rs', render: (r) => `Rs ${r.replacement_cost_rupees}` },
    { key: 'exposure', header: 'Total exposure Rs', render: (r) => `Rs ${r.total_cost_exposure_rupees}` },
  ];

  const monthCols: Column<MonthRow>[] = [
    { key: 'month', header: 'Month', render: (r) => new Date(r.month_start).toLocaleDateString() },
    { key: 'count', header: 'Audits', render: (r) => String(r.audit_count) },
    { key: 'failed', header: 'Failed', render: (r) => String(r.failed_count) },
    { key: 'missing', header: 'Missing', render: (r) => String(r.total_missing) },
    { key: 'cost', header: 'Cost Rs', render: (r) => `Rs ${r.total_cost_rupees}` },
  ];

  const kindCols: Column<KindRow>[] = [
    { key: 'kind', header: 'Audit kind', render: (r) => r.audit_kind },
    { key: 'count', header: 'Count', render: (r) => String(r.audit_count) },
    { key: 'failed', header: 'Failed', render: (r) => String(r.failed_count) },
    { key: 'pct', header: 'Fail %', render: (r) => `${r.fail_pct}%` },
    { key: 'cost', header: 'Cost Rs', render: (r) => `Rs ${r.total_cost_rupees}` },
  ];

  return (
    <main className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Kit-Completeness Audit</h1>
        <p className="text-sm text-gray-500">r2310 · random spot-checks of field engineer kits & replacement cost recovery</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Total audits</div>
          <div className="text-2xl font-semibold">{summary.total_audits}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Passed</div>
          <div className="text-2xl font-semibold text-green-600">{summary.passed_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Failed</div>
          <div className="text-2xl font-semibold text-red-600">{summary.failed_count}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Pass %</div>
          <div className="text-2xl font-semibold">{summary.pass_pct}%</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Missing items</div>
          <div className="text-2xl font-semibold">{summary.total_missing_items}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Replacement cost</div>
          <div className="text-2xl font-semibold">Rs {summary.total_replacement_cost_rupees}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Recovered</div>
          <div className="text-2xl font-semibold text-green-600">Rs {summary.recovered_cost_rupees}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs uppercase text-gray-500">Unrecovered</div>
          <div className="text-2xl font-semibold text-red-600">Rs {summary.unrecovered_cost_rupees}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Required kit catalog</h2>
        <DataTable rows={items} columns={itemCols} rowKey={(r, i) => String(r.id ?? i)} emptyMessage="No required items defined." />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audit log</h2>
        <DataTable rows={audits} columns={auditCols} rowKey={(r, i) => String(r.id ?? i)} emptyMessage="No audits recorded yet." />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Chronic offenders</h2>
        <DataTable rows={offenders} columns={offenderCols} rowKey={(r, i) => String(r.engineer_user_id ?? i)} emptyMessage="No offenders — clean record." />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Most-missed items</h2>
        <DataTable rows={missing} columns={missingCols} rowKey={(r, i) => String(r.item_code ?? i)} emptyMessage="No misses logged." />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audits by month</h2>
        <DataTable rows={months} columns={monthCols} rowKey={(r, i) => String(r.month_start ?? i)} emptyMessage="No monthly data." />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Audits by kind</h2>
        <DataTable rows={kinds} columns={kindCols} rowKey={(r, i) => String(r.audit_kind ?? i)} emptyMessage="No kind breakdown." />
      </section>
    </main>
  );
}
