import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type RosterRow = {
  member_full_name: string;
  member_role: string;
  affiliation_org: string;
  seat_class: string;
  nda_status: string;
  conflict_declared: string;
  compensation_type: string;
  quarterly_retainer_rupees: number;
  equity_bps: number;
  is_active: boolean;
};

type AttendanceRow = {
  member_full_name: string;
  total_sessions: number;
  attended_full_count: number;
  attended_partial_count: number;
  written_notes_count: number;
  no_show_count: number;
  rescheduled_count: number;
  attendance_score_pct: number | string;
};

type NdaRow = {
  nda_status: string;
  member_count: number;
  active_count: number;
};

type PreReadRow = {
  session_quarter: string;
  total_sessions: number;
  delivered_on_time: number;
  delivered_late: number;
  delivered_partial: number;
  skipped: number;
  avg_lead_hours: number | string;
};

type FollowUpRow = {
  member_full_name: string;
  session_type: string;
  session_quarter: string;
  scheduled_on: string;
  decision_follow_up_status: string;
  decision_summary: string;
  action_items_count: number;
};

type ConflictRow = {
  conflict_declared: string;
  member_count: number;
  active_members: number;
  members_list: string | null;
};

type CompensationRow = {
  member_full_name: string;
  compensation_type: string;
  quarterly_retainer_rupees: number;
  equity_bps: number;
  total_paid_rupees: number;
  sessions_compensated: number;
};

type SessionTypeRow = {
  session_quarter: string;
  session_type: string;
  session_count: number;
  total_action_items: number;
  closed_count: number;
  in_progress_count: number;
};

type RiskRow = {
  member_full_name: string;
  affiliation_org: string;
  nda_status: string;
  conflict_declared: string;
  is_offboarded: boolean;
  risk_severity: string;
  risk_note: string;
};

