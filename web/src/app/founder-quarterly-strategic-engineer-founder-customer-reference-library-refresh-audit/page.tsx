import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/founder/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_refs: number;
  current_refs: number;
  needs_refresh_refs: number;
  stale_refs: number;
  expired_refs: number;
  draft_refs: number;
  avg_strategic_score: number | string;
  total_amc_value_rupees: number;
};

type ByVertical = {
  vertical: string;
  ref_count: number;
  current_count: number;
  avg_score: number | string;
  amc_value_rupees: number;
};

type TopStrategic = {
  hospital_name: string;
  hospital_tier: string;
  vertical: string;
  reference_type: string;
  refresh_status: string;
  strategic_score: number;
  amc_value_rupees: number;
  founder_owner: string;
};

type RefreshQueue = {
  hospital_name: string;
  refresh_status: string;
  freshness_days: number;
  expires_on: string;
  strategic_score: number;
  founder_owner: string;
  engineer_anchor: string | null;
};

type AuditBySeverity = {
  severity: string;
  finding_count: number;
  open_count: number;
  resolved_count: number;
  total_blast_radius_rupees: number;
  avg_days_open: number | string;
};

type OpenCritical = {
  hospital_name: string;
  audit_area: string;
  severity: string;
  finding_summary: string;
  owner_role: string;
  days_open: number;
  due_on: string;
  blast_radius_rupees: number;
};

type OwnerWorkload = {
  owner_role: string;
  finding_count: number;
  open_count: number;
  total_effort_hours: number;
  total_blast_radius_rupees: number;
};

type FounderOwnerBook = {
  founder_owner: string;
  ref_count: number;
  current_count: number;
  needs_attention_count: number;
  total_amc_value_rupees: number;
  avg_strategic_score: number | string;
};

