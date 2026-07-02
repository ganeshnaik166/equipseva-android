import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ChannelRow = {
  channel: string;
  broadcasts_count: number;
  total_audience: number;
  total_opened: number;
  total_consumed: number;
  open_rate_pct: number | null;
  consume_rate_pct: number | null;
  avg_nps: number | null;
};

type AudienceRow = {
  audience_segment: string;
  broadcasts_count: number;
  total_reach: number;
  consume_rate_pct: number | null;
  reply_count: number;
  follow_up_completion_pct: number | null;
  avg_nps: number | null;
};

type CadenceRow = {
  cadence_slot: string;
  broadcasts_count: number;
  avg_consume_rate_pct: number | null;
  avg_nps: number | null;
  dud_count: number;
  excellent_count: number;
};

type ToneRow = {
  tone_classification: string;
  broadcasts_count: number;
  avg_clarity: number | null;
  avg_alignment: number | null;
  positive_sentiment_pct: number | null;
  concern_pct: number | null;
};

type FollowupRow = {
  broadcast_code: string;
  title: string;
  follow_up_action_count: number;
  follow_up_completed_count: number;
  completion_pct: number | null;
  effectiveness_band: string;
};

type LangRow = {
  language_primary: string;
  broadcasts_count: number;
  total_consumed: number;
  consume_rate_pct: number | null;
  avg_nps: number | null;
};

type RoleRow = {
  responder_role: string;
  total_feedback: number;
  raised_concern_count: number;
  concern_pct: number | null;
  avg_nps: number | null;
  avg_clarity: number | null;
};

type BroadcastRow = {
  broadcast_code: string;
  title: string;
  channel: string;
  audience_segment: string;
  topic_theme: string;
  sent_at: string;
  duration_minutes: number;
  audience_size: number;
  fully_consumed_count: number;
  avg_nps_score: number | null;
  tone_classification: string;
  effectiveness_band: string;
  status: string;
};

const fmtPct = (n: number | null | undefined) =>
  n == null ? '—' : `${Number(n).toFixed(1)}%`;
const fmtNum = (n: number | null | undefined) =>
  n == null ? '—' : Number(n).toLocaleString('en-IN');
const fmtNps = (n: number | null | undefined) =>
  n == null ? '—' : Number(n).toFixed(2);
