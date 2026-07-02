import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_disclosures: number;
  pending_review: number;
  approved_count: number;
  rejected_count: number;
  critical_risk_count: number;
  total_external_hours: number;
  total_external_income_rupees: number;
  customer_overlap_count: number;
};

type DisclosureRow = {
  id: string;
  engineer_name: string;
  engineer_code: string;
  quarter: string;
  activity_type: string;
  weekly_hours: number;
  monthly_income_rupees: number;
  conflict_risk_score: number;
  conflict_risk_band: string;
  disclosure_status: string;
  approval_verdict: string | null;
  submitted_at: string;
};

type ActivityRow = {
  activity_type: string;
  count: number;
  avg_weekly_hours: number;
  avg_risk_score: number;
  total_income_rupees: number;
};

type RiskRow = {
  conflict_risk_band: string;
  count: number;
  approved_count: number;
  rejected_count: number;
  avg_hours: number;
};

type CriticalRow = {
  id: string;
  engineer_name: string;
  engineer_code: string;
  activity_type: string;
  activity_description: string;
  weekly_hours: number;
  conflict_risk_score: number;
  uses_equipseva_tools: boolean;
  serves_equipseva_clients: boolean;
  disclosure_status: string;
};

type AuditRow = {
  id: string;
  engineer_code: string;
  engineer_name: string;
  event_type: string;
  event_severity: string;
  actor: string;
  notes: string;
  occurred_at: string;
};

type QuarterRow = {
  quarter: string;
  total_disclosures: number;
  approved_count: number;
  rejected_count: number;
  conditional_count: number;
  pending_count: number;
  total_hours: number;
};

type VerdictRow = {
  approval_verdict: string;
  count: number;
  pct_of_total: number;
};

function fmtInr(v: number | null | undefined): string {
  if (v === null || v === undefined) return '-';
  return '₹' + Number(v).toLocaleString('en-IN');
}

