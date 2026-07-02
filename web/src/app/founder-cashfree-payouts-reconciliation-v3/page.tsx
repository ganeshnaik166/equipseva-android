import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { formatNumber } from '@/lib/format';

export const dynamic = 'force-dynamic';

type Summary = {
  lifetime_attempts: number;
  lifetime_succeeded: number;
  lifetime_failed: number;
  lifetime_amount_rupees: number;
  lifetime_succeeded_rupees: number;
  attempts_30d: number;
  succeeded_30d: number;
  failed_30d: number;
  amount_30d_rupees: number;
  pending_attempts: number;
  manual_intervention_count: number;
  reverted_count: number;
  webhooks_total: number;
  webhooks_30d: number;
  invalid_signature_count: number;
  reconciliation_runs_total: number;
  last_run_status: string;
  discrepancies_open: number;
};

type Attempt = {
  id: string;
  engineer_payout_id: string;
  attempt_number: number;
  cashfree_reference_id: string | null;
  amount_rupees: number;
  attempt_status: string;
  failure_reason: string | null;
  failure_code: string | null;
  submitted_at: string;
  completed_at: string | null;
};

type Webhook = {
  id: string;
  event_id: string;
  event_kind: string;
  payout_attempt_id: string | null;
  signature_valid: boolean | null;
  received_at: string;
  processed_at: string | null;
  processing_outcome: string | null;
};

type Run = {
  id: string;
  run_date: string;
  run_kind: string;
  total_payouts_processed: number | null;
  total_attempts_made: number | null;
  total_succeeded: number | null;
  total_failed: number | null;
  total_amount_rupees: number | null;
  total_amount_succeeded_rupees: number | null;
  discrepancies_found: number;
  discrepancy_amount_rupees: number;
  run_status: string;
  started_at: string;
  completed_at: string | null;
};

type Discrepancy = {
  attempt_id: string;
  engineer_payout_id: string;
  attempt_number: number;
  cashfree_reference_id: string | null;
  amount_rupees: number;
  attempt_status: string;
  failure_reason: string | null;
  submitted_at: string;
  hours_stale: number;
};

