import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpis = {
  total_sessions: number;
  sessions_send: number;
  sessions_hold: number;
  sessions_abort: number;
  avg_confidence: number | null;
  avg_delivery: number | null;
  total_drills: number;
  drills_refine: number;
};

type SessionRow = {
  id: string;
  quarter_label: string;
  audience_kind: string;
  topic_title: string;
  rehearsal_round: number;
  scheduled_at: string;
  founder_confidence: number;
  delivery_score: number;
  send_decision: string;
};

type DrillRow = {
  id: string;
  topic_title: string;
  question_text: string;
  question_category: string;
  asked_by_persona: string;
  answer_clarity: number;
  answer_confidence: number;
  needed_refine: boolean;
  resolved: boolean;
};

type AudienceRow = {
  audience_kind: string;
  sessions: number;
  avg_confidence: number;
  send_rate_pct: number;
};

type RefineRow = {
  topic_title: string;
  refine_count: number;
  refine_notes: string | null;
  founder_confidence: number;
  send_decision: string;
};

type LowConfRow = {
  topic_title: string;
  audience_kind: string;
  founder_confidence: number;
  hard_question_score: number;
  send_decision: string;
};

type SendReadyRow = {
  topic_title: string;
  audience_kind: string;
  founder_confidence: number;
  send_decision: string;
  send_decided_at: string | null;
};

