import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ChecklistRow = {
  id: string;
  chain_name: string;
  chain_code: string;
  vendor_tier: string;
  total_hospitals: number;
  annual_contract_value_rupees: number;
  overall_status: string;
  last_review_at: string | null;
  next_review_due_at: string | null;
  items_total: number;
  items_compliant: number;
  items_blocker: number;
  compliance_pct: number;
};

type KpiRow = {
  total_chains: number;
  compliant_chains: number;
  at_risk_chains: number;
  non_compliant_chains: number;
  overdue_reviews: number;
  total_acv_at_risk_rupees: number;
  open_blocker_items: number;
};

function formatRupees(n: number | null | undefined): string {
  if (!n || n <= 0) return '₹0';
  if (n >= 1_00_00_000) return '₹' + (n / 1_00_00_000).toFixed(2) + ' Cr';
  if (n >= 1_00_000) return '₹' + (n / 1_00_000).toFixed(2) + ' L';
  return '₹' + n.toLocaleString('en-IN');
}

function formatDate(ts: string | null): string {
  if (!ts) return '—';
  const d = new Date(ts);
  return d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' });
}

function statusPill(status: string): string {
  switch (status) {
    case 'compliant': return 'bg-green-100 text-green-800';
    case 'in_progress': return 'bg-blue-100 text-blue-800';
    case 'at_risk': return 'bg-yellow-100 text-yellow-800';
    case 'non_compliant': return 'bg-red-100 text-red-800';
    case 'suspended': return 'bg-gray-300 text-gray-900';
    default: return 'bg-gray-100 text-gray-700';
  }
}

