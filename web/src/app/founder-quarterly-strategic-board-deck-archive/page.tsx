import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Deck = {
  deck_code: string;
  quarter_label: string;
  meeting_date: string;
  meeting_kind: string;
  slide_count: number;
  key_slide_title: string;
  key_metric: string;
  decision_summary: string;
  follow_up_owner: string;
  follow_up_due: string;
  archive_verdict: string;
  confidence_score: number;
};

type Followup = {
  deck_code: string;
  action_item: string;
  status: string;
  owner_role: string;
  raised_on: string;
  closed_on: string | null;
  impact_rupees: number;
  notes: string;
};

type Verdict = { archive_verdict: string; deck_count: number; avg_confidence: number };
type StatusRow = { status: string; item_count: number; total_impact_rupees: number };
type Kind = { meeting_kind: string; deck_count: number; total_slides: number };
type Overdue = {
  deck_code: string;
  action_item: string;
  owner_role: string;
  raised_on: string;
  days_open: number;
  impact_rupees: number;
  status: string;
};
type DeckCount = {
  deck_code: string;
  quarter_label: string;
  archive_verdict: string;
  total_followups: number;
  open_count: number;
  done_count: number;
  total_impact: number;
};

type Kpi = {
  total_decks: number;
  canonical_decks: number;
  draft_decks: number;
  total_followups: number;
  open_followups: number;
  blocked_followups: number;
  avg_confidence: number;
  total_impact_rupees: number;
};