function rupees(n: number | null | undefined): string {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    overviewRes,
    byVerticalRes,
    topStrategicRes,
    refreshQueueRes,
    auditBySeverityRes,
    openCriticalRes,
    ownerWorkloadRes,
    founderOwnerBookRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3049_library_overview'),
    supabase.rpc('founder_r3049_by_vertical'),
    supabase.rpc('founder_r3049_top_strategic'),
    supabase.rpc('founder_r3049_refresh_queue'),
    supabase.rpc('founder_r3049_audit_by_severity'),
    supabase.rpc('founder_r3049_open_critical'),
    supabase.rpc('founder_r3049_owner_workload'),
    supabase.rpc('founder_r3049_founder_owner_book'),
  ]);

  const overview = (overviewRes.data?.[0] ?? null) as Overview | null;
  const byVertical = (byVerticalRes.data ?? []) as ByVertical[];
  const topStrategic = (topStrategicRes.data ?? []) as TopStrategic[];
  const refreshQueue = (refreshQueueRes.data ?? []) as RefreshQueue[];
  const auditBySeverity = (auditBySeverityRes.data ?? []) as AuditBySeverity[];
  const openCritical = (openCriticalRes.data ?? []) as OpenCritical[];
  const ownerWorkload = (ownerWorkloadRes.data ?? []) as OwnerWorkload[];
  const founderOwnerBook = (founderOwnerBookRes.data ?? []) as FounderOwnerBook[];

  const byVerticalCols: Column<ByVertical>[] = [
    { header: 'Vertical', accessor: (r) => r.vertical },
    { header: 'Refs', accessor: (r) => r.ref_count },
    { header: 'Current', accessor: (r) => r.current_count },
    { header: 'Avg Score', accessor: (r) => r.avg_score },
    { header: 'AMC Value', accessor: (r) => rupees(r.amc_value_rupees) },
  ];

  const topCols: Column<TopStrategic>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Tier', accessor: (r) => r.hospital_tier },
    { header: 'Vertical', accessor: (r) => r.vertical },
    { header: 'Type', accessor: (r) => r.reference_type },
    { header: 'Status', accessor: (r) => r.refresh_status },
    { header: 'Score', accessor: (r) => r.strategic_score },
    { header: 'AMC', accessor: (r) => rupees(r.amc_value_rupees) },
    { header: 'Owner', accessor: (r) => r.founder_owner },
  ];

  const refreshCols: Column<RefreshQueue>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Status', accessor: (r) => r.refresh_status },
    { header: 'Days Old', accessor: (r) => r.freshness_days },
    { header: 'Expires', accessor: (r) => r.expires_on },
    { header: 'Score', accessor: (r) => r.strategic_score },
    { header: 'Owner', accessor: (r) => r.founder_owner },
    { header: 'Engineer', accessor: (r) => r.engineer_anchor ?? '—' },
  ];

  const severityCols: Column<AuditBySeverity>[] = [
    { header: 'Severity', accessor: (r) => r.severity },
    { header: 'Findings', accessor: (r) => r.finding_count },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Resolved', accessor: (r) => r.resolved_count },
    { header: 'Blast Radius', accessor: (r) => rupees(r.total_blast_radius_rupees) },
    { header: 'Avg Days Open', accessor: (r) => r.avg_days_open },
  ];

  const criticalCols: Column<OpenCritical>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital_name },
    { header: 'Area', accessor: (r) => r.audit_area },
    { header: 'Sev', accessor: (r) => r.severity },
    { header: 'Finding', accessor: (r) => r.finding_summary },
    { header: 'Owner', accessor: (r) => r.owner_role },
    { header: 'Days', accessor: (r) => r.days_open },
    { header: 'Due', accessor: (r) => r.due_on },
    { header: 'Blast', accessor: (r) => rupees(r.blast_radius_rupees) },
  ];

  const workloadCols: Column<OwnerWorkload>[] = [
    { header: 'Owner Role', accessor: (r) => r.owner_role },
    { header: 'Findings', accessor: (r) => r.finding_count },
    { header: 'Open', accessor: (r) => r.open_count },
    { header: 'Effort Hrs', accessor: (r) => r.total_effort_hours },
    { header: 'Blast Radius', accessor: (r) => rupees(r.total_blast_radius_rupees) },
  ];

  const bookCols: Column<FounderOwnerBook>[] = [
    { header: 'Founder', accessor: (r) => r.founder_owner },
    { header: 'Refs', accessor: (r) => r.ref_count },
    { header: 'Current', accessor: (r) => r.current_count },
    { header: 'Needs Attn', accessor: (r) => r.needs_attention_count },
    { header: 'AMC Value', accessor: (r) => rupees(r.total_amc_value_rupees) },
    { header: 'Avg Score', accessor: (r) => r.avg_strategic_score },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Quarterly Strategic Engineer-Founder Customer-Reference Library Refresh Audit
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Round r3049 — founder console
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Library Overview</h2>
        {overview ? (
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12 }}>
            <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
              <div style={{ color: '#666', fontSize: 12 }}>Total Refs</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{overview.total_refs}</div>
            </div>
            <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
              <div style={{ color: '#666', fontSize: 12 }}>Current</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{overview.current_refs}</div>
            </div>
            <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
              <div style={{ color: '#666', fontSize: 12 }}>Needs Refresh</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{overview.needs_refresh_refs}</div>
            </div>
            <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
              <div style={{ color: '#666', fontSize: 12 }}>Stale</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{overview.stale_refs}</div>
            </div>
            <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
              <div style={{ color: '#666', fontSize: 12 }}>Expired</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{overview.expired_refs}</div>
            </div>
            <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
              <div style={{ color: '#666', fontSize: 12 }}>Draft</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{overview.draft_refs}</div>
            </div>
            <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
              <div style={{ color: '#666', fontSize: 12 }}>Avg Score</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{overview.avg_strategic_score}</div>
            </div>
            <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12 }}>
              <div style={{ color: '#666', fontSize: 12 }}>Total AMC Value</div>
              <div style={{ fontSize: 22, fontWeight: 700 }}>{rupees(overview.total_amc_value_rupees)}</div>
            </div>
          </div>
        ) : (
          <div style={{ color: '#666' }}>No overview data.</div>
        )}
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>By Vertical</h2>
        <DataTable
          rows={byVertical}
          columns={byVerticalCols}
          emptyMessage="No vertical data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top 10 Strategic References</h2>
        <DataTable
          rows={topStrategic}
          columns={topCols}
          emptyMessage="No strategic references."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Refresh Queue (stale + needs_refresh + expired)</h2>
        <DataTable
          rows={refreshQueue}
          columns={refreshCols}
          emptyMessage="Queue empty."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Audit Findings by Severity</h2>
        <DataTable
          rows={auditBySeverity}
          columns={severityCols}
          emptyMessage="No findings."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Open p0/p1 Findings</h2>
        <DataTable
          rows={openCritical}
          columns={criticalCols}
          emptyMessage="No critical open findings."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Owner Workload</h2>
        <DataTable
          rows={ownerWorkload}
          columns={workloadCols}
          emptyMessage="No workload data."
          rowKey={(r, i) => String(i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Founder Owner Book</h2>
        <DataTable
          rows={founderOwnerBook}
          columns={bookCols}
          emptyMessage="No owner book data."
          rowKey={(r, i) => String(i)}
        />
      </section>
    </main>
  );
}