function tierPill(tier: string): string {
  switch (tier) {
    case 'preferred': return 'bg-purple-100 text-purple-800';
    case 'tier_1': return 'bg-indigo-100 text-indigo-800';
    case 'tier_2': return 'bg-slate-100 text-slate-700';
    case 'probation': return 'bg-orange-100 text-orange-800';
    default: return 'bg-gray-100 text-gray-700';
  }
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [checklistsRes, kpiRes] = await Promise.all([
    sb.rpc('r2287_list_chain_checklists'),
    sb.rpc('r2287_compliance_kpi_summary'),
  ]);

  const checklists = (checklistsRes.data ?? []) as ChecklistRow[];
  const kpiArr = (kpiRes.data ?? []) as KpiRow[];
  const kpi: KpiRow = kpiArr[0] ?? {
    total_chains: 0,
    compliant_chains: 0,
    at_risk_chains: 0,
    non_compliant_chains: 0,
    overdue_reviews: 0,
    total_acv_at_risk_rupees: 0,
    open_blocker_items: 0,
  };

  const columns: Column<ChecklistRow>[] = [
    {
      key: 'chain',
      header: 'Chain',
      render: (r: ChecklistRow) => (
        <div>
          <div className="font-medium text-gray-900">{r.chain_name}</div>
          <div className="text-xs text-gray-500">{r.chain_code} · {r.total_hospitals} hospitals</div>
        </div>
      ),
    },
    {
      key: 'tier',
      header: 'Vendor tier',
      render: (r: ChecklistRow) => (
        <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${tierPill(r.vendor_tier)}`}>
          {r.vendor_tier}
        </span>
      ),
    },
    {
      key: 'acv',
      header: 'Annual ACV',
      render: (r: ChecklistRow) => (
        <span className="font-mono text-sm">{formatRupees(r.annual_contract_value_rupees)}</span>
      ),
    },
    {
      key: 'status',
      header: 'Overall',
      render: (r: ChecklistRow) => (
        <span className={`inline-block px-2 py-0.5 rounded text-xs font-medium ${statusPill(r.overall_status)}`}>
          {r.overall_status.replace('_', ' ')}
        </span>
      ),
    },
    {
      key: 'pct',
      header: 'Compliance %',
      render: (r: ChecklistRow) => {
        const pct = Number(r.compliance_pct ?? 0);
        const barColor = pct >= 95 ? 'bg-green-500' : pct >= 70 ? 'bg-blue-500' : pct >= 40 ? 'bg-yellow-500' : 'bg-red-500';
        return (
          <div className="min-w-[120px]">
            <div className="flex justify-between text-xs mb-1">
              <span>{pct.toFixed(1)}%</span>
              <span className="text-gray-500">{r.items_compliant}/{r.items_total}</span>
            </div>
            <div className="h-2 bg-gray-200 rounded">
              <div className={`h-2 rounded ${barColor}`} style={{ width: `${Math.min(100, pct)}%` }} />
            </div>
          </div>
        );
      },
    },
    {
      key: 'blockers',
      header: 'Open blockers',
      render: (r: ChecklistRow) => (
        <span className={r.items_blocker > 0 ? 'text-red-700 font-semibold' : 'text-gray-500'}>
          {r.items_blocker}
        </span>
      ),
    },
    {
      key: 'last_review',
      header: 'Last review',
      render: (r: ChecklistRow) => <span className="text-sm">{formatDate(r.last_review_at)}</span>,
    },
    {
      key: 'next_review',
      header: 'Next due',
      render: (r: ChecklistRow) => {
        const overdue = r.next_review_due_at && new Date(r.next_review_due_at) < new Date();
        return (
          <span className={overdue ? 'text-red-700 font-semibold' : 'text-sm'}>
            {formatDate(r.next_review_due_at)}
            {overdue ? ' (overdue)' : ''}
          </span>
        );
      },
    },
  ];

  return (
    <div className="p-6 max-w-7xl mx-auto">
      <header className="mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Hospital chain compliance checklist tracker</h1>
        <p className="text-sm text-gray-600 mt-1">
          Per-chain status of Equipseva's compliance against vendor terms — NABH, ISO 9001/13485, DPDP & HIPAA-equivalent, CDSCO, GST & MSME.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Total chains</div>
          <div className="text-2xl font-bold text-gray-900 mt-1">{kpi.total_chains}</div>
          <div className="text-xs text-green-700 mt-1">{kpi.compliant_chains} compliant</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">At risk</div>
          <div className="text-2xl font-bold text-yellow-700 mt-1">{kpi.at_risk_chains}</div>
          <div className="text-xs text-gray-500 mt-1">need remediation</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">Non-compliant</div>
          <div className="text-2xl font-bold text-red-700 mt-1">{kpi.non_compliant_chains}</div>
          <div className="text-xs text-gray-500 mt-1">{kpi.overdue_reviews} reviews overdue</div>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <div className="text-xs text-gray-500 uppercase tracking-wide">ACV at risk</div>
          <div className="text-2xl font-bold text-gray-900 mt-1">{formatRupees(kpi.total_acv_at_risk_rupees)}</div>
          <div className="text-xs text-gray-500 mt-1">{kpi.open_blocker_items} open blocker items</div>
        </div>
      </section>

      <section className="bg-white border rounded-lg">
        <div className="px-4 py-3 border-b">
          <h2 className="font-semibold text-gray-900">Chains & rollup</h2>
          <p className="text-xs text-gray-500 mt-0.5">
            Compliance % &gt;= 95% =&gt; compliant. Any non-compliant item or &lt; 70% =&gt; at risk. 3+ non-compliant or &lt; 40% =&gt; non-compliant.
          </p>
        </div>
        <DataTable
          columns={columns}
          rows={checklists}
          rowKey={(r: ChecklistRow) => r.id}
        />
      </section>

      <section className="mt-8 grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-white border rounded-lg p-4">
          <h3 className="font-semibold text-gray-900 mb-2">Standard families tracked</h3>
          <ul className="text-sm text-gray-700 space-y-1 list-disc pl-5">
            <li>NABH — National Accreditation Board for Hospitals</li>
            <li>ISO 9001 — quality management</li>
            <li>ISO 13485 — medical device quality systems</li>
            <li>DPDP — India Digital Personal Data Protection Act</li>
            <li>HIPAA-equivalent — demanded by international JV chains</li>
            <li>CDSCO — Central Drugs Standard Control Org. authorisations</li>
            <li>GST & MSME — tax / Udyam vendor registration</li>
          </ul>
        </div>
        <div className="bg-white border rounded-lg p-4">
          <h3 className="font-semibold text-gray-900 mb-2">Workflow</h3>
          <ol className="text-sm text-gray-700 space-y-1 list-decimal pl-5">
            <li>Upsert a chain checklist via r2287_upsert_chain_checklist.</li>
            <li>Add items per vendor-terms PDF via r2287_upsert_checklist_item.</li>
            <li>Mark items verified once evidence is attached.</li>
            <li>Recompute overall status — rollup feeds KPI cards above.</li>
            <li>Review cadence drives the "next due" column — overdue rows highlighted in red.</li>
          </ol>
        </div>
      </section>
    </div>
  );
}