const fmtDate = (s: string | null | undefined) =>
  !s ? '—' : new Date(s).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    channelRes,
    audienceRes,
    cadenceRes,
    toneRes,
    followupRes,
    langRes,
    roleRes,
    recentRes,
  ] = await Promise.all([
    supabase.rpc('fn_r3111_channel_rollup'),
    supabase.rpc('fn_r3111_audience_rollup'),
    supabase.rpc('fn_r3111_cadence_effectiveness'),
    supabase.rpc('fn_r3111_tone_outcome'),
    supabase.rpc('fn_r3111_followup_completion'),
    supabase.rpc('fn_r3111_language_reach'),
    supabase.rpc('fn_r3111_role_concern_hotspots'),
    supabase.rpc('fn_r3111_recent_broadcasts'),
  ]);

  const channels = (channelRes.data ?? []) as ChannelRow[];
  const audience = (audienceRes.data ?? []) as AudienceRow[];
  const cadence = (cadenceRes.data ?? []) as CadenceRow[];
  const tone = (toneRes.data ?? []) as ToneRow[];
  const followup = (followupRes.data ?? []) as FollowupRow[];
  const langs = (langRes.data ?? []) as LangRow[];
  const roles = (roleRes.data ?? []) as RoleRow[];
  const recent = (recentRes.data ?? []) as BroadcastRow[];

  const channelCols: Column<ChannelRow>[] = [
    { key: 'channel', header: 'Channel' },
    { key: 'broadcasts_count', header: 'Broadcasts', render: (r) => fmtNum(r.broadcasts_count) },
    { key: 'total_audience', header: 'Audience', render: (r) => fmtNum(r.total_audience) },
    { key: 'total_opened', header: 'Opened', render: (r) => fmtNum(r.total_opened) },
    { key: 'total_consumed', header: 'Consumed', render: (r) => fmtNum(r.total_consumed) },
    { key: 'open_rate_pct', header: 'Open rate', render: (r) => fmtPct(r.open_rate_pct) },
    { key: 'consume_rate_pct', header: 'Consume rate', render: (r) => fmtPct(r.consume_rate_pct) },
    { key: 'avg_nps', header: 'Avg NPS', render: (r) => fmtNps(r.avg_nps) },
  ];

  const audienceCols: Column<AudienceRow>[] = [
    { key: 'audience_segment', header: 'Audience' },
    { key: 'broadcasts_count', header: 'Broadcasts', render: (r) => fmtNum(r.broadcasts_count) },
    { key: 'total_reach', header: 'Reach', render: (r) => fmtNum(r.total_reach) },
    { key: 'consume_rate_pct', header: 'Consume %', render: (r) => fmtPct(r.consume_rate_pct) },
    { key: 'reply_count', header: 'Replies', render: (r) => fmtNum(r.reply_count) },
    { key: 'follow_up_completion_pct', header: 'Follow-up done', render: (r) => fmtPct(r.follow_up_completion_pct) },
    { key: 'avg_nps', header: 'Avg NPS', render: (r) => fmtNps(r.avg_nps) },
  ];

  const cadenceCols: Column<CadenceRow>[] = [
    { key: 'cadence_slot', header: 'Cadence' },
    { key: 'broadcasts_count', header: 'Broadcasts', render: (r) => fmtNum(r.broadcasts_count) },
    { key: 'avg_consume_rate_pct', header: 'Avg consume %', render: (r) => fmtPct(r.avg_consume_rate_pct) },
    { key: 'avg_nps', header: 'Avg NPS', render: (r) => fmtNps(r.avg_nps) },
    { key: 'excellent_count', header: 'Excellent', render: (r) => fmtNum(r.excellent_count) },
    { key: 'dud_count', header: 'Duds', render: (r) => fmtNum(r.dud_count) },
  ];

  const toneCols: Column<ToneRow>[] = [
    { key: 'tone_classification', header: 'Tone' },
    { key: 'broadcasts_count', header: 'Broadcasts', render: (r) => fmtNum(r.broadcasts_count) },
    { key: 'avg_clarity', header: 'Clarity (1-5)', render: (r) => fmtNps(r.avg_clarity) },
    { key: 'avg_alignment', header: 'Alignment (1-5)', render: (r) => fmtNps(r.avg_alignment) },
    { key: 'positive_sentiment_pct', header: 'Positive %', render: (r) => fmtPct(r.positive_sentiment_pct) },
    { key: 'concern_pct', header: 'Concern %', render: (r) => fmtPct(r.concern_pct) },
  ];

  const followupCols: Column<FollowupRow>[] = [
    { key: 'broadcast_code', header: 'Code' },
    { key: 'title', header: 'Title' },
    { key: 'follow_up_action_count', header: 'Actions', render: (r) => fmtNum(r.follow_up_action_count) },
    { key: 'follow_up_completed_count', header: 'Completed', render: (r) => fmtNum(r.follow_up_completed_count) },
    { key: 'completion_pct', header: 'Completion %', render: (r) => fmtPct(r.completion_pct) },
    { key: 'effectiveness_band', header: 'Band' },
  ];

  const langCols: Column<LangRow>[] = [
    { key: 'language_primary', header: 'Language' },
    { key: 'broadcasts_count', header: 'Broadcasts', render: (r) => fmtNum(r.broadcasts_count) },
    { key: 'total_consumed', header: 'Consumed', render: (r) => fmtNum(r.total_consumed) },
    { key: 'consume_rate_pct', header: 'Consume %', render: (r) => fmtPct(r.consume_rate_pct) },
    { key: 'avg_nps', header: 'Avg NPS', render: (r) => fmtNps(r.avg_nps) },
  ];

  const roleCols: Column<RoleRow>[] = [
    { key: 'responder_role', header: 'Role' },
    { key: 'total_feedback', header: 'Feedback', render: (r) => fmtNum(r.total_feedback) },
    { key: 'raised_concern_count', header: 'Concerns raised', render: (r) => fmtNum(r.raised_concern_count) },
    { key: 'concern_pct', header: 'Concern %', render: (r) => fmtPct(r.concern_pct) },
    { key: 'avg_nps', header: 'Avg NPS', render: (r) => fmtNps(r.avg_nps) },
    { key: 'avg_clarity', header: 'Avg clarity (1-5)', render: (r) => fmtNps(r.avg_clarity) },
  ];

  const recentCols: Column<BroadcastRow>[] = [
    { key: 'broadcast_code', header: 'Code' },
    { key: 'title', header: 'Title' },
    { key: 'channel', header: 'Channel' },
    { key: 'audience_segment', header: 'Audience' },
    { key: 'topic_theme', header: 'Topic' },
    { key: 'sent_at', header: 'Sent at', render: (r) => fmtDate(r.sent_at) },
    { key: 'duration_minutes', header: 'Mins', render: (r) => fmtNum(r.duration_minutes) },
    { key: 'fully_consumed_count', header: 'Consumed', render: (r) => fmtNum(r.fully_consumed_count) },
    { key: 'avg_nps_score', header: 'NPS', render: (r) => fmtNps(r.avg_nps_score) },
    { key: 'tone_classification', header: 'Tone' },
    { key: 'effectiveness_band', header: 'Band' },
    { key: 'status', header: 'Status' },
  ];

  return (
    <div className="mx-auto max-w-7xl space-y-10 p-6">
      <header>
        <h1 className="text-2xl font-semibold">Founder Voice & Internal Comms Cadence Tracker</h1>
        <p className="mt-1 text-sm text-neutral-600">
          Channel x audience reach x open/listen x NPS x tone x follow-up rate. All-hands, Looms, memos.
        </p>
      </header>

      <section>
        <h2 className="mb-3 text-lg font-medium">Channel mix & consume rate</h2>
        <DataTable
          rows={channels}
          columns={channelCols}
          emptyMessage="No broadcasts logged yet"
          rowKey={(r, i) => String(r.channel ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Audience reach & follow-up completion</h2>
        <DataTable
          rows={audience}
          columns={audienceCols}
          emptyMessage="No audience data"
          rowKey={(r, i) => String(r.audience_segment ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Cadence slot effectiveness</h2>
        <DataTable
          rows={cadence}
          columns={cadenceCols}
          emptyMessage="No cadence data"
          rowKey={(r, i) => String(r.cadence_slot ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Tone vs clarity/alignment outcome</h2>
        <DataTable
          rows={tone}
          columns={toneCols}
          emptyMessage="No tone data"
          rowKey={(r, i) => String(r.tone_classification ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Follow-up action completion (lowest first)</h2>
        <DataTable
          rows={followup}
          columns={followupCols}
          emptyMessage="No follow-up actions"
          rowKey={(r, i) => String(r.broadcast_code ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Language reach & resonance</h2>
        <DataTable
          rows={langs}
          columns={langCols}
          emptyMessage="No language data"
          rowKey={(r, i) => String(r.language_primary ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Role concern hotspots</h2>
        <DataTable
          rows={roles}
          columns={roleCols}
          emptyMessage="No feedback"
          rowKey={(r, i) => String(r.responder_role ?? i)}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-medium">Recent broadcasts feed</h2>
        <DataTable
          rows={recent}
          columns={recentCols}
          emptyMessage="No broadcasts"
          rowKey={(r, i) => String(r.broadcast_code ?? i)}
        />
      </section>
    </div>
  );
}