function inr(n: number) {
  return new Intl.NumberFormat('en-IN').format(n ?? 0);
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [decksRes, followRes, verdictRes, statusRes, kpiRes, kindRes, overdueRes, deckCountRes] = await Promise.all([
    supabase.rpc('r2801_list_decks'),
    supabase.rpc('r2801_list_followups'),
    supabase.rpc('r2801_verdict_breakdown'),
    supabase.rpc('r2801_followup_status_summary'),
    supabase.rpc('r2801_kpi_summary'),
    supabase.rpc('r2801_meeting_kind_distribution'),
    supabase.rpc('r2801_overdue_followups'),
    supabase.rpc('r2801_deck_with_followup_counts'),
  ]);

  const decks: Deck[] = (decksRes.data as Deck[]) ?? [];
  const followups: Followup[] = (followRes.data as Followup[]) ?? [];
  const verdicts: Verdict[] = (verdictRes.data as Verdict[]) ?? [];
  const statuses: StatusRow[] = (statusRes.data as StatusRow[]) ?? [];
  const kinds: Kind[] = (kindRes.data as Kind[]) ?? [];
  const overdue: Overdue[] = (overdueRes.data as Overdue[]) ?? [];
  const deckCounts: DeckCount[] = (deckCountRes.data as DeckCount[]) ?? [];
  const kpi: Kpi = ((kpiRes.data as Kpi[]) ?? [])[0] ?? {
    total_decks: 0,
    canonical_decks: 0,
    draft_decks: 0,
    total_followups: 0,
    open_followups: 0,
    blocked_followups: 0,
    avg_confidence: 0,
    total_impact_rupees: 0,
  };

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Founder · Quarterly Strategic Board Deck Archive</h1>
        <p className="text-sm text-gray-600">
          Deck × meeting × key slide × decision × follow-up × archive verdict. Canonical
          decks score &gt;= 90 confidence; drafts sit &lt; 70 until CFO sign-off.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Total decks</div>
          <div className="text-xl font-semibold">{kpi.total_decks}</div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Canonical / Draft</div>
          <div className="text-xl font-semibold">
            {kpi.canonical_decks} / {kpi.draft_decks}
          </div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Follow-ups (open + blocked)</div>
          <div className="text-xl font-semibold">
            {kpi.open_followups + kpi.blocked_followups} / {kpi.total_followups}
          </div>
        </div>
        <div className="rounded-lg border p-4">
          <div className="text-xs text-gray-500">Avg confidence</div>
          <div className="text-xl font-semibold">{Number(kpi.avg_confidence ?? 0).toFixed(2)}</div>
        </div>
        <div className="rounded-lg border p-4 col-span-2 md:col-span-4">
          <div className="text-xs text-gray-500">Total follow-up impact tracked</div>
          <div className="text-xl font-semibold">Rs {inr(kpi.total_impact_rupees)}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Archive verdict breakdown</h2>
        <DataTable
          rows={verdicts}
          columns={[
            { key: 'archive_verdict', header: 'Verdict', render: (r: Verdict) => r.archive_verdict },
            { key: 'deck_count', header: 'Decks', render: (r: Verdict) => r.deck_count },
            {
              key: 'avg_confidence',
              header: 'Avg confidence',
              render: (r: Verdict) => Number(r.avg_confidence ?? 0).toFixed(2),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: Verdict, i: number) => String(r.archive_verdict ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Follow-up status summary</h2>
        <DataTable
          rows={statuses}
          columns={[
            { key: 'status', header: 'Status', render: (r: StatusRow) => r.status },
            { key: 'item_count', header: 'Items', render: (r: StatusRow) => r.item_count },
            {
              key: 'total_impact_rupees',
              header: 'Impact (Rs)',
              render: (r: StatusRow) => inr(r.total_impact_rupees),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: StatusRow, i: number) => String(r.status ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Meeting kind distribution</h2>
        <DataTable
          rows={kinds}
          columns={[
            { key: 'meeting_kind', header: 'Kind', render: (r: Kind) => r.meeting_kind },
            { key: 'deck_count', header: 'Decks', render: (r: Kind) => r.deck_count },
            { key: 'total_slides', header: 'Total slides', render: (r: Kind) => r.total_slides },
          ]}
          emptyMessage="No data"
          rowKey={(r: Kind, i: number) => String(r.meeting_kind ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Deck archive (latest first)</h2>
        <DataTable
          rows={decks}
          columns={[
            { key: 'deck_code', header: 'Deck', render: (r: Deck) => r.deck_code },
            { key: 'quarter_label', header: 'Quarter', render: (r: Deck) => r.quarter_label },
            { key: 'meeting_date', header: 'Meeting', render: (r: Deck) => r.meeting_date },
            { key: 'meeting_kind', header: 'Kind', render: (r: Deck) => r.meeting_kind },
            { key: 'slide_count', header: 'Slides', render: (r: Deck) => r.slide_count },
            { key: 'key_slide_title', header: 'Key slide', render: (r: Deck) => r.key_slide_title },
            { key: 'key_metric', header: 'Metric', render: (r: Deck) => r.key_metric },
            { key: 'decision_summary', header: 'Decision', render: (r: Deck) => r.decision_summary },
            { key: 'follow_up_owner', header: 'Owner', render: (r: Deck) => r.follow_up_owner },
            { key: 'follow_up_due', header: 'Due', render: (r: Deck) => r.follow_up_due },
            { key: 'archive_verdict', header: 'Verdict', render: (r: Deck) => r.archive_verdict },
            {
              key: 'confidence_score',
              header: 'Conf.',
              render: (r: Deck) => Number(r.confidence_score ?? 0).toFixed(2),
            },
          ]}
          emptyMessage="No data"
          rowKey={(r: Deck, i: number) => String(r.deck_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Deck rollup with follow-up counts</h2>
        <DataTable
          rows={deckCounts}
          columns={[
            { key: 'deck_code', header: 'Deck', render: (r: DeckCount) => r.deck_code },
            { key: 'quarter_label', header: 'Quarter', render: (r: DeckCount) => r.quarter_label },
            { key: 'archive_verdict', header: 'Verdict', render: (r: DeckCount) => r.archive_verdict },
            { key: 'total_followups', header: 'Total f/u', render: (r: DeckCount) => r.total_followups },
            { key: 'open_count', header: 'Open', render: (r: DeckCount) => r.open_count },
            { key: 'done_count', header: 'Done', render: (r: DeckCount) => r.done_count },
            { key: 'total_impact', header: 'Impact (Rs)', render: (r: DeckCount) => inr(r.total_impact) },
          ]}
          emptyMessage="No data"
          rowKey={(r: DeckCount, i: number) => String(r.deck_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All follow-up actions</h2>
        <DataTable
          rows={followups}
          columns={[
            { key: 'deck_code', header: 'Deck', render: (r: Followup) => r.deck_code },
            { key: 'action_item', header: 'Action', render: (r: Followup) => r.action_item },
            { key: 'status', header: 'Status', render: (r: Followup) => r.status },
            { key: 'owner_role', header: 'Owner', render: (r: Followup) => r.owner_role },
            { key: 'raised_on', header: 'Raised', render: (r: Followup) => r.raised_on },
            { key: 'closed_on', header: 'Closed', render: (r: Followup) => r.closed_on ?? '-' },
            { key: 'impact_rupees', header: 'Impact (Rs)', render: (r: Followup) => inr(r.impact_rupees) },
            { key: 'notes', header: 'Notes', render: (r: Followup) => r.notes },
          ]}
          emptyMessage="No data"
          rowKey={(r: Followup, i: number) => String(`${r.deck_code}-${i}`)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Overdue follow-ups (open / in-progress / blocked)</h2>
        <p className="text-xs text-gray-500 mb-2">
          Days-open &gt;= 0 measured from raised date; sort descending so oldest unfinished items surface first.
        </p>
        <DataTable
          rows={overdue}
          columns={[
            { key: 'deck_code', header: 'Deck', render: (r: Overdue) => r.deck_code },
            { key: 'action_item', header: 'Action', render: (r: Overdue) => r.action_item },
            { key: 'owner_role', header: 'Owner', render: (r: Overdue) => r.owner_role },
            { key: 'raised_on', header: 'Raised', render: (r: Overdue) => r.raised_on },
            { key: 'days_open', header: 'Days open', render: (r: Overdue) => r.days_open },
            { key: 'impact_rupees', header: 'Impact (Rs)', render: (r: Overdue) => inr(r.impact_rupees) },
            { key: 'status', header: 'Status', render: (r: Overdue) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: Overdue, i: number) => String(`${r.deck_code}-${i}`)}
        />
      </section>
    </div>
  );
}
