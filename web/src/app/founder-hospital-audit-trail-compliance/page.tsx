import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type ComplianceRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  audit_body: string;
  last_audit_date: string | null;
  next_audit_date: string | null;
  evidence_pack_url: string | null;
  compliance_score: number | null;
  status: string;
  observations_count: number;
  created_at: string;
};

type UpcomingRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  audit_body: string;
  next_audit_date: string | null;
  days_until: number | null;
  status: string;
  compliance_score: number | null;
};

type AtRiskRow = {
  id: string;
  hospital_user_id: string;
  hospital_email: string | null;
  audit_body: string;
  compliance_score: number | null;
  status: string;
  observations_count: number;
  major_observations: number;
  next_audit_date: string | null;
};

function fmtDate(d: string | null): string {
  if (!d) return '—';
  return new Date(d).toISOString().slice(0, 10);
}

function fmtScore(s: number | null): string {
  if (s === null || s === undefined) return '—';
  return `${s}/100`;
}

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [compliance, upcoming, atRisk] = await Promise.all([
    sb.rpc('list_compliance_r1783'),
    sb.rpc('upcoming_audits_r1783'),
    sb.rpc('top_at_risk_r1783'),
  ]);

  const complianceRows: ComplianceRow[] = (compliance.data ?? []) as ComplianceRow[];
  const upcomingRows: UpcomingRow[] = (upcoming.data ?? []) as UpcomingRow[];
  const atRiskRows: AtRiskRow[] = (atRisk.data ?? []) as AtRiskRow[];

  const totalHospitals = complianceRows.length;
  const compliantCount = complianceRows.filter((r) => r.status === 'compliant').length;
  const issuesCount = complianceRows.filter((r) => r.status === 'issues').length;
  const nonCompliantCount = complianceRows.filter((r) => r.status === 'non_compliant').length;
  const upcoming30 = upcomingRows.filter((r) => (r.days_until ?? 999) <= 30).length;
  const avgScore =
    complianceRows.length > 0
      ? Math.round(
          complianceRows.reduce((acc, r) => acc + (r.compliance_score ?? 0), 0) /
            complianceRows.length
        )
      : 0;

  const complianceCols: Column<ComplianceRow>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) ?? '—' },
    { key: 'audit_body', header: 'Body', render: (r: any) => String(r.audit_body ?? '').toUpperCase() },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'compliance_score', header: 'Score', render: (r: any) => fmtScore(r.compliance_score) },
    { key: 'last_audit_date', header: 'Last Audit', render: (r: any) => fmtDate(r.last_audit_date) },
    { key: 'next_audit_date', header: 'Next Audit', render: (r: any) => fmtDate(r.next_audit_date) },
    { key: 'observations_count', header: 'Obs', render: (r: any) => String(r.observations_count ?? 0) },
    {
      key: 'evidence_pack_url',
      header: 'Evidence',
      render: (r: any) =>
        r.evidence_pack_url ? (
          <a href={r.evidence_pack_url} target="_blank" rel="noopener noreferrer" style={{ color: '#0070f3' }}>
            pack
          </a>
        ) : (
          '—'
        ),
    },
  ];

  const upcomingCols: Column<UpcomingRow>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) ?? '—' },
    { key: 'audit_body', header: 'Body', render: (r: any) => String(r.audit_body ?? '').toUpperCase() },
    { key: 'next_audit_date', header: 'Next Audit', render: (r: any) => fmtDate(r.next_audit_date) },
    { key: 'days_until', header: 'Days Until', render: (r: any) => String(r.days_until ?? '—') },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'compliance_score', header: 'Score', render: (r: any) => fmtScore(r.compliance_score) },
  ];

  const atRiskCols: Column<AtRiskRow>[] = [
    { key: 'hospital_email', header: 'Hospital', render: (r: any) => r.hospital_email ?? r.hospital_user_id?.slice(0, 8) ?? '—' },
    { key: 'audit_body', header: 'Body', render: (r: any) => String(r.audit_body ?? '').toUpperCase() },
    { key: 'compliance_score', header: 'Score', render: (r: any) => fmtScore(r.compliance_score) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'major_observations', header: 'Open Major', render: (r: any) => String(r.major_observations ?? 0) },
    { key: 'observations_count', header: 'Total Obs', render: (r: any) => String(r.observations_count ?? 0) },
    { key: 'next_audit_date', header: 'Next Audit', render: (r: any) => fmtDate(r.next_audit_date) },
  ];

  return (
    <div style={{ padding: '24px', maxWidth: '1400px', margin: '0 auto' }}>
      <h1 style={{ fontSize: '28px', fontWeight: 700, marginBottom: '8px' }}>
        Hospital Audit Trail Compliance
      </h1>
      <p style={{ color: '#666', marginBottom: '24px' }}>
        Round 1783 · NABH / NABL / JCI / ISO evidence packs per hospital
      </p>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>Overview</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: '12px' }}>
          <div style={{ background: '#f5f5f5', padding: '16px', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Hospitals tracked</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{totalHospitals}</div>
          </div>
          <div style={{ background: '#e6f7e6', padding: '16px', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Compliant</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{compliantCount}</div>
          </div>
          <div style={{ background: '#fff4e5', padding: '16px', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>With issues</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{issuesCount}</div>
          </div>
          <div style={{ background: '#fde2e2', padding: '16px', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Non-compliant</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{nonCompliantCount}</div>
          </div>
          <div style={{ background: '#f5f5f5', padding: '16px', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Audits &lt;= 30d</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{upcoming30}</div>
          </div>
          <div style={{ background: '#f5f5f5', padding: '16px', borderRadius: '8px' }}>
            <div style={{ fontSize: '12px', color: '#666' }}>Avg score</div>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{avgScore}</div>
          </div>
        </div>
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Compliance records ({complianceRows.length})
        </h2>
        <DataTable<ComplianceRow>
          rows={complianceRows}
          columns={complianceCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Upcoming audits (next 90 days)
        </h2>
        <DataTable<UpcomingRow>
          rows={upcomingRows}
          columns={upcomingCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: '32px' }}>
        <h2 style={{ fontSize: '18px', fontWeight: 600, marginBottom: '12px' }}>
          Top at-risk hospitals
        </h2>
        <p style={{ color: '#666', fontSize: '13px', marginBottom: '8px' }}>
          Hospitals with status issues / non_compliant / under_review, sorted by lowest score & open major observations.
        </p>
        <DataTable<AtRiskRow>
          rows={atRiskRows}
          columns={atRiskCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
