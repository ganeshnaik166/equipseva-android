import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_photos: number;
  granted_count: number;
  pending_count: number;
  denied_count: number;
  disputes_open: number;
};

type LedgerRow = {
  id: string;
  engineer_code: string;
  engineer_name: string;
  customer_org: string;
  asset_label: string;
  photo_kind: string;
  consent_status: string;
  usage_intent: string;
  redaction_level: string;
  outcome: string;
  photos_count: number;
  captured_at: string;
};

type EngineerRollup = {
  engineer_code: string;
  engineer_name: string;
  total_rows: number;
  photos_count: number;
  granted_count: number;
  issues_count: number;
};

type IntentRow = {
  usage_intent: string;
  row_count: number;
  photos_total: number;
  granted_share: number | null;
};

type RedactionRow = {
  redaction_level: string;
  row_count: number;
  photos_total: number;
};

type DisputeRow = {
  dispute_state: string;
  outcome: string;
  row_count: number;
};

type AuditRow = {
  id: string;
  consent_id: string;
  audit_step: string;
  actor_role: string;
  decision: string;
  notes: string | null;
  cost_paise: number;
  duration_seconds: number;
  occurred_at: string;
};

type OutcomeRow = {
  outcome: string;
  row_count: number;
  photos_total: number;
  share_pct: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, ledgerRes, rollupRes, intentRes, redactRes, disputeRes, auditRes, outcomeRes] = await Promise.all([
    supabase.rpc('founder_r2790_photo_consent_kpis'),
    supabase.rpc('founder_r2790_consent_ledger'),
    supabase.rpc('founder_r2790_engineer_rollup'),
    supabase.rpc('founder_r2790_usage_intent_breakdown'),
    supabase.rpc('founder_r2790_redaction_distribution'),
    supabase.rpc('founder_r2790_dispute_board'),
    supabase.rpc('founder_r2790_audit_trail'),
    supabase.rpc('founder_r2790_outcome_funnel'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? {
    total_photos: 0, granted_count: 0, pending_count: 0, denied_count: 0, disputes_open: 0,
  };
  const ledger: LedgerRow[] = (ledgerRes.data as LedgerRow[]) ?? [];
  const rollup: EngineerRollup[] = (rollupRes.data as EngineerRollup[]) ?? [];
  const intents: IntentRow[] = (intentRes.data as IntentRow[]) ?? [];
  const redactions: RedactionRow[] = (redactRes.data as RedactionRow[]) ?? [];
  const disputes: DisputeRow[] = (disputeRes.data as DisputeRow[]) ?? [];
  const audits: AuditRow[] = (auditRes.data as AuditRow[]) ?? [];
  const outcomes: OutcomeRow[] = (outcomeRes.data as OutcomeRow[]) ?? [];

  const kpis = [
    { label: 'Total Photos', value: String(kpi.total_photos) },
    { label: 'Consent Granted', value: String(kpi.granted_count) },
    { label: 'Pending', value: String(kpi.pending_count) },
    { label: 'Denied', value: String(kpi.denied_count) },
    { label: 'Disputes Open', value: String(kpi.disputes_open) },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1280, margin: '0 auto' }}>
      <header style={{ marginBottom: 24 }}>
        <h1 style={{ fontSize: 26, fontWeight: 700 }}>
          Engineer Monthly Customer Photo Share Consent
        </h1>
        <p style={{ color: '#555', marginTop: 6 }}>
          Round r2790 — engineer × photo × consent status × usage × redaction × dispute × outcome.
          Founder-only view: tracks every engineer-captured photo, who consented, how it was redacted, and where it landed.
        </p>
      </header>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 28 }}>
        {kpis.map((k) => (
          <div key={k.label} style={{ border: '1px solid #e5e5e5', borderRadius: 10, padding: 14, background: '#fafafa' }}>
            <div style={{ fontSize: 12, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{k.label}</div>
            <div style={{ fontSize: 24, fontWeight: 700, marginTop: 4 }}>{k.value}</div>
          </div>
        ))}
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Consent Ledger</h2>
        <DataTable
          rows={ledger}
          columns={[
            { key: 'engineer_code', header: 'Engineer', render: (r: LedgerRow) => `${r.engineer_code} / ${r.engineer_name}` },
            { key: 'customer_org', header: 'Customer', render: (r: LedgerRow) => r.customer_org },
            { key: 'asset_label', header: 'Asset', render: (r: LedgerRow) => r.asset_label },
            { key: 'photo_kind', header: 'Kind', render: (r: LedgerRow) => r.photo_kind },
            { key: 'consent_status', header: 'Consent', render: (r: LedgerRow) => r.consent_status },
            { key: 'usage_intent', header: 'Usage', render: (r: LedgerRow) => r.usage_intent },
            { key: 'redaction_level', header: 'Redaction', render: (r: LedgerRow) => r.redaction_level },
            { key: 'outcome', header: 'Outcome', render: (r: LedgerRow) => r.outcome },
            { key: 'photos_count', header: 'Photos', render: (r: LedgerRow) => String(r.photos_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: LedgerRow, i: number) => String(r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Engineer Rollup</h2>
        <DataTable
          rows={rollup}
          columns={[
            { key: 'engineer_code', header: 'Engineer Code', render: (r: EngineerRollup) => r.engineer_code },
            { key: 'engineer_name', header: 'Name', render: (r: EngineerRollup) => r.engineer_name },
            { key: 'total_rows', header: 'Rows', render: (r: EngineerRollup) => String(r.total_rows) },
            { key: 'photos_count', header: 'Photos', render: (r: EngineerRollup) => String(r.photos_count) },
            { key: 'granted_count', header: 'Granted', render: (r: EngineerRollup) => String(r.granted_count) },
            { key: 'issues_count', header: 'Issues', render: (r: EngineerRollup) => String(r.issues_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: EngineerRollup, i: number) => String(r.engineer_code ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Usage Intent Breakdown</h2>
        <DataTable
          rows={intents}
          columns={[
            { key: 'usage_intent', header: 'Intent', render: (r: IntentRow) => r.usage_intent },
            { key: 'row_count', header: 'Rows', render: (r: IntentRow) => String(r.row_count) },
            { key: 'photos_total', header: 'Photos', render: (r: IntentRow) => String(r.photos_total) },
            { key: 'granted_share', header: 'Granted %', render: (r: IntentRow) => (r.granted_share == null ? '-' : `${r.granted_share}%`) },
          ]}
          emptyMessage="No data"
          rowKey={(r: IntentRow, i: number) => String(r.usage_intent ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Redaction Distribution</h2>
        <DataTable
          rows={redactions}
          columns={[
            { key: 'redaction_level', header: 'Level', render: (r: RedactionRow) => r.redaction_level },
            { key: 'row_count', header: 'Rows', render: (r: RedactionRow) => String(r.row_count) },
            { key: 'photos_total', header: 'Photos', render: (r: RedactionRow) => String(r.photos_total) },
          ]}
          emptyMessage="No data"
          rowKey={(r: RedactionRow, i: number) => String(r.redaction_level ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Dispute Board</h2>
        <DataTable
          rows={disputes}
          columns={[
            { key: 'dispute_state', header: 'Dispute State', render: (r: DisputeRow) => r.dispute_state },
            { key: 'outcome', header: 'Outcome', render: (r: DisputeRow) => r.outcome },
            { key: 'row_count', header: 'Rows', render: (r: DisputeRow) => String(r.row_count) },
          ]}
          emptyMessage="No data"
          rowKey={(r: DisputeRow, i: number) => `${r.dispute_state}-${r.outcome}-${i}`}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Outcome Funnel</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeRow) => r.outcome },
            { key: 'row_count', header: 'Rows', render: (r: OutcomeRow) => String(r.row_count) },
            { key: 'photos_total', header: 'Photos', render: (r: OutcomeRow) => String(r.photos_total) },
            { key: 'share_pct', header: 'Share %', render: (r: OutcomeRow) => (r.share_pct == null ? '-' : `${r.share_pct}%`) },
          ]}
          emptyMessage="No data"
          rowKey={(r: OutcomeRow, i: number) => String(r.outcome ?? i)}
        />
      </section>

      <section style={{ marginBottom: 28 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 10 }}>Redaction & Dispute Audit Trail</h2>
        <DataTable
          rows={audits}
          columns={[
            { key: 'occurred_at', header: 'When', render: (r: AuditRow) => new Date(r.occurred_at).toLocaleString() },
            { key: 'audit_step', header: 'Step', render: (r: AuditRow) => r.audit_step },
            { key: 'actor_role', header: 'Actor', render: (r: AuditRow) => r.actor_role },
            { key: 'decision', header: 'Decision', render: (r: AuditRow) => r.decision },
            { key: 'notes', header: 'Notes', render: (r: AuditRow) => r.notes ?? '-' },
            { key: 'cost_paise', header: 'Cost (paise)', render: (r: AuditRow) => String(r.cost_paise) },
            { key: 'duration_seconds', header: 'Duration (s)', render: (r: AuditRow) => String(r.duration_seconds) },
          ]}
          emptyMessage="No data"
          rowKey={(r: AuditRow, i: number) => String(r.id ?? i)}
        />
      </section>
    </main>
  );
}
