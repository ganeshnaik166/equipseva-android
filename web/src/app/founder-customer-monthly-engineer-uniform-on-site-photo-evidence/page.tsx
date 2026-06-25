import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { total_captures: number; compliant: number; non_compliant: number; verified: number; open_actions: number; avg_score: number };
type Capture = { id: string; job_code: string; customer_org: string; engineer_name: string; capture_at: string; uniform_score: number; compliance_status: string; on_site: boolean; verified: boolean };
type Action = { id: string; job_code: string; issue_type: string; severity: string; action_taken: string; action_owner: string; status: string; created_at: string };
type ComplianceRow = { compliance_status: string; captures: number; avg_score: number };
type IssueRow = { issue_type: string; actions: number; open_actions: number };
type EngineerRow = { engineer_name: string; captures: number; avg_score: number; non_compliant_count: number };
type UnverifiedRow = { job_code: string; customer_org: string; engineer_name: string; uniform_score: number; compliance_status: string; capture_at: string };
type SeverityRow = { severity: string; actions: number; resolved: number };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, capturesRes, actionsRes, complianceRes, issuesRes, engineersRes, unverifiedRes, severityRes] = await Promise.all([
    supabase.rpc('r2736_kpi_summary'),
    supabase.rpc('r2736_list_captures'),
    supabase.rpc('r2736_list_actions'),
    supabase.rpc('r2736_compliance_breakdown'),
    supabase.rpc('r2736_issue_breakdown'),
    supabase.rpc('r2736_engineer_scores'),
    supabase.rpc('r2736_unverified_queue'),
    supabase.rpc('r2736_severity_breakdown'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] ?? { total_captures: 0, compliant: 0, non_compliant: 0, verified: 0, open_actions: 0, avg_score: 0 }) as Kpi;
  const captures: Capture[] = (capturesRes.data ?? []) as Capture[];
  const actions: Action[] = (actionsRes.data ?? []) as Action[];
  const compliance: ComplianceRow[] = (complianceRes.data ?? []) as ComplianceRow[];
  const issues: IssueRow[] = (issuesRes.data ?? []) as IssueRow[];
  const engineers: EngineerRow[] = (engineersRes.data ?? []) as EngineerRow[];
  const unverified: UnverifiedRow[] = (unverifiedRes.data ?? []) as UnverifiedRow[];
  const severity: SeverityRow[] = (severityRes.data ?? []) as SeverityRow[];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Monthly Engineer Uniform & On-Site Photo Evidence</h1>
        <p className="text-sm text-gray-600">Round r2736 — job × photo capture × compliance × issue × action × verified</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-6 gap-3">
        <div className="rounded-lg border p-3"><div className="text-xs text-gray-500">Total Captures</div><div className="text-xl font-semibold">{kpi.total_captures}</div></div>
        <div className="rounded-lg border p-3"><div className="text-xs text-gray-500">Compliant</div><div className="text-xl font-semibold">{kpi.compliant}</div></div>
        <div className="rounded-lg border p-3"><div className="text-xs text-gray-500">Non-Compliant</div><div className="text-xl font-semibold">{kpi.non_compliant}</div></div>
        <div className="rounded-lg border p-3"><div className="text-xs text-gray-500">Verified</div><div className="text-xl font-semibold">{kpi.verified}</div></div>
        <div className="rounded-lg border p-3"><div className="text-xs text-gray-500">Open Actions</div><div className="text-xl font-semibold">{kpi.open_actions}</div></div>
        <div className="rounded-lg border p-3"><div className="text-xs text-gray-500">Avg Score</div><div className="text-xl font-semibold">{kpi.avg_score}</div></div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Photo Captures</h2>
        <DataTable
          rows={captures}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: Capture) => <span>{r.job_code}</span> },
            { key: 'customer_org', header: 'Customer', render: (r: Capture) => <span>{r.customer_org}</span> },
            { key: 'engineer_name', header: 'Engineer', render: (r: Capture) => <span>{r.engineer_name}</span> },
            { key: 'capture_at', header: 'Captured', render: (r: Capture) => <span>{new Date(r.capture_at).toLocaleString()}</span> },
            { key: 'uniform_score', header: 'Score', render: (r: Capture) => <span>{r.uniform_score}</span> },
            { key: 'compliance_status', header: 'Status', render: (r: Capture) => <span>{r.compliance_status}</span> },
            { key: 'on_site', header: 'On-Site', render: (r: Capture) => <span>{r.on_site ? 'yes' : 'no'}</span> },
            { key: 'verified', header: 'Verified', render: (r: Capture) => <span>{r.verified ? 'yes' : 'no'}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Capture, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Compliance Actions</h2>
        <DataTable
          rows={actions}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: Action) => <span>{r.job_code}</span> },
            { key: 'issue_type', header: 'Issue', render: (r: Action) => <span>{r.issue_type}</span> },
            { key: 'severity', header: 'Severity', render: (r: Action) => <span>{r.severity}</span> },
            { key: 'action_taken', header: 'Action', render: (r: Action) => <span>{r.action_taken}</span> },
            { key: 'action_owner', header: 'Owner', render: (r: Action) => <span>{r.action_owner}</span> },
            { key: 'status', header: 'Status', render: (r: Action) => <span>{r.status}</span> },
            { key: 'created_at', header: 'Created', render: (r: Action) => <span>{new Date(r.created_at).toLocaleDateString()}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Action, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Compliance Breakdown</h2>
          <DataTable
            rows={compliance}
            columns={[
              { key: 'compliance_status', header: 'Status', render: (r: ComplianceRow) => <span>{r.compliance_status}</span> },
              { key: 'captures', header: 'Captures', render: (r: ComplianceRow) => <span>{r.captures}</span> },
              { key: 'avg_score', header: 'Avg Score', render: (r: ComplianceRow) => <span>{r.avg_score}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: ComplianceRow, i: number) => String(r.compliance_status ?? i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Issue Breakdown</h2>
          <DataTable
            rows={issues}
            columns={[
              { key: 'issue_type', header: 'Issue Type', render: (r: IssueRow) => <span>{r.issue_type}</span> },
              { key: 'actions', header: 'Actions', render: (r: IssueRow) => <span>{r.actions}</span> },
              { key: 'open_actions', header: 'Open', render: (r: IssueRow) => <span>{r.open_actions}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: IssueRow, i: number) => String(r.issue_type ?? i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Scores (lowest first)</h2>
        <DataTable
          rows={engineers}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: EngineerRow) => <span>{r.engineer_name}</span> },
            { key: 'captures', header: 'Captures', render: (r: EngineerRow) => <span>{r.captures}</span> },
            { key: 'avg_score', header: 'Avg Score', render: (r: EngineerRow) => <span>{r.avg_score}</span> },
            { key: 'non_compliant_count', header: 'Non-Compliant', render: (r: EngineerRow) => <span>{r.non_compliant_count}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRow, i: number) => String(r.engineer_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Unverified Queue</h2>
        <DataTable
          rows={unverified}
          columns={[
            { key: 'job_code', header: 'Job', render: (r: UnverifiedRow) => <span>{r.job_code}</span> },
            { key: 'customer_org', header: 'Customer', render: (r: UnverifiedRow) => <span>{r.customer_org}</span> },
            { key: 'engineer_name', header: 'Engineer', render: (r: UnverifiedRow) => <span>{r.engineer_name}</span> },
            { key: 'uniform_score', header: 'Score', render: (r: UnverifiedRow) => <span>{r.uniform_score}</span> },
            { key: 'compliance_status', header: 'Status', render: (r: UnverifiedRow) => <span>{r.compliance_status}</span> },
            { key: 'capture_at', header: 'Captured', render: (r: UnverifiedRow) => <span>{new Date(r.capture_at).toLocaleString()}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: UnverifiedRow, i: number) => String(r.job_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Severity Breakdown</h2>
        <DataTable
          rows={severity}
          columns={[
            { key: 'severity', header: 'Severity', render: (r: SeverityRow) => <span>{r.severity}</span> },
            { key: 'actions', header: 'Actions', render: (r: SeverityRow) => <span>{r.actions}</span> },
            { key: 'resolved', header: 'Resolved', render: (r: SeverityRow) => <span>{r.resolved}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: SeverityRow, i: number) => String(r.severity ?? i)}
        />
      </section>
    </div>
  );
}