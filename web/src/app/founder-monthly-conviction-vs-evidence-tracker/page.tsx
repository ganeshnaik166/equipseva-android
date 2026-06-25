import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_topics: number;
  conviction_up: number;
  conviction_down: number;
  avg_current: number;
  evidence_total: number;
  double_down_count: number;
  pivot_or_kill: number;
};

type Topic = {
  id: string;
  topic_label: string;
  topic_domain: string;
  prior_conviction_score: number;
  current_conviction_score: number;
  conviction_delta: number;
  evidence_count: number;
  net_signal: string;
  recommended_action: string;
  calibration_status: string;
};

type Evidence = {
  topic_label: string;
  evidence_date: string;
  evidence_kind: string;
  evidence_polarity: string;
  evidence_weight: number;
  signal_strength: string;
  action_triggered: string;
  evidence_summary: string;
  source_label: string;
  drove_score_change: number;
};

type SignalMix = { net_signal: string; topic_count: number; avg_delta: number };
type ActionRow = { topic_label: string; topic_domain: string; recommended_action: string; current_conviction_score: number; conviction_delta: number; calibration_status: string };
type DomainRow = { topic_domain: string; topic_count: number; avg_current: number; avg_delta: number; total_evidence: number };
type Mover = { topic_label: string; conviction_delta: number; current_conviction_score: number; net_signal: string; recommended_action: string };

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, topicsRes, evidenceRes, signalRes, actionRes, domainRes, moversRes] = await Promise.all([
    supabase.rpc('founder_conviction_r2745_kpis'),
    supabase.rpc('founder_conviction_r2745_topics'),
    supabase.rpc('founder_conviction_r2745_evidence'),
    supabase.rpc('founder_conviction_r2745_signal_mix'),
    supabase.rpc('founder_conviction_r2745_action_queue'),
    supabase.rpc('founder_conviction_r2745_domain_rollup'),
    supabase.rpc('founder_conviction_r2745_top_movers'),
  ]);

  const kpi: Kpi = (kpisRes.data?.[0] as Kpi) ?? { total_topics: 0, conviction_up: 0, conviction_down: 0, avg_current: 0, evidence_total: 0, double_down_count: 0, pivot_or_kill: 0 };
  const topics: Topic[] = (topicsRes.data as Topic[]) ?? [];
  const evidence: Evidence[] = (evidenceRes.data as Evidence[]) ?? [];
  const signalMix: SignalMix[] = (signalRes.data as SignalMix[]) ?? [];
  const actions: ActionRow[] = (actionRes.data as ActionRow[]) ?? [];
  const domains: DomainRow[] = (domainRes.data as DomainRow[]) ?? [];
  const movers: Mover[] = (moversRes.data as Mover[]) ?? [];

  return (
    <div style={{ padding: 24, maxWidth: 1280, margin: '0 auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1 style={{ fontSize: 26, marginBottom: 4 }}>Founder Monthly Conviction vs Evidence Tracker</h1>
      <p style={{ color: '#555', marginBottom: 20 }}>
        Track every founder belief by topic, score conviction, weigh supporting & contradicting evidence, surface signal direction, and calibrate the next action.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 12, marginBottom: 24 }}>
        <Card label="Topics tracked" value={kpi.total_topics} />
        <Card label="Conviction up" value={kpi.conviction_up} />
        <Card label="Conviction down" value={kpi.conviction_down} />
        <Card label="Avg current score" value={kpi.avg_current} />
        <Card label="Evidence logged" value={kpi.evidence_total} />
        <Card label="Double-down" value={kpi.double_down_count} />
        <Card label="Pivot or kill" value={kpi.pivot_or_kill} />
      </section>

      <h2 style={{ fontSize: 18, marginTop: 24, marginBottom: 8 }}>Topics — conviction shift this cycle</h2>
      <DataTable
        rows={topics}
        columns={[
          { key: 'topic_label', header: 'Topic', render: (r: Topic) => r.topic_label },
          { key: 'topic_domain', header: 'Domain', render: (r: Topic) => r.topic_domain },
          { key: 'prior_conviction_score', header: 'Prior', render: (r: Topic) => r.prior_conviction_score },
          { key: 'current_conviction_score', header: 'Current', render: (r: Topic) => r.current_conviction_score },
          { key: 'conviction_delta', header: 'Delta', render: (r: Topic) => (r.conviction_delta > 0 ? '+' : '') + r.conviction_delta },
          { key: 'evidence_count', header: 'Evidence', render: (r: Topic) => r.evidence_count },
          { key: 'net_signal', header: 'Signal', render: (r: Topic) => r.net_signal },
          { key: 'recommended_action', header: 'Action', render: (r: Topic) => r.recommended_action },
          { key: 'calibration_status', header: 'Calibration', render: (r: Topic) => r.calibration_status },
        ]}
        emptyMessage="No topics yet"
        rowKey={(r: Topic, i: number) => String(r.id ?? i)}
      />

      <h2 style={{ fontSize: 18, marginTop: 32, marginBottom: 8 }}>Signal mix</h2>
      <DataTable
        rows={signalMix}
        columns={[
          { key: 'net_signal', header: 'Net signal', render: (r: SignalMix) => r.net_signal },
          { key: 'topic_count', header: 'Topics', render: (r: SignalMix) => r.topic_count },
          { key: 'avg_delta', header: 'Avg delta', render: (r: SignalMix) => (r.avg_delta > 0 ? '+' : '') + r.avg_delta },
        ]}
        emptyMessage="No signal data"
        rowKey={(r: SignalMix, i: number) => String(r.net_signal ?? i)}
      />

      <h2 style={{ fontSize: 18, marginTop: 32, marginBottom: 8 }}>Action queue — decisions owed</h2>
      <DataTable
        rows={actions}
        columns={[
          { key: 'topic_label', header: 'Topic', render: (r: ActionRow) => r.topic_label },
          { key: 'topic_domain', header: 'Domain', render: (r: ActionRow) => r.topic_domain },
          { key: 'recommended_action', header: 'Action', render: (r: ActionRow) => r.recommended_action },
          { key: 'current_conviction_score', header: 'Score', render: (r: ActionRow) => r.current_conviction_score },
          { key: 'conviction_delta', header: 'Delta', render: (r: ActionRow) => (r.conviction_delta > 0 ? '+' : '') + r.conviction_delta },
          { key: 'calibration_status', header: 'Status', render: (r: ActionRow) => r.calibration_status },
        ]}
        emptyMessage="No actions pending"
        rowKey={(r: ActionRow, i: number) => String(r.topic_label + i)}
      />

      <h2 style={{ fontSize: 18, marginTop: 32, marginBottom: 8 }}>Domain rollup</h2>
      <DataTable
        rows={domains}
        columns={[
          { key: 'topic_domain', header: 'Domain', render: (r: DomainRow) => r.topic_domain },
          { key: 'topic_count', header: 'Topics', render: (r: DomainRow) => r.topic_count },
          { key: 'avg_current', header: 'Avg current', render: (r: DomainRow) => r.avg_current },
          { key: 'avg_delta', header: 'Avg delta', render: (r: DomainRow) => (r.avg_delta > 0 ? '+' : '') + r.avg_delta },
          { key: 'total_evidence', header: 'Evidence', render: (r: DomainRow) => r.total_evidence },
        ]}
        emptyMessage="No domain data"
        rowKey={(r: DomainRow, i: number) => String(r.topic_domain ?? i)}
      />

      <h2 style={{ fontSize: 18, marginTop: 32, marginBottom: 8 }}>Top movers</h2>
      <DataTable
        rows={movers}
        columns={[
          { key: 'topic_label', header: 'Topic', render: (r: Mover) => r.topic_label },
          { key: 'conviction_delta', header: 'Delta', render: (r: Mover) => (r.conviction_delta > 0 ? '+' : '') + r.conviction_delta },
          { key: 'current_conviction_score', header: 'Current', render: (r: Mover) => r.current_conviction_score },
          { key: 'net_signal', header: 'Signal', render: (r: Mover) => r.net_signal },
          { key: 'recommended_action', header: 'Action', render: (r: Mover) => r.recommended_action },
        ]}
        emptyMessage="No movers"
        rowKey={(r: Mover, i: number) => String(r.topic_label + i)}
      />

      <h2 style={{ fontSize: 18, marginTop: 32, marginBottom: 8 }}>Evidence log</h2>
      <DataTable
        rows={evidence}
        columns={[
          { key: 'evidence_date', header: 'Date', render: (r: Evidence) => r.evidence_date },
          { key: 'topic_label', header: 'Topic', render: (r: Evidence) => r.topic_label },
          { key: 'evidence_kind', header: 'Kind', render: (r: Evidence) => r.evidence_kind },
          { key: 'evidence_polarity', header: 'Polarity', render: (r: Evidence) => r.evidence_polarity },
          { key: 'evidence_weight', header: 'Weight', render: (r: Evidence) => r.evidence_weight },
          { key: 'signal_strength', header: 'Strength', render: (r: Evidence) => r.signal_strength },
          { key: 'action_triggered', header: 'Action', render: (r: Evidence) => r.action_triggered },
          { key: 'drove_score_change', header: 'Score change', render: (r: Evidence) => (r.drove_score_change > 0 ? '+' : '') + r.drove_score_change },
          { key: 'source_label', header: 'Source', render: (r: Evidence) => r.source_label },
          { key: 'evidence_summary', header: 'Summary', render: (r: Evidence) => r.evidence_summary },
        ]}
        emptyMessage="No evidence yet"
        rowKey={(r: Evidence, i: number) => String(r.topic_label + r.evidence_date + i)}
      />
    </div>
  );
}

function Card({ label, value }: { label: string; value: number }) {
  return (
    <div style={{ background: '#f7f7f8', borderRadius: 10, padding: 14, border: '1px solid #ececef' }}>
      <div style={{ fontSize: 11, color: '#666', textTransform: 'uppercase', letterSpacing: 0.5 }}>{label}</div>
      <div style={{ fontSize: 22, fontWeight: 600, marginTop: 4 }}>{value}</div>
    </div>
  );
}