type DrillCatRow = {
  question_category: string;
  drills: number;
  avg_clarity: number;
  unresolved: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpisRes, sessionsRes, drillsRes, audienceRes, refineRes, lowConfRes, sendReadyRes, drillCatRes] = await Promise.all([
    supabase.rpc('rpc_r2861_kpis'),
    supabase.rpc('rpc_r2861_sessions'),
    supabase.rpc('rpc_r2861_drills'),
    supabase.rpc('rpc_r2861_audience_breakdown'),
    supabase.rpc('rpc_r2861_refine_queue'),
    supabase.rpc('rpc_r2861_low_confidence'),
    supabase.rpc('rpc_r2861_send_ready'),
    supabase.rpc('rpc_r2861_drill_categories'),
  ]);

  const kpis: Kpis = (kpisRes.data?.[0] as Kpis) ?? {
    total_sessions: 0,
    sessions_send: 0,
    sessions_hold: 0,
    sessions_abort: 0,
    avg_confidence: 0,
    avg_delivery: 0,
    total_drills: 0,
    drills_refine: 0,
  };

  const sessions: SessionRow[] = (sessionsRes.data as SessionRow[]) ?? [];
  const drills: DrillRow[] = (drillsRes.data as DrillRow[]) ?? [];
  const audience: AudienceRow[] = (audienceRes.data as AudienceRow[]) ?? [];
  const refine: RefineRow[] = (refineRes.data as RefineRow[]) ?? [];
  const lowConf: LowConfRow[] = (lowConfRes.data as LowConfRow[]) ?? [];
  const sendReady: SendReadyRow[] = (sendReadyRes.data as SendReadyRow[]) ?? [];
  const drillCats: DrillCatRow[] = (drillCatRes.data as DrillCatRow[]) ?? [];

  return (
    <div style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>
        Quarterly Board Deck & Investor Call Rehearsal
      </h1>
      <p style={{ color: '#666', marginBottom: 20 }}>
        Round r2861 — rehearsal × audience × topic × score × refine × confidence × send decision.
        Confidence below 7.0 is a hold signal. Drills marked "refine" need a sharper answer before send.
      </p>

      <section style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 24 }}>
        <Kpi label="Total sessions" value={String(kpis.total_sessions)} />
        <Kpi label="Send / Send-w-caveats" value={String(kpis.sessions_send)} />
        <Kpi label="On hold" value={String(kpis.sessions_hold)} />
        <Kpi label="Aborted" value={String(kpis.sessions_abort)} />
        <Kpi label="Avg founder confidence" value={kpis.avg_confidence ? `${kpis.avg_confidence} / 10` : '—'} />
        <Kpi label="Avg delivery" value={kpis.avg_delivery ? `${kpis.avg_delivery} / 10` : '—'} />
        <Kpi label="Hard-question drills" value={String(kpis.total_drills)} />
        <Kpi label="Drills needing refine" value={String(kpis.drills_refine)} />
      </section>

      <Section title="Rehearsal sessions">
        <DataTable
          rows={sessions}
          columns={[
            { key: 'quarter_label', header: 'Quarter', render: (r: SessionRow) => r.quarter_label },
            { key: 'audience_kind', header: 'Audience', render: (r: SessionRow) => r.audience_kind },
            { key: 'topic_title', header: 'Topic', render: (r: SessionRow) => r.topic_title },
            { key: 'rehearsal_round', header: 'Round #', render: (r: SessionRow) => String(r.rehearsal_round) },
            { key: 'scheduled_at', header: 'Scheduled', render: (r: SessionRow) => new Date(r.scheduled_at).toLocaleString() },
            { key: 'founder_confidence', header: 'Confidence', render: (r: SessionRow) => `${r.founder_confidence} / 10` },
            { key: 'delivery_score', header: 'Delivery', render: (r: SessionRow) => `${r.delivery_score} / 10` },
            { key: 'send_decision', header: 'Send decision', render: (r: SessionRow) => r.send_decision },
          ]}
          emptyMessage="No data"
          rowKey={(r: SessionRow, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Hard-question drills">
        <DataTable
          rows={drills}
          columns={[
            { key: 'topic_title', header: 'Topic', render: (r: DrillRow) => r.topic_title },
            { key: 'question_text', header: 'Question', render: (r: DrillRow) => r.question_text },
            { key: 'question_category', header: 'Category', render: (r: DrillRow) => r.question_category },
            { key: 'asked_by_persona', header: 'Asked by', render: (r: DrillRow) => r.asked_by_persona },
            { key: 'answer_clarity', header: 'Clarity', render: (r: DrillRow) => `${r.answer_clarity} / 10` },
            { key: 'answer_confidence', header: 'Confidence', render: (r: DrillRow) => `${r.answer_confidence} / 10` },
            { key: 'needed_refine', header: 'Refine?', render: (r: DrillRow) => (r.needed_refine ? 'yes' : 'no') },
            { key: 'resolved', header: 'Resolved', render: (r: DrillRow) => (r.resolved ? 'yes' : 'no') },
          ]}
          emptyMessage="No data"
          rowKey={(r: DrillRow, i: number) => String(r.id ?? i)}
        />
      </Section>

      <Section title="Audience breakdown">
        <DataTable
          rows={audience}
          columns={[
            { key: 'audience_kind', header: 'Audience', render: (r: AudienceRow) => r.audience_kind },
            { key: 'sessions', header: 'Sessions', render: (r: AudienceRow) => String(r.sessions) },
            { key: 'avg_confidence', header: 'Avg confidence', render: (r: AudienceRow) => `${r.avg_confidence} / 10` },
            { key: 'send_rate_pct', header: 'Send rate', render: (r: AudienceRow) => `${r.send_rate_pct}%` },
          ]}
          emptyMessage="No data"
          rowKey={(r: AudienceRow, i: number) => String(r.audience_kind ?? i)}
        />
      </Section>

      <Section title="Refine queue (sessions iterated more than once)">
        <DataTable
          rows={refine}
          columns={[
            { key: 'topic_title', header: 'Topic', render: (r: RefineRow) => r.topic_title },
            { key: 'refine_count', header: 'Refines', render: (r: RefineRow) => String(r.refine_count) },
            { key: 'refine_notes', header: 'Notes', render: (r: RefineRow) => r.refine_notes ?? '—' },
            { key: 'founder_confidence', header: 'Confidence', render: (r: RefineRow) => `${r.founder_confidence} / 10` },
            { key: 'send_decision', header: 'Decision', render: (r: RefineRow) => r.send_decision },
          ]}
          emptyMessage="No data"
          rowKey={(r: RefineRow, i: number) => String(r.topic_title ?? i)}
        />
      </Section>

      <Section title="Low confidence (below 7.0)">
        <DataTable
          rows={lowConf}
          columns={[
            { key: 'topic_title', header: 'Topic', render: (r: LowConfRow) => r.topic_title },
            { key: 'audience_kind', header: 'Audience', render: (r: LowConfRow) => r.audience_kind },
            { key: 'founder_confidence', header: 'Confidence', render: (r: LowConfRow) => `${r.founder_confidence} / 10` },
            { key: 'hard_question_score', header: 'Hard Q score', render: (r: LowConfRow) => `${r.hard_question_score} / 10` },
            { key: 'send_decision', header: 'Decision', render: (r: LowConfRow) => r.send_decision },
          ]}
          emptyMessage="No data"
          rowKey={(r: LowConfRow, i: number) => String(r.topic_title ?? i)}
        />
      </Section>

      <Section title="Send-ready">
        <DataTable
          rows={sendReady}
          columns={[
            { key: 'topic_title', header: 'Topic', render: (r: SendReadyRow) => r.topic_title },
            { key: 'audience_kind', header: 'Audience', render: (r: SendReadyRow) => r.audience_kind },
            { key: 'founder_confidence', header: 'Confidence', render: (r: SendReadyRow) => `${r.founder_confidence} / 10` },
            { key: 'send_decision', header: 'Decision', render: (r: SendReadyRow) => r.send_decision },
            { key: 'send_decided_at', header: 'Decided at', render: (r: SendReadyRow) => (r.send_decided_at ? new Date(r.send_decided_at).toLocaleString() : '—') },
          ]}
          emptyMessage="No data"
          rowKey={(r: SendReadyRow, i: number) => String(r.topic_title ?? i)}
        />
      </Section>

      <Section title="Drill categories">
        <DataTable
          rows={drillCats}
          columns={[
            { key: 'question_category', header: 'Category', render: (r: DrillCatRow) => r.question_category },
            { key: 'drills', header: 'Drills', render: (r: DrillCatRow) => String(r.drills) },
            { key: 'avg_clarity', header: 'Avg clarity', render: (r: DrillCatRow) => `${r.avg_clarity} / 10` },
            { key: 'unresolved', header: 'Unresolved', render: (r: DrillCatRow) => String(r.unresolved) },
          ]}
          emptyMessage="No data"
          rowKey={(r: DrillCatRow, i: number) => String(r.question_category ?? i)}
        />
      </Section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ background: '#fafafa', border: '1px solid #eee', borderRadius: 8, padding: 12 }}>
      <div style={{ color: '#666', fontSize: 12 }}>{label}</div>
      <div style={{ fontSize: 20, fontWeight: 700, marginTop: 4 }}>{value}</div>
    </div>
  );
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ marginBottom: 28 }}>
      <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 10 }}>{title}</h2>
      {children}
    </section>
  );
}
