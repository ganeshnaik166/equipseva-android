import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type FailureRow = {
  id: string;
  engineer_email: string | null;
  hospital_name: string | null;
  equipment_name: string;
  failure_type: string;
  failure_at: string;
  repaired_in_same_visit: boolean;
  status: string;
  root_cause_md: string | null;
};

type PatternRow = {
  failure_type: string;
  total_count: number;
  repaired_count: number;
  open_count: number;
  same_visit_repair_count: number;
};

type ResponseRow = {
  id: string;
  failure_id: string;
  equipment_name: string | null;
  action_type: string;
  taken_at: string;
  by_email: string | null;
  outcome: string | null;
};

export default async function FounderEngineerFieldEquipmentFailuresPage() {
  const sb = await getSupabaseServerClient();

  const [failuresRes, patternsRes, responsesRes] = await Promise.all([
    sb.rpc('list_failures_r1900'),
    sb.rpc('failure_pattern_summary_r1900'),
    sb.rpc('recent_responses_r1900'),
  ]);

  const failures: FailureRow[] = (failuresRes.data as FailureRow[]) ?? [];
  const patterns: PatternRow[] = (patternsRes.data as PatternRow[]) ?? [];
  const responses: ResponseRow[] = (responsesRes.data as ResponseRow[]) ?? [];

  const failureCols: Column<FailureRow>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name ?? '—' },
    { key: 'failure_type', header: 'Type', render: (r: any) => r.failure_type ?? '—' },
    { key: 'engineer_email', header: 'Engineer', render: (r: any) => r.engineer_email ?? '—' },
    { key: 'hospital_name', header: 'Hospital', render: (r: any) => r.hospital_name ?? '—' },
    { key: 'failure_at', header: 'Failure At', render: (r: any) => r.failure_at ? new Date(r.failure_at).toLocaleString() : '—' },
    { key: 'repaired_in_same_visit', header: 'Same Visit?', render: (r: any) => r.repaired_in_same_visit ? 'yes' : 'no' },
    { key: 'status', header: 'Status', render: (r: any) => r.status ?? '—' },
  ];

  const patternCols: Column<PatternRow>[] = [
    { key: 'failure_type', header: 'Failure Type', render: (r: any) => r.failure_type ?? '—' },
    { key: 'total_count', header: 'Total', render: (r: any) => String(r.total_count ?? 0) },
    { key: 'repaired_count', header: 'Repaired', render: (r: any) => String(r.repaired_count ?? 0) },
    { key: 'open_count', header: 'Open', render: (r: any) => String(r.open_count ?? 0) },
    { key: 'same_visit_repair_count', header: 'Same-Visit Fix', render: (r: any) => String(r.same_visit_repair_count ?? 0) },
  ];

  const responseCols: Column<ResponseRow>[] = [
    { key: 'equipment_name', header: 'Equipment', render: (r: any) => r.equipment_name ?? '—' },
    { key: 'action_type', header: 'Action', render: (r: any) => r.action_type ?? '—' },
    { key: 'taken_at', header: 'Taken At', render: (r: any) => r.taken_at ? new Date(r.taken_at).toLocaleString() : '—' },
    { key: 'by_email', header: 'By', render: (r: any) => r.by_email ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome ?? '—' },
  ];

  const totalFailures = failures.length;
  const openFailures = failures.filter((f) => f.status === 'open').length;
  const sameVisitFixes = failures.filter((f) => f.repaired_in_same_visit).length;

  return (
    <main style={{ padding: '24px', maxWidth: '1280px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '24px', fontWeight: 700, marginBottom: '8px' }}>
        Engineer Field Equipment Failures
      </h1>
      <p style={{ color: '#555', marginBottom: '24px', fontSize: '14px' }}>
        Track equipment failures during repair jobs — engineer-caught vs hospital-reported,
        with response actions and pattern summaries.
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '12px' }}>Overview</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '12px' }}>
          <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Total Failures</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalFailures}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Open</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{openFailures}</div>
          </div>
          <div style={{ padding: '16px', border: '1px solid #e5e5e5', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Same-Visit Fixes</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{sameVisitFixes}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '12px' }}>
          Failure Pattern Summary
        </h2>
        <DataTable
          rows={patterns}
          columns={patternCols}
          rowKey={(r: any, i: number) => String(r.failure_type ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '12px' }}>
          Recent Failures (latest 200)
        </h2>
        <DataTable
          rows={failures}
          columns={failureCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '16px', fontWeight: 600, marginBottom: '12px' }}>
          Recent Response Actions
        </h2>
        <DataTable
          rows={responses}
          columns={responseCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
