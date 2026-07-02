import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [sumRes, listRes, chainRes, metricRes, rootRes, negRes, queueRes] = await Promise.all([
    sb.rpc('founder_chain_sla_breach_summary_r2375'),
    sb.rpc('founder_chain_sla_breach_list_r2375'),
    sb.rpc('founder_chain_sla_exposure_by_chain_r2375'),
    sb.rpc('founder_chain_sla_breach_by_metric_r2375'),
    sb.rpc('founder_chain_sla_root_cause_mix_r2375'),
    sb.rpc('founder_chain_sla_negotiations_r2375'),
    sb.rpc('founder_chain_sla_action_queue_r2375'),
  ]);

  const summary: any = Array.isArray(sumRes.data) ? sumRes.data[0] ?? {} : sumRes.data ?? {};
  const breaches: any[] = Array.isArray(listRes.data) ? listRes.data : [];
  const byChain: any[] = Array.isArray(chainRes.data) ? chainRes.data : [];
  const byMetric: any[] = Array.isArray(metricRes.data) ? metricRes.data : [];
  const rootCauses: any[] = Array.isArray(rootRes.data) ? rootRes.data : [];
  const negotiations: any[] = Array.isArray(negRes.data) ? negRes.data : [];
  const queue: any[] = Array.isArray(queueRes.data) ? queueRes.data : [];

  const fmtRupees = (n: number | bigint | null | undefined) => {
    const v = Number(n ?? 0);
    return '₹' + v.toLocaleString('en-IN');
  };

  const breachCols: Column<any>[] = [
    { key: 'breach_ref', header: 'Ref', render: (r: any) => r.breach_ref },
    { key: 'detected_at', header: 'Detected', render: (r: any) => new Date(r.detected_at).toLocaleString() },
    { key: 'chain_name', header: 'Chain', render: (r: any) => `${r.chain_name} (${r.chain_tier})` },
    { key: 'hospital_site', header: 'Site', render: (r: any) => r.hospital_site ?? '—' },
    { key: 'sla_metric', header: 'SLA Metric', render: (r: any) => r.sla_metric },
    { key: 'breach_severity', header: 'Severity', render: (r: any) => r.breach_severity },
    { key: 'contractual_threshold', header: 'Threshold', render: (r: any) => r.contractual_threshold },
    { key: 'observed_value', header: 'Observed', render: (r: any) => r.observed_value },
    { key: 'contractual_penalty_rupees', header: 'Contract Penalty', render: (r: any) => fmtRupees(r.contractual_penalty_rupees) },
    { key: 'customer_claimed_penalty_rupees', header: 'Customer Claim', render: (r: any) => fmtRupees(r.customer_claimed_penalty_rupees) },
    { key: 'our_proposed_settlement_rupees', header: 'Our Offer', render: (r: any) => fmtRupees(r.our_proposed_settlement_rupees) },
    { key: 'final_settlement_rupees', header: 'Final', render: (r: any) => (r.final_settlement_rupees == null ? '—' : fmtRupees(r.final_settlement_rupees)) },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'relationship_impact', header: 'Relationship', render: (r: any) => r.relationship_impact ?? '—' },
    { key: 'due_date_for_settlement', header: 'Due', render: (r: any) => r.due_date_for_settlement ?? '—' },
    { key: 'press_or_social_risk', header: 'Press Risk', render: (r: any) => (r.press_or_social_risk ? 'Y' : '—') },
    { key: 'legal_exposure_flag', header: 'Legal', render: (r: any) => (r.legal_exposure_flag ? 'Y' : '—') },
    { key: 'negotiation_round_count', header: 'Rounds', render: (r: any) => String(r.negotiation_round_count ?? 0) },
    { key: 'created_by_email', header: 'Logged By', render: (r: any) => r.created_by_email ?? '—' },
  ];

  const chainCols: Column<any>[] = [
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'chain_tier', header: 'Tier', render: (r: any) => r.chain_tier },
    { key: 'open_breaches', header: 'Open', render: (r: any) => String(r.open_breaches ?? 0) },
    { key: 'worst_severity', header: 'Worst', render: (r: any) => r.worst_severity ?? '—' },
    { key: 'total_contractual_penalty_rupees', header: 'Contract Penalty', render: (r: any) => fmtRupees(r.total_contractual_penalty_rupees) },
    { key: 'total_customer_claim_rupees', header: 'Customer Claim', render: (r: any) => fmtRupees(r.total_customer_claim_rupees) },
    { key: 'total_paid_rupees', header: 'Paid', render: (r: any) => fmtRupees(r.total_paid_rupees) },
    { key: 'arr_at_chain_rupees', header: 'ARR', render: (r: any) => fmtRupees(r.arr_at_chain_rupees) },
    { key: 'contract_at_risk', header: 'Contract At Risk', render: (r: any) => (r.contract_at_risk ? 'Y' : '—') },
  ];

  const metricCols: Column<any>[] = [
    { key: 'sla_metric', header: 'SLA Metric', render: (r: any) => r.sla_metric },
    { key: 'breach_count', header: 'Breaches', render: (r: any) => String(r.breach_count ?? 0) },
    { key: 'contractual_penalty_rupees', header: 'Contract Penalty', render: (r: any) => fmtRupees(r.contractual_penalty_rupees) },
    { key: 'paid_rupees', header: 'Paid', render: (r: any) => fmtRupees(r.paid_rupees) },
    { key: 'avg_settlement_pct_of_claim', header: 'Avg Settle % of Claim', render: (r: any) => (r.avg_settlement_pct_of_claim == null ? '—' : `${Number(r.avg_settlement_pct_of_claim).toFixed(2)}%`) },
  ];

  const rootCols: Column<any>[] = [
    { key: 'root_cause_category', header: 'Root Cause', render: (r: any) => r.root_cause_category },
    { key: 'breach_count', header: 'Breaches', render: (r: any) => String(r.breach_count ?? 0) },
    { key: 'fully_preventable', header: 'Fully Preventable', render: (r: any) => String(r.fully_preventable ?? 0) },
    { key: 'partly_preventable', header: 'Partly', render: (r: any) => String(r.partly_preventable ?? 0) },
    { key: 'unpreventable', header: 'Unpreventable', render: (r: any) => String(r.unpreventable ?? 0) },
    { key: 'total_penalty_rupees', header: 'Penalty', render: (r: any) => fmtRupees(r.total_penalty_rupees) },
  ];

  const negCols: Column<any>[] = [
    { key: 'occurred_at', header: 'When', render: (r: any) => new Date(r.occurred_at).toLocaleString() },
    { key: 'breach_ref', header: 'Breach', render: (r: any) => r.breach_ref },
    { key: 'chain_name', header: 'Chain', render: (r: any) => r.chain_name },
    { key: 'round_number', header: 'Round', render: (r: any) => `#${r.round_number}` },
    { key: 'channel', header: 'Channel', render: (r: any) => r.channel },
    { key: 'participant_label', header: 'Participant', render: (r: any) => r.participant_label },
    { key: 'customer_position_rupees', header: 'Their Ask', render: (r: any) => (r.customer_position_rupees == null ? '—' : fmtRupees(r.customer_position_rupees)) },
    { key: 'our_position_rupees', header: 'Our Offer', render: (r: any) => (r.our_position_rupees == null ? '—' : fmtRupees(r.our_position_rupees)) },
    { key: 'customer_tone', header: 'Tone', render: (r: any) => r.customer_tone ?? '—' },
    { key: 'outcome', header: 'Outcome', render: (r: any) => r.outcome },
    { key: 'next_action', header: 'Next Action', render: (r: any) => (r.next_action ?? '').slice(0, 120) },
    { key: 'next_action_due', header: 'Due', render: (r: any) => r.next_action_due ?? '—' },
    { key: 'logged_by_email', header: 'Logged By', render: (r: any) => r.logged_by_email ?? '—' },
  ];

  const queueCols: Column<any>[] = [
    { key: 'breach_ref', header: 'Ref', render: (r: any) => r.breach_ref },
    { key: 'chain_name', header: 'Chain', render: (r: any) => `${r.chain_name} (${r.chain_tier})` },
    { key: 'breach_severity', header: 'Severity', render: (r: any) => r.breach_severity },
    { key: 'status', header: 'Status', render: (r: any) => r.status },
    { key: 'contractual_penalty_rupees', header: 'Contract', render: (r: any) => fmtRupees(r.contractual_penalty_rupees) },
    { key: 'customer_claimed_penalty_rupees', header: 'Claim', render: (r: any) => fmtRupees(r.customer_claimed_penalty_rupees) },
    { key: 'due_date_for_settlement', header: 'Due', render: (r: any) => r.due_date_for_settlement ?? '—' },
    { key: 'days_overdue', header: 'Days Overdue', render: (r: any) => String(r.days_overdue ?? 0) },
    { key: 'press_or_social_risk', header: 'Press', render: (r: any) => (r.press_or_social_risk ? 'Y' : '—') },
    { key: 'legal_exposure_flag', header: 'Legal', render: (r: any) => (r.legal_exposure_flag ? 'Y' : '—') },
    { key: 'relationship_impact', header: 'Relationship', render: (r: any) => r.relationship_impact ?? '—' },
    { key: 'recommended_action', header: 'Recommended Action', render: (r: any) => r.recommended_action },
  ];

  return (
    <main style={{ padding: '24px', maxWidth: 1400, margin: '0 auto' }}>
      <h1 style={{ fontSize: 28, fontWeight: 700, marginBottom: 8 }}>
        Hospital Chain SLA Breach & Penalty Log
      </h1>
      <p style={{ color: '#666', marginBottom: 24 }}>
        Every contractual SLA breach we cause, the penalty clause it triggers, what the chain claims, what we proposed, the negotiation rounds, and the final settlement. Pay fast where we owe; defend cleanly where we don't; learn where prevention is cheap.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Open Breaches</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{Number(summary.open_breaches ?? 0)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Negotiating</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{Number(summary.negotiating ?? 0)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Major/Catastrophic</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#b91c1c' }}>{Number(summary.catastrophic_or_major ?? 0)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Contract Penalty (Open)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtRupees(summary.total_contractual_penalty_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Customer Claim (Open)</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtRupees(summary.total_customer_claim_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Paid Last 90d</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtRupees(summary.total_paid_last_90d_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>ARR Under Threat</div>
          <div style={{ fontSize: 22, fontWeight: 700 }}>{fmtRupees(summary.total_arr_under_threat_rupees)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Press Risk</div>
          <div style={{ fontSize: 24, fontWeight: 700 }}>{Number(summary.press_risk_count ?? 0)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Legal Exposure</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#b91c1c' }}>{Number(summary.legal_exposure_count ?? 0)}</div>
        </div>
        <div style={{ padding: 16, border: '1px solid #e5e5e5', borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: '#666' }}>Overdue Settlements</div>
          <div style={{ fontSize: 24, fontWeight: 700, color: '#b45309' }}>{Number(summary.overdue_settlements ?? 0)}</div>
        </div>
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Action Queue — Founder Decides Today</h2>
        <p style={{ color: '#666', marginBottom: 12, fontSize: 14 }}>
          Major or catastrophic breaches, legal exposure, press risk, overdue settlements, and contracts at risk. Each row carries a recommended next move.
        </p>
        <DataTable rows={queue} columns={queueCols} emptyMessage="No urgent breach actions." rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>All Breach Events</h2>
        <DataTable rows={breaches} columns={breachCols} emptyMessage="No breach events logged." rowKey={(r: any) => r.id} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Exposure by Chain</h2>
        <DataTable rows={byChain} columns={chainCols} emptyMessage="No chain exposure yet." rowKey={(r: any) => r.chain_name} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Breach Mix by SLA Metric</h2>
        <DataTable rows={byMetric} columns={metricCols} emptyMessage="No SLA metric breakdown yet." rowKey={(r: any) => r.sla_metric} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Root Cause & Preventability</h2>
        <DataTable rows={rootCauses} columns={rootCols} emptyMessage="No root-cause data yet." rowKey={(r: any) => r.root_cause_category} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 20, fontWeight: 600, marginBottom: 12 }}>Post-Incident Negotiation Rounds</h2>
        <p style={{ color: '#666', marginBottom: 12, fontSize: 14 }}>
          Every round of back-and-forth with the chain — their position, our offer, tone, outcome, and next action.
        </p>
        <DataTable rows={negotiations} columns={negCols} emptyMessage="No negotiation rounds logged yet." rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
