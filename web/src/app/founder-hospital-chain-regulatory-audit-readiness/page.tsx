import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type DocRow = {
  id: string;
  chain_id: string;
  chain_name: string;
  regulator: string;
  doc_kind: string;
  doc_title: string;
  ready: boolean;
  last_refreshed_at: string | null;
  expires_on: string | null;
  owner_email: string | null;
  audit_window_start: string | null;
  audit_window_end: string | null;
};

type GapRow = {
  id: string;
  chain_id: string;
  chain_name: string;
  regulator: string;
  gap_kind: string;
  gap_title: string;
  severity: string;
  detected_at: string;
  remediation: string | null;
  owner_email: string | null;
  days_open: number;
};

type ScoreRow = {
  chain_id: string;
  chain_name: string;
  total_docs: number;
  ready_docs: number;
  expired_docs: number;
  blocker_gaps: number;
  high_gaps: number;
  medium_gaps: number;
  low_gaps: number;
  readiness_pct: number;
};

type ExpiringRow = {
  id: string;
  chain_id: string;
  chain_name: string;
  regulator: string;
  doc_kind: string;
  doc_title: string;
  expires_on: string | null;
  days_until_expiry: number;
  owner_email: string | null;
};

type UpcomingRow = {
  chain_id: string;
  chain_name: string;
  regulator: string;
  audit_window_start: string | null;
  audit_window_end: string | null;
  days_until_audit: number;
  ready_docs: number;
  total_docs: number;
};

type RegulatorGapRow = {
  regulator: string;
  blocker_gaps: number;
  high_gaps: number;
  medium_gaps: number;
  low_gaps: number;
  total_open: number;
  chains_affected: number;
};