function statusColor(s: string): string {
  if (s === 'succeeded' || s === 'complete') return '#16a34a';
  if (s === 'failed' || s === 'timeout' || s === 'reverted') return '#dc2626';
  if (s === 'manual_intervention') return '#9333ea';
  if (s === 'pending' || s === 'submitted' || s === 'running') return '#f59e0b';
  return '#6b7280';
}

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, attemptsRes, webhooksRes, runsRes, discrepanciesRes] = await Promise.all([
    supabase.rpc('founder_cashfree_v3_summary'),
    supabase.rpc('founder_cashfree_v3_attempts_recent', { p_status: null, p_limit: 100 }),
    supabase.rpc('founder_cashfree_v3_webhooks_recent', { p_limit: 100 }),
    supabase.rpc('founder_cashfree_v3_reconciliation_runs_recent', { p_limit: 20 }),
    supabase.rpc('founder_cashfree_v3_discrepancies'),
  ]);

  const s: Summary = (summaryRes.data?.[0] ?? {}) as Summary;
  const attempts: Attempt[] = (attemptsRes.data ?? []) as Attempt[];
  const webhooks: Webhook[] = (webhooksRes.data ?? []) as Webhook[];
  const runs: Run[] = (runsRes.data ?? []) as Run[];
  const discrepancies: Discrepancy[] = (discrepanciesRes.data ?? []) as Discrepancy[];

  const cards: { label: string; value: string; sub?: string }[] = [
    { label: 'Lifetime Attempts', value: formatNumber(s.lifetime_attempts ?? 0) },
    { label: 'Lifetime Succeeded', value: formatNumber(s.lifetime_succeeded ?? 0) },
    { label: 'Lifetime Failed', value: formatNumber(s.lifetime_failed ?? 0) },
    { label: 'Lifetime Amount', value: `Rs ${formatNumber(s.lifetime_amount_rupees ?? 0)}` },
    { label: 'Lifetime Succeeded Rs', value: `Rs ${formatNumber(s.lifetime_succeeded_rupees ?? 0)}` },
    { label: 'Attempts 30d', value: formatNumber(s.attempts_30d ?? 0) },
    { label: 'Succeeded 30d', value: formatNumber(s.succeeded_30d ?? 0) },
    { label: 'Failed 30d', value: formatNumber(s.failed_30d ?? 0) },
    { label: 'Amount 30d', value: `Rs ${formatNumber(s.amount_30d_rupees ?? 0)}` },
    { label: 'Pending Attempts', value: formatNumber(s.pending_attempts ?? 0) },
    { label: 'Manual Intervention', value: formatNumber(s.manual_intervention_count ?? 0) },
    { label: 'Reverted', value: formatNumber(s.reverted_count ?? 0) },
    { label: 'Webhooks Total', value: formatNumber(s.webhooks_total ?? 0) },
    { label: 'Webhooks 30d', value: formatNumber(s.webhooks_30d ?? 0) },
    { label: 'Invalid Signatures', value: formatNumber(s.invalid_signature_count ?? 0) },
    { label: 'Reconciliation Runs', value: formatNumber(s.reconciliation_runs_total ?? 0) },
    { label: 'Last Run Status', value: s.last_run_status ?? 'none' },
    { label: 'Open Discrepancies', value: formatNumber(s.discrepancies_open ?? 0) },
  ];

  return (
    <main style={{ padding: '2rem', maxWidth: 1400, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <div style={{
        background: 'linear-gradient(135deg, #7c3aed 0%, #db2777 50%, #f59e0b 100%)',
        color: 'white',
        padding: '2rem',
        borderRadius: 16,
        marginBottom: '1.5rem',
        boxShadow: '0 10px 40px rgba(124,58,237,0.3)',
      }}>
        <div style={{ fontSize: 14, fontWeight: 700, letterSpacing: 2, opacity: 0.9 }}>
          ★★★★★ R1400 — 600 SHIPS MILESTONE ★★★★★
        </div>
        <h1 style={{ fontSize: 36, fontWeight: 800, margin: '0.5rem 0' }}>
          Cashfree Payouts v3 Reconciliation Engine
        </h1>
        <div style={{ fontSize: 16, opacity: 0.95 }}>
          Attempt ledger · Webhook events · Daily reconciliation runs · Discrepancy detection
        </div>
      </div>

      {discrepancies.length > 0 && (
        <section style={{ background: '#fef2f2', border: '2px solid #dc2626', borderRadius: 12, padding: '1.25rem', marginBottom: '1.5rem' }}>
          <h2 style={{ color: '#b91c1c', margin: '0 0 0.5rem', fontSize: 18 }}>
            ⚠ {discrepancies.length} Open Discrepancies — Manual Review Required
          </h2>
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
              <thead>
                <tr style={{ background: '#fee2e2' }}>
                  <th style={{ padding: '0.5rem', textAlign: 'left' }}>Attempt</th>
                  <th style={{ padding: '0.5rem', textAlign: 'left' }}>Payout</th>
                  <th style={{ padding: '0.5rem', textAlign: 'left' }}>Ref</th>
                  <th style={{ padding: '0.5rem', textAlign: 'right' }}>Amount</th>
                  <th style={{ padding: '0.5rem', textAlign: 'left' }}>Status</th>
                  <th style={{ padding: '0.5rem', textAlign: 'right' }}>Hrs Stale</th>
                  <th style={{ padding: '0.5rem', textAlign: 'left' }}>Reason</th>
                </tr>
              </thead>
              <tbody>
                {discrepancies.map((d) => (
                  <tr key={d.attempt_id} style={{ borderTop: '1px solid #fecaca' }}>
                    <td style={{ padding: '0.5rem', fontFamily: 'monospace', fontSize: 11 }}>{d.attempt_id.slice(0, 8)} #{d.attempt_number}</td>
                    <td style={{ padding: '0.5rem', fontFamily: 'monospace', fontSize: 11 }}>{d.engineer_payout_id.slice(0, 8)}</td>
                    <td style={{ padding: '0.5rem', fontFamily: 'monospace', fontSize: 11 }}>{d.cashfree_reference_id ?? '—'}</td>
                    <td style={{ padding: '0.5rem', textAlign: 'right' }}>Rs {formatNumber(d.amount_rupees)}</td>
                    <td style={{ padding: '0.5rem', color: statusColor(d.attempt_status), fontWeight: 600 }}>{d.attempt_status}</td>
                    <td style={{ padding: '0.5rem', textAlign: 'right' }}>{Number(d.hours_stale).toFixed(1)}</td>
                    <td style={{ padding: '0.5rem' }}>{d.failure_reason ?? '—'}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      )}

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: 20, fontWeight: 700, margin: '0 0 1rem' }}>18 KPIs</h2>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))', gap: '0.75rem' }}>
          {cards.map((c) => (
            <div key={c.label} style={{ background: '#fff', border: '1px solid #e5e7eb', borderRadius: 10, padding: '1rem', boxShadow: '0 1px 2px rgba(0,0,0,0.04)' }}>
              <div style={{ fontSize: 12, color: '#6b7280', fontWeight: 500 }}>{c.label}</div>
              <div style={{ fontSize: 22, fontWeight: 700, color: '#111827', marginTop: 4 }}>{c.value}</div>
            </div>
          ))}
        </div>
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: 20, fontWeight: 700, margin: '0 0 0.75rem' }}>Payout Attempts (last 100)</h2>
        <div style={{ overflowX: 'auto', background: '#fff', border: '1px solid #e5e7eb', borderRadius: 10 }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr style={{ background: '#f9fafb' }}>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Attempt</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Payout</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>#</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>CF Ref</th>
                <th style={{ padding: '0.6rem', textAlign: 'right' }}>Amount</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Status</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Failure</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Submitted</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Completed</th>
              </tr>
            </thead>
            <tbody>
              {attempts.length === 0 ? (
                <tr><td colSpan={9} style={{ padding: '1rem', textAlign: 'center', color: '#6b7280' }}>No attempts yet</td></tr>
              ) : attempts.map((a) => (
                <tr key={a.id} style={{ borderTop: '1px solid #f3f4f6' }}>
                  <td style={{ padding: '0.5rem', fontFamily: 'monospace', fontSize: 11 }}>{a.id.slice(0, 8)}</td>
                  <td style={{ padding: '0.5rem', fontFamily: 'monospace', fontSize: 11 }}>{a.engineer_payout_id.slice(0, 8)}</td>
                  <td style={{ padding: '0.5rem' }}>{a.attempt_number}</td>
                  <td style={{ padding: '0.5rem', fontFamily: 'monospace', fontSize: 11 }}>{a.cashfree_reference_id ?? '—'}</td>
                  <td style={{ padding: '0.5rem', textAlign: 'right' }}>Rs {formatNumber(a.amount_rupees)}</td>
                  <td style={{ padding: '0.5rem', color: statusColor(a.attempt_status), fontWeight: 600 }}>{a.attempt_status}</td>
                  <td style={{ padding: '0.5rem', fontSize: 12 }}>{a.failure_reason ?? a.failure_code ?? '—'}</td>
                  <td style={{ padding: '0.5rem', fontSize: 12 }}>{new Date(a.submitted_at).toLocaleString()}</td>
                  <td style={{ padding: '0.5rem', fontSize: 12 }}>{a.completed_at ? new Date(a.completed_at).toLocaleString() : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section style={{ marginBottom: '2rem' }}>
        <h2 style={{ fontSize: 20, fontWeight: 700, margin: '0 0 0.75rem' }}>Webhook Events (last 100)</h2>
        <div style={{ overflowX: 'auto', background: '#fff', border: '1px solid #e5e7eb', borderRadius: 10 }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr style={{ background: '#f9fafb' }}>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Event ID</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Kind</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Attempt</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Signature</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Outcome</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Received</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Processed</th>
              </tr>
            </thead>
            <tbody>
              {webhooks.length === 0 ? (
                <tr><td colSpan={7} style={{ padding: '1rem', textAlign: 'center', color: '#6b7280' }}>No webhooks yet</td></tr>
              ) : webhooks.map((w) => (
                <tr key={w.id} style={{ borderTop: '1px solid #f3f4f6' }}>
                  <td style={{ padding: '0.5rem', fontFamily: 'monospace', fontSize: 11 }}>{w.event_id.slice(0, 16)}</td>
                  <td style={{ padding: '0.5rem', fontWeight: 600 }}>{w.event_kind}</td>
                  <td style={{ padding: '0.5rem', fontFamily: 'monospace', fontSize: 11 }}>{w.payout_attempt_id ? w.payout_attempt_id.slice(0, 8) : '—'}</td>
                  <td style={{
                    padding: '0.5rem',
                    color: w.signature_valid === true ? '#16a34a' : w.signature_valid === false ? '#dc2626' : '#6b7280',
                    fontWeight: 600,
                  }}>
                    {w.signature_valid === true ? '✓ valid' : w.signature_valid === false ? '✗ INVALID' : '—'}
                  </td>
                  <td style={{ padding: '0.5rem' }}>{w.processing_outcome ?? '—'}</td>
                  <td style={{ padding: '0.5rem', fontSize: 12 }}>{new Date(w.received_at).toLocaleString()}</td>
                  <td style={{ padding: '0.5rem', fontSize: 12 }}>{w.processed_at ? new Date(w.processed_at).toLocaleString() : '—'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section>
        <h2 style={{ fontSize: 20, fontWeight: 700, margin: '0 0 0.75rem' }}>Reconciliation Runs (last 20)</h2>
        <div style={{ overflowX: 'auto', background: '#fff', border: '1px solid #e5e7eb', borderRadius: 10 }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr style={{ background: '#f9fafb' }}>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Date</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Kind</th>
                <th style={{ padding: '0.6rem', textAlign: 'right' }}>Payouts</th>
                <th style={{ padding: '0.6rem', textAlign: 'right' }}>Attempts</th>
                <th style={{ padding: '0.6rem', textAlign: 'right' }}>Succeeded</th>
                <th style={{ padding: '0.6rem', textAlign: 'right' }}>Failed</th>
                <th style={{ padding: '0.6rem', textAlign: 'right' }}>Amount</th>
                <th style={{ padding: '0.6rem', textAlign: 'right' }}>Succeeded Rs</th>
                <th style={{ padding: '0.6rem', textAlign: 'right' }}>Discrepancies</th>
                <th style={{ padding: '0.6rem', textAlign: 'left' }}>Status</th>
              </tr>
            </thead>
            <tbody>
              {runs.length === 0 ? (
                <tr><td colSpan={10} style={{ padding: '1rem', textAlign: 'center', color: '#6b7280' }}>No reconciliation runs yet</td></tr>
              ) : runs.map((r) => (
                <tr key={r.id} style={{ borderTop: '1px solid #f3f4f6' }}>
                  <td style={{ padding: '0.5rem' }}>{r.run_date}</td>
                  <td style={{ padding: '0.5rem' }}>{r.run_kind}</td>
                  <td style={{ padding: '0.5rem', textAlign: 'right' }}>{formatNumber(r.total_payouts_processed ?? 0)}</td>
                  <td style={{ padding: '0.5rem', textAlign: 'right' }}>{formatNumber(r.total_attempts_made ?? 0)}</td>
                  <td style={{ padding: '0.5rem', textAlign: 'right', color: '#16a34a' }}>{formatNumber(r.total_succeeded ?? 0)}</td>
                  <td style={{ padding: '0.5rem', textAlign: 'right', color: '#dc2626' }}>{formatNumber(r.total_failed ?? 0)}</td>
                  <td style={{ padding: '0.5rem', textAlign: 'right' }}>Rs {formatNumber(r.total_amount_rupees ?? 0)}</td>
                  <td style={{ padding: '0.5rem', textAlign: 'right' }}>Rs {formatNumber(r.total_amount_succeeded_rupees ?? 0)}</td>
                  <td style={{ padding: '0.5rem', textAlign: 'right', color: r.discrepancies_found > 0 ? '#dc2626' : '#16a34a', fontWeight: 600 }}>{r.discrepancies_found}</td>
                  <td style={{ padding: '0.5rem', color: statusColor(r.run_status), fontWeight: 600 }}>{r.run_status}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