function formatRupees(n: number | null | undefined): string {
  if (n == null) return '-';
  return 'Rs ' + n.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [roster, attendance, nda, preRead, followUp, conflicts, comp, sessionType, risk] = await Promise.all([
    supabase.rpc('founder_r3135_member_roster'),
    supabase.rpc('founder_r3135_attendance_by_member'),
    supabase.rpc('founder_r3135_nda_status_rollup'),
    supabase.rpc('founder_r3135_pre_read_discipline'),
    supabase.rpc('founder_r3135_decision_follow_up'),
    supabase.rpc('founder_r3135_conflict_audit'),
    supabase.rpc('founder_r3135_compensation_ledger'),
    supabase.rpc('founder_r3135_session_type_rollup'),
    supabase.rpc('founder_r3135_governance_risk_flags'),
  ]);

  const rosterRows: RosterRow[] = (roster.data as RosterRow[]) ?? [];
  const attendanceRows: AttendanceRow[] = (attendance.data as AttendanceRow[]) ?? [];
  const ndaRows: NdaRow[] = (nda.data as NdaRow[]) ?? [];
  const preReadRows: PreReadRow[] = (preRead.data as PreReadRow[]) ?? [];
  const followUpRows: FollowUpRow[] = (followUp.data as FollowUpRow[]) ?? [];
  const conflictRows: ConflictRow[] = (conflicts.data as ConflictRow[]) ?? [];
  const compRows: CompensationRow[] = (comp.data as CompensationRow[]) ?? [];
  const sessionTypeRows: SessionTypeRow[] = (sessionType.data as SessionTypeRow[]) ?? [];
  const riskRows: RiskRow[] = (risk.data as RiskRow[]) ?? [];

  const rosterCols: Column<RosterRow>[] = [
    { key: 'member_full_name', header: 'Member' },
    { key: 'member_role', header: 'Role' },
    { key: 'affiliation_org', header: 'Affiliation' },
    { key: 'seat_class', header: 'Seat class' },
    { key: 'nda_status', header: 'NDA' },
    { key: 'conflict_declared', header: 'Conflict' },
    { key: 'compensation_type', header: 'Comp type' },
    { key: 'quarterly_retainer_rupees', header: 'Retainer/qtr', render: (r) => formatRupees(r.quarterly_retainer_rupees) },
    { key: 'equity_bps', header: 'Equity (bps)' },
    { key: 'is_active', header: 'Active', render: (r) => (r.is_active ? 'Yes' : 'Offboarded') },
  ];

  const attendanceCols: Column<AttendanceRow>[] = [
    { key: 'member_full_name', header: 'Member' },
    { key: 'total_sessions', header: 'Total' },
    { key: 'attended_full_count', header: 'Full' },
    { key: 'attended_partial_count', header: 'Partial' },
    { key: 'written_notes_count', header: 'Written' },
    { key: 'no_show_count', header: 'No-show' },
    { key: 'rescheduled_count', header: 'Reschd' },
    { key: 'attendance_score_pct', header: 'Score %' },
  ];

  const ndaCols: Column<NdaRow>[] = [
    { key: 'nda_status', header: 'NDA status' },
    { key: 'member_count', header: 'Members' },
    { key: 'active_count', header: 'Active' },
  ];

  const preReadCols: Column<PreReadRow>[] = [
    { key: 'session_quarter', header: 'Quarter' },
    { key: 'total_sessions', header: 'Sessions' },
    { key: 'delivered_on_time', header: 'On-time' },
    { key: 'delivered_late', header: 'Late' },
    { key: 'delivered_partial', header: 'Partial' },
    { key: 'skipped', header: 'Skipped' },
    { key: 'avg_lead_hours', header: 'Avg lead hrs' },
  ];

  const followUpCols: Column<FollowUpRow>[] = [
    { key: 'member_full_name', header: 'Member' },
    { key: 'session_type', header: 'Session type' },
    { key: 'session_quarter', header: 'Quarter' },
    { key: 'scheduled_on', header: 'Scheduled', render: (r) => new Date(r.scheduled_on).toLocaleDateString('en-IN') },
    { key: 'decision_follow_up_status', header: 'Status' },
    { key: 'decision_summary', header: 'Decision' },
    { key: 'action_items_count', header: 'Actions' },
  ];

  const conflictCols: Column<ConflictRow>[] = [
    { key: 'conflict_declared', header: 'Conflict class' },
    { key: 'member_count', header: 'Members' },
    { key: 'active_members', header: 'Active' },
    { key: 'members_list', header: 'Names' },
  ];

  const compCols: Column<CompensationRow>[] = [
    { key: 'member_full_name', header: 'Member' },
    { key: 'compensation_type', header: 'Comp type' },
    { key: 'quarterly_retainer_rupees', header: 'Retainer/qtr', render: (r) => formatRupees(r.quarterly_retainer_rupees) },
    { key: 'equity_bps', header: 'Equity (bps)' },
    { key: 'total_paid_rupees', header: 'Total paid', render: (r) => formatRupees(r.total_paid_rupees) },
    { key: 'sessions_compensated', header: 'Sessions paid' },
  ];

  const sessionTypeCols: Column<SessionTypeRow>[] = [
    { key: 'session_quarter', header: 'Quarter' },
    { key: 'session_type', header: 'Session type' },
    { key: 'session_count', header: 'Count' },
    { key: 'total_action_items', header: 'Action items' },
    { key: 'closed_count', header: 'Closed' },
    { key: 'in_progress_count', header: 'In-progress' },
  ];

  const riskCols: Column<RiskRow>[] = [
    { key: 'member_full_name', header: 'Member' },
    { key: 'affiliation_org', header: 'Affiliation' },
    { key: 'nda_status', header: 'NDA' },
    { key: 'conflict_declared', header: 'Conflict' },
    { key: 'is_offboarded', header: 'Offboarded', render: (r) => (r.is_offboarded ? 'Yes' : 'No') },
    { key: 'risk_severity', header: 'Severity' },
    { key: 'risk_note', header: 'Note' },
  ];

  return (
    <main className="mx-auto max-w-7xl p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Board Observer & Advisory Governance Cadence (r3135)</h1>
        <p className="text-sm text-neutral-600 mt-1">
          Member roster, cadence attendance, NDA, pre-read discipline, decision follow-up, conflict declarations, and comp ledger.
        </p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-2">Member roster</h2>
        <DataTable<RosterRow>
          rows={rosterRows}
          columns={rosterCols}
          emptyMessage="No members onboarded."
          rowKey={(r, i) => String(r.member_full_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Attendance by member</h2>
        <DataTable<AttendanceRow>
          rows={attendanceRows}
          columns={attendanceCols}
          emptyMessage="No sessions recorded."
          rowKey={(r, i) => String(r.member_full_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">NDA status rollup</h2>
        <DataTable<NdaRow>
          rows={ndaRows}
          columns={ndaCols}
          emptyMessage="No NDA data."
          rowKey={(r, i) => String(r.nda_status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Pre-read delivery discipline by quarter</h2>
        <DataTable<PreReadRow>
          rows={preReadRows}
          columns={preReadCols}
          emptyMessage="No pre-read data."
          rowKey={(r, i) => String(r.session_quarter ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open decision follow-ups</h2>
        <DataTable<FollowUpRow>
          rows={followUpRows}
          columns={followUpCols}
          emptyMessage="All decisions closed."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Conflict declaration audit</h2>
        <DataTable<ConflictRow>
          rows={conflictRows}
          columns={conflictCols}
          emptyMessage="No conflict data."
          rowKey={(r, i) => String(r.conflict_declared ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Compensation ledger</h2>
        <DataTable<CompensationRow>
          rows={compRows}
          columns={compCols}
          emptyMessage="No compensation records."
          rowKey={(r, i) => String(r.member_full_name ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Session-type rollup by quarter</h2>
        <DataTable<SessionTypeRow>
          rows={sessionTypeRows}
          columns={sessionTypeCols}
          emptyMessage="No sessions recorded."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Governance risk flags</h2>
        <DataTable<RiskRow>
          rows={riskRows}
          columns={riskCols}
          emptyMessage="No governance risks flagged."
          rowKey={(r, i) => String(r.member_full_name ?? i)}
        />
      </section>
    </main>
  );
}