type SummaryRow = {
  total_chains: number;
  total_docs: number;
  ready_docs: number;
  expired_docs: number;
  open_gaps: number;
  blocker_gaps: number;
  upcoming_audits_30d: number;
  avg_readiness_pct: number;
};

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [docsRes, gapsRes, scoreRes, expiringRes, upcomingRes, regGapsRes, summaryRes] = await Promise.all([
    sb.rpc('list_audit_docs_r2383'),
    sb.rpc('list_audit_gaps_r2383'),
    sb.rpc('chain_readiness_score_r2383'),
    sb.rpc('expiring_audit_docs_r2383', { p_days: 30 }),
    sb.rpc('upcoming_audit_windows_r2383'),
    sb.rpc('gaps_by_regulator_r2383'),
    sb.rpc('portfolio_audit_summary_r2383'),
  ]);

  const docs: DocRow[] = (docsRes.data as DocRow[] | null) ?? [];
  const gaps: GapRow[] = (gapsRes.data as GapRow[] | null) ?? [];
  const scores: ScoreRow[] = (scoreRes.data as ScoreRow[] | null) ?? [];
  const expiring: ExpiringRow[] = (expiringRes.data as ExpiringRow[] | null) ?? [];
  const upcoming: UpcomingRow[] = (upcomingRes.data as UpcomingRow[] | null) ?? [];
  const regGaps: RegulatorGapRow[] = (regGapsRes.data as RegulatorGapRow[] | null) ?? [];
  const summary: SummaryRow[] = (summaryRes.data as SummaryRow[] | null) ?? [];
  const s = summary[0];

  const docCols: Column<DocRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'regulator', header: 'Regulator', render: (r: any) => r.regulator },
    { key: 'doc_kind', header: 'Doc kind', render: (r: any) => r.doc_kind },
    { key: 'doc_title', header: 'Title', render: (r: any) => r.doc_title },
    { key: 'ready', header: 'Ready', render: (r: any) => (r.ready ? 'yes' : 'no') },
    { key: 'expires_on', header: 'Expires', render: (r: any) => r.expires_on ?? '—' },
    { key: 'last_refreshed_at', header: 'Refreshed', render: (r: any) => (r.last_refreshed_at ? String(r.last_refreshed_at).slice(0, 10) : '—') },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const gapCols: Column<GapRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'regulator', header: 'Regulator', render: (r: any) => r.regulator },
    { key: 'gap_kind', header: 'Gap kind', render: (r: any) => r.gap_kind },
    { key: 'gap_title', header: 'Title', render: (r: any) => r.gap_title },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity },
    { key: 'days_open', header: 'Days open', render: (r: any) => r.days_open },
    { key: 'remediation', header: 'Remediation', render: (r: any) => r.remediation ?? '—' },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const scoreCols: Column<ScoreRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'readiness_pct', header: 'Readiness %', render: (r: any) => r.readiness_pct },
    { key: 'ready_docs', header: 'Ready', render: (r: any) => `${r.ready_docs}/${r.total_docs}` },
    { key: 'expired_docs', header: 'Expired', render: (r: any) => r.expired_docs },
    { key: 'blocker_gaps', header: 'Blocker', render: (r: any) => r.blocker_gaps },
    { key: 'high_gaps', header: 'High', render: (r: any) => r.high_gaps },
    { key: 'medium_gaps', header: 'Med', render: (r: any) => r.medium_gaps },
    { key: 'low_gaps', header: 'Low', render: (r: any) => r.low_gaps },
  ];

  const expCols: Column<ExpiringRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'regulator', header: 'Regulator', render: (r: any) => r.regulator },
    { key: 'doc_kind', header: 'Doc kind', render: (r: any) => r.doc_kind },
    { key: 'doc_title', header: 'Title', render: (r: any) => r.doc_title },
    { key: 'expires_on', header: 'Expires', render: (r: any) => r.expires_on ?? '—' },
    { key: 'days_until_expiry', header: 'Days left', render: (r: any) => r.days_until_expiry },
    { key: 'owner_email', header: 'Owner', render: (r: any) => r.owner_email ?? '—' },
  ];

  const upcomingCols: Column<UpcomingRow>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'regulator', header: 'Regulator', render: (r: any) => r.regulator },
    { key: 'audit_window_start', header: 'Window start', render: (r: any) => r.audit_window_start ?? '—' },
    { key: 'audit_window_end', header: 'Window end', render: (r: any) => r.audit_window_end ?? '—' },
    { key: 'days_until_audit', header: 'Days out', render: (r: any) => r.days_until_audit },
    { key: 'ready_docs', header: 'Ready', render: (r: any) => `${r.ready_docs}/${r.total_docs}` },
  ];

  const regCols: Column<RegulatorGapRow>[] = [
    { key: 'regulator', header: 'Regulator', render: (r: any) => r.regulator },
    { key: 'blocker_gaps', header: 'Blocker', render: (r: any) => r.blocker_gaps },
    { key: 'high_gaps', header: 'High', render: (r: any) => r.high_gaps },
    { key: 'medium_gaps', header: 'Medium', render: (r: any) => r.medium_gaps },
    { key: 'low_gaps', header: 'Low', render: (r: any) => r.low_gaps },
    { key: 'total_open', header: 'Total open', render: (r: any) => r.total_open },
    { key: 'chains_affected', header: 'Chains', render: (r: any) => r.chains_affected },
  ];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Hospital Chain Regulatory-Audit Readiness</h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Per-chain compliance docs ready for their audits, gap log, readiness score. Track NABH, CDSCO, AERB, PCB, fire, BMW & DPDP audit windows and surface expiring docs before the auditor walks in.
      </p>

      {s ? (
        <section style={{ marginBottom: 28, display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
          <Stat label="Chains" value={s.total_chains} />
          <Stat label="Avg readiness %" value={s.avg_readiness_pct} />
          <Stat label="Ready / total docs" value={`${s.ready_docs} / ${s.total_docs}`} />
          <Stat label="Expired docs" value={s.expired_docs} />
          <Stat label="Open gaps" value={s.open_gaps} />
          <Stat label="Blocker gaps" value={s.blocker_gaps} />
          <Stat label="Audits in next 30 days" value={s.upcoming_audits_30d} />
        </section>
      ) : null}

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Readiness score per chain ({scores.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Score = ready-doc % minus penalties: blocker -20, high -10, medium -4, low -1. Floor 0, cap 100.
        </p>
        <DataTable
          rows={scores}
          columns={scoreCols}
          rowKey={(r: any, i: number) => String(r.chain_id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Upcoming audit windows ({upcoming.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Chains with audit windows starting on or after today. Ready &gt;= total means we&apos;re green.
        </p>
        <DataTable
          rows={upcoming}
          columns={upcomingCols}
          rowKey={(r: any, i: number) => `${r.chain_id}-${r.regulator}-${i}`}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Docs expiring within 30 days ({expiring.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Includes already-expired docs (days left &lt;= 0). Refresh these before the audit window.
        </p>
        <DataTable
          rows={expiring}
          columns={expCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Open gaps ({gaps.length})</h2>
        <p style={{ color: '#666', marginBottom: 8, fontSize: 13 }}>
          Sorted blocker =&gt; high =&gt; medium =&gt; low, then oldest first.
        </p>
        <DataTable
          rows={gaps}
          columns={gapCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Gaps by regulator ({regGaps.length})</h2>
        <DataTable
          rows={regGaps}
          columns={regCols}
          rowKey={(r: any, i: number) => `${r.regulator}-${i}`}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>All audit docs ({docs.length})</h2>
        <DataTable
          rows={docs}
          columns={docCols}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: number | string }) {
  return (
    <div style={{ border: '1px solid #e5e7eb', borderRadius: 8, padding: 12, background: '#fafafa' }}>
      <div style={{ fontSize: 12, color: '#666', marginBottom: 4 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 700 }}>{value}</div>
    </div>
  );
}