function fmtDate(v: string | null | undefined): string {
  if (!v) return '-';
  try {
    return new Date(v).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return v;
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, listRes, byActivityRes, byRiskRes, criticalRes, auditRes, quarterRes, verdictRes] = await Promise.all([
    supabase.rpc('founder_side_hustle_kpis_r2742'),
    supabase.rpc('founder_side_hustle_list_r2742'),
    supabase.rpc('founder_side_hustle_by_activity_r2742'),
    supabase.rpc('founder_side_hustle_by_risk_r2742'),
    supabase.rpc('founder_side_hustle_critical_r2742'),
    supabase.rpc('founder_side_hustle_audit_timeline_r2742'),
    supabase.rpc('founder_side_hustle_quarter_rollup_r2742'),
    supabase.rpc('founder_side_hustle_verdict_breakdown_r2742'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? {
    total_disclosures: 0,
    pending_review: 0,
    approved_count: 0,
    rejected_count: 0,
    critical_risk_count: 0,
    total_external_hours: 0,
    total_external_income_rupees: 0,
    customer_overlap_count: 0,
  }) as Kpi;

  const disclosures: DisclosureRow[] = (listRes.data ?? []) as DisclosureRow[];
  const byActivity: ActivityRow[] = (byActivityRes.data ?? []) as ActivityRow[];
  const byRisk: RiskRow[] = (byRiskRes.data ?? []) as RiskRow[];
  const critical: CriticalRow[] = (criticalRes.data ?? []) as CriticalRow[];
  const audit: AuditRow[] = (auditRes.data ?? []) as AuditRow[];
  const quarter: QuarterRow[] = (quarterRes.data ?? []) as QuarterRow[];
  const verdict: VerdictRow[] = (verdictRes.data ?? []) as VerdictRow[];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Engineer Quarterly Side-Hustle Disclosure</h1>
        <p className="text-sm text-gray-600 mt-1">
          Engineer × side activity × hours × conflict risk × disclosure × approval verdict. Track external work, flag customer overlap (risk band &gt;= high), enforce time caps (&lt;= 10h/week).
        </p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-white rounded-lg shadow p-4">
          <div className="text-xs text-gray-500">Total Disclosures</div>
          <div className="text-2xl font-semibold">{kpi.total_disclosures}</div>
        </div>
        <div className="bg-white rounded-lg shadow p-4">
          <div className="text-xs text-gray-500">Pending Review</div>
          <div className="text-2xl font-semibold text-amber-600">{kpi.pending_review}</div>
        </div>
        <div className="bg-white rounded-lg shadow p-4">
          <div className="text-xs text-gray-500">Approved</div>
          <div className="text-2xl font-semibold text-emerald-600">{kpi.approved_count}</div>
        </div>
        <div className="bg-white rounded-lg shadow p-4">
          <div className="text-xs text-gray-500">Rejected</div>
          <div className="text-2xl font-semibold text-rose-600">{kpi.rejected_count}</div>
        </div>
        <div className="bg-white rounded-lg shadow p-4">
          <div className="text-xs text-gray-500">Critical Risk</div>
          <div className="text-2xl font-semibold text-rose-700">{kpi.critical_risk_count}</div>
        </div>
        <div className="bg-white rounded-lg shadow p-4">
          <div className="text-xs text-gray-500">Total External Hrs/Wk</div>
          <div className="text-2xl font-semibold">{Number(kpi.total_external_hours).toFixed(1)}</div>
        </div>
        <div className="bg-white rounded-lg shadow p-4">
          <div className="text-xs text-gray-500">External Income/Mo</div>
          <div className="text-2xl font-semibold">{fmtInr(kpi.total_external_income_rupees)}</div>
        </div>
        <div className="bg-white rounded-lg shadow p-4">
          <div className="text-xs text-gray-500">Customer Overlap</div>
          <div className="text-2xl font-semibold text-rose-600">{kpi.customer_overlap_count}</div>
        </div>
      </div>

      <section className="bg-white rounded-lg shadow p-4">
        <h2 className="text-lg font-semibold mb-3">All Disclosures</h2>
        <DataTable
          rows={disclosures}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: DisclosureRow) => (
              <div>
                <div className="font-medium">{r.engineer_name}</div>
                <div className="text-xs text-gray-500">{r.engineer_code}</div>
              </div>
            ) },
            { key: 'quarter', header: 'Quarter', render: (r: DisclosureRow) => <span>{r.quarter}</span> },
            { key: 'activity_type', header: 'Activity', render: (r: DisclosureRow) => <span className="text-sm">{r.activity_type}</span> },
            { key: 'weekly_hours', header: 'Hrs/Wk', render: (r: DisclosureRow) => <span>{Number(r.weekly_hours).toFixed(1)}</span> },
            { key: 'monthly_income_rupees', header: 'Income/Mo', render: (r: DisclosureRow) => <span>{fmtInr(r.monthly_income_rupees)}</span> },
            { key: 'conflict_risk_score', header: 'Risk', render: (r: DisclosureRow) => (
              <span className={
                r.conflict_risk_band === 'critical' ? 'text-rose-700 font-semibold' :
                r.conflict_risk_band === 'high' ? 'text-rose-600' :
                r.conflict_risk_band === 'medium' ? 'text-amber-600' : 'text-emerald-600'
              }>
                {Number(r.conflict_risk_score).toFixed(2)} ({r.conflict_risk_band})
              </span>
            ) },
            { key: 'disclosure_status', header: 'Status', render: (r: DisclosureRow) => <span className="text-sm">{r.disclosure_status}</span> },
            { key: 'approval_verdict', header: 'Verdict', render: (r: DisclosureRow) => <span className="text-xs">{r.approval_verdict ?? 'pending'}</span> },
            { key: 'submitted_at', header: 'Submitted', render: (r: DisclosureRow) => <span className="text-xs">{fmtDate(r.submitted_at)}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: DisclosureRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <section className="bg-white rounded-lg shadow p-4">
          <h2 className="text-lg font-semibold mb-3">By Activity Type</h2>
          <DataTable
            rows={byActivity}
            columns={[
              { key: 'activity_type', header: 'Activity', render: (r: ActivityRow) => <span>{r.activity_type}</span> },
              { key: 'count', header: 'Count', render: (r: ActivityRow) => <span>{r.count}</span> },
              { key: 'avg_weekly_hours', header: 'Avg Hrs/Wk', render: (r: ActivityRow) => <span>{Number(r.avg_weekly_hours).toFixed(2)}</span> },
              { key: 'avg_risk_score', header: 'Avg Risk', render: (r: ActivityRow) => <span>{Number(r.avg_risk_score).toFixed(2)}</span> },
              { key: 'total_income_rupees', header: 'Total Income', render: (r: ActivityRow) => <span>{fmtInr(r.total_income_rupees)}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: ActivityRow, i: number) => String(r.activity_type ?? i)}
          />
        </section>

        <section className="bg-white rounded-lg shadow p-4">
          <h2 className="text-lg font-semibold mb-3">By Risk Band</h2>
          <DataTable
            rows={byRisk}
            columns={[
              { key: 'conflict_risk_band', header: 'Band', render: (r: RiskRow) => <span>{r.conflict_risk_band}</span> },
              { key: 'count', header: 'Count', render: (r: RiskRow) => <span>{r.count}</span> },
              { key: 'approved_count', header: 'Approved', render: (r: RiskRow) => <span className="text-emerald-600">{r.approved_count}</span> },
              { key: 'rejected_count', header: 'Rejected', render: (r: RiskRow) => <span className="text-rose-600">{r.rejected_count}</span> },
              { key: 'avg_hours', header: 'Avg Hrs', render: (r: RiskRow) => <span>{Number(r.avg_hours).toFixed(2)}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: RiskRow, i: number) => String(r.conflict_risk_band ?? i)}
          />
        </section>
      </div>

      <section className="bg-white rounded-lg shadow p-4">
        <h2 className="text-lg font-semibold mb-3">Critical Conflicts (band &gt;= high OR serves EquipSeva clients)</h2>
        <DataTable
          rows={critical}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: CriticalRow) => (
              <div>
                <div className="font-medium">{r.engineer_name}</div>
                <div className="text-xs text-gray-500">{r.engineer_code}</div>
              </div>
            ) },
            { key: 'activity_type', header: 'Activity', render: (r: CriticalRow) => <span>{r.activity_type}</span> },
            { key: 'activity_description', header: 'Description', render: (r: CriticalRow) => <span className="text-sm">{r.activity_description}</span> },
            { key: 'weekly_hours', header: 'Hrs/Wk', render: (r: CriticalRow) => <span>{Number(r.weekly_hours).toFixed(1)}</span> },
            { key: 'conflict_risk_score', header: 'Score', render: (r: CriticalRow) => <span className="font-semibold text-rose-700">{Number(r.conflict_risk_score).toFixed(2)}</span> },
            { key: 'uses_equipseva_tools', header: 'Uses Tools', render: (r: CriticalRow) => <span>{r.uses_equipseva_tools ? 'YES' : 'no'}</span> },
            { key: 'serves_equipseva_clients', header: 'Serves Clients', render: (r: CriticalRow) => <span className={r.serves_equipseva_clients ? 'text-rose-700 font-semibold' : ''}>{r.serves_equipseva_clients ? 'YES' : 'no'}</span> },
            { key: 'disclosure_status', header: 'Status', render: (r: CriticalRow) => <span>{r.disclosure_status}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: CriticalRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <section className="bg-white rounded-lg shadow p-4">
          <h2 className="text-lg font-semibold mb-3">Quarter Rollup</h2>
          <DataTable
            rows={quarter}
            columns={[
              { key: 'quarter', header: 'Quarter', render: (r: QuarterRow) => <span>{r.quarter}</span> },
              { key: 'total_disclosures', header: 'Total', render: (r: QuarterRow) => <span>{r.total_disclosures}</span> },
              { key: 'approved_count', header: 'Approved', render: (r: QuarterRow) => <span className="text-emerald-600">{r.approved_count}</span> },
              { key: 'rejected_count', header: 'Rejected', render: (r: QuarterRow) => <span className="text-rose-600">{r.rejected_count}</span> },
              { key: 'conditional_count', header: 'Conditional', render: (r: QuarterRow) => <span className="text-amber-600">{r.conditional_count}</span> },
              { key: 'pending_count', header: 'Pending', render: (r: QuarterRow) => <span>{r.pending_count}</span> },
              { key: 'total_hours', header: 'Total Hrs/Wk', render: (r: QuarterRow) => <span>{Number(r.total_hours).toFixed(1)}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: QuarterRow, i: number) => String(r.quarter ?? i)}
          />
        </section>

        <section className="bg-white rounded-lg shadow p-4">
          <h2 className="text-lg font-semibold mb-3">Verdict Breakdown</h2>
          <DataTable
            rows={verdict}
            columns={[
              { key: 'approval_verdict', header: 'Verdict', render: (r: VerdictRow) => <span>{r.approval_verdict}</span> },
              { key: 'count', header: 'Count', render: (r: VerdictRow) => <span>{r.count}</span> },
              { key: 'pct_of_total', header: 'Share', render: (r: VerdictRow) => <span>{Number(r.pct_of_total).toFixed(1)}%</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: VerdictRow, i: number) => String(r.approval_verdict ?? i)}
          />
        </section>
      </div>

      <section className="bg-white rounded-lg shadow p-4">
        <h2 className="text-lg font-semibold mb-3">Audit Timeline (latest 50)</h2>
        <DataTable
          rows={audit}
          columns={[
            { key: 'occurred_at', header: 'When', render: (r: AuditRow) => <span className="text-xs">{fmtDate(r.occurred_at)}</span> },
            { key: 'engineer_code', header: 'Engineer', render: (r: AuditRow) => (
              <div>
                <div className="font-medium">{r.engineer_name}</div>
                <div className="text-xs text-gray-500">{r.engineer_code}</div>
              </div>
            ) },
            { key: 'event_type', header: 'Event', render: (r: AuditRow) => <span>{r.event_type}</span> },
            { key: 'event_severity', header: 'Severity', render: (r: AuditRow) => (
              <span className={
                r.event_severity === 'critical' ? 'text-rose-700 font-semibold' :
                r.event_severity === 'high' ? 'text-rose-600' :
                r.event_severity === 'warn' ? 'text-amber-600' : 'text-gray-700'
              }>
                {r.event_severity}
              </span>
            ) },
            { key: 'actor', header: 'Actor', render: (r: AuditRow) => <span className="text-sm">{r.actor}</span> },
            { key: 'notes', header: 'Notes', render: (r: AuditRow) => <span className="text-sm">{r.notes}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: AuditRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
