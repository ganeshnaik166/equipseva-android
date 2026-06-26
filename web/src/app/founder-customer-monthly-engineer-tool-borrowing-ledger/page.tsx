import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = {
  total_events: number;
  total_loss_rupees: number;
  open_borrows: number;
  red_engineers: number;
};

type Event = {
  id: string;
  ledger_month: string;
  engineer_code: string;
  engineer_name: string;
  tool_code: string;
  tool_name: string;
  borrowed_from: string;
  borrowed_at: string;
  due_back_at: string;
  returned_at: string | null;
  return_condition: string;
  loss_value_rupees: number;
  verdict: string;
  notes: string | null;
};

type Scorecard = {
  id: string;
  ledger_month: string;
  engineer_code: string;
  engineer_name: string;
  borrow_count: number;
  on_time_returns: number;
  late_returns: number;
  damaged_count: number;
  lost_count: number;
  total_loss_rupees: number;
  risk_grade: string;
  recommended_action: string;
};

type MixRow = {
  borrowed_from?: string;
  return_condition?: string;
  verdict?: string;
  event_count: number;
  loss_rupees: number;
};

function rupees(n: number | null | undefined) {
  const v = Number(n ?? 0);
  return '₹' + v.toLocaleString('en-IN');
}

function fmtDate(iso: string | null) {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' });
  } catch {
    return iso;
  }
}

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [kpiRes, eventsRes, scoreRes, sourceRes, conditionRes, verdictRes, highRiskRes, openRes] = await Promise.all([
    supabase.rpc('founder_r2868_borrow_kpis'),
    supabase.rpc('founder_r2868_borrow_events'),
    supabase.rpc('founder_r2868_engineer_scorecard'),
    supabase.rpc('founder_r2868_borrow_source_mix'),
    supabase.rpc('founder_r2868_condition_mix'),
    supabase.rpc('founder_r2868_verdict_mix'),
    supabase.rpc('founder_r2868_high_risk_engineers'),
    supabase.rpc('founder_r2868_open_borrows'),
  ]);

  const kpi: Kpi = (kpiRes.data?.[0] as Kpi) ?? { total_events: 0, total_loss_rupees: 0, open_borrows: 0, red_engineers: 0 };
  const events: Event[] = (eventsRes.data as Event[]) ?? [];
  const scorecard: Scorecard[] = (scoreRes.data as Scorecard[]) ?? [];
  const sourceMix: MixRow[] = (sourceRes.data as MixRow[]) ?? [];
  const conditionMix: MixRow[] = (conditionRes.data as MixRow[]) ?? [];
  const verdictMix: MixRow[] = (verdictRes.data as MixRow[]) ?? [];
  const highRisk: Scorecard[] = (highRiskRes.data as Scorecard[]) ?? [];
  const openBorrows: Event[] = (openRes.data as Event[]) ?? [];

  return (
    <div className="p-6 space-y-6">
      <header>
        <h1 className="text-2xl font-bold">Engineer Tool Borrowing Ledger</h1>
        <p className="text-sm text-gray-600">
          Monthly audit of every engineer-tool checkout: borrowed from, returned, condition, loss & verdict.
        </p>
      </header>

      <section className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500">Total events</div>
          <div className="text-2xl font-bold">{kpi.total_events}</div>
        </div>
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500">Total loss</div>
          <div className="text-2xl font-bold">{rupees(kpi.total_loss_rupees)}</div>
        </div>
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500">Open borrows</div>
          <div className="text-2xl font-bold">{kpi.open_borrows}</div>
        </div>
        <div className="border rounded-lg p-4">
          <div className="text-xs text-gray-500">Red engineers</div>
          <div className="text-2xl font-bold">{kpi.red_engineers}</div>
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer scorecard</h2>
        <DataTable
          rows={scorecard}
          columns={[
            { key: 'engineer_code', header: 'Code', render: (r: Scorecard) => <span>{r.engineer_code}</span> },
            { key: 'engineer_name', header: 'Engineer', render: (r: Scorecard) => <span>{r.engineer_name}</span> },
            { key: 'borrow_count', header: 'Borrows', render: (r: Scorecard) => <span>{r.borrow_count}</span> },
            { key: 'on_time_returns', header: 'On-time', render: (r: Scorecard) => <span>{r.on_time_returns}</span> },
            { key: 'late_returns', header: 'Late', render: (r: Scorecard) => <span>{r.late_returns}</span> },
            { key: 'damaged_count', header: 'Damaged', render: (r: Scorecard) => <span>{r.damaged_count}</span> },
            { key: 'lost_count', header: 'Lost', render: (r: Scorecard) => <span>{r.lost_count}</span> },
            { key: 'total_loss_rupees', header: 'Loss', render: (r: Scorecard) => <span>{rupees(r.total_loss_rupees)}</span> },
            { key: 'risk_grade', header: 'Grade', render: (r: Scorecard) => <span className="uppercase">{r.risk_grade}</span> },
            { key: 'recommended_action', header: 'Action', render: (r: Scorecard) => <span>{r.recommended_action}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Scorecard, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">All borrow events</h2>
        <DataTable
          rows={events}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Event) => <span>{r.engineer_name}</span> },
            { key: 'tool_name', header: 'Tool', render: (r: Event) => <span>{r.tool_name}</span> },
            { key: 'borrowed_from', header: 'From', render: (r: Event) => <span>{r.borrowed_from}</span> },
            { key: 'borrowed_at', header: 'Borrowed', render: (r: Event) => <span>{fmtDate(r.borrowed_at)}</span> },
            { key: 'due_back_at', header: 'Due', render: (r: Event) => <span>{fmtDate(r.due_back_at)}</span> },
            { key: 'returned_at', header: 'Returned', render: (r: Event) => <span>{fmtDate(r.returned_at)}</span> },
            { key: 'return_condition', header: 'Condition', render: (r: Event) => <span>{r.return_condition}</span> },
            { key: 'loss_value_rupees', header: 'Loss', render: (r: Event) => <span>{rupees(r.loss_value_rupees)}</span> },
            { key: 'verdict', header: 'Verdict', render: (r: Event) => <span className="uppercase">{r.verdict}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Event, i: number) => String(r.id ?? i)}
        />
      </section>

      <section className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div>
          <h2 className="text-lg font-semibold mb-2">Source mix</h2>
          <DataTable
            rows={sourceMix}
            columns={[
              { key: 'borrowed_from', header: 'Source', render: (r: MixRow) => <span>{r.borrowed_from}</span> },
              { key: 'event_count', header: 'Events', render: (r: MixRow) => <span>{r.event_count}</span> },
              { key: 'loss_rupees', header: 'Loss', render: (r: MixRow) => <span>{rupees(r.loss_rupees)}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: MixRow, i: number) => String(i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Condition mix</h2>
          <DataTable
            rows={conditionMix}
            columns={[
              { key: 'return_condition', header: 'Condition', render: (r: MixRow) => <span>{r.return_condition}</span> },
              { key: 'event_count', header: 'Events', render: (r: MixRow) => <span>{r.event_count}</span> },
              { key: 'loss_rupees', header: 'Loss', render: (r: MixRow) => <span>{rupees(r.loss_rupees)}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: MixRow, i: number) => String(i)}
          />
        </div>
        <div>
          <h2 className="text-lg font-semibold mb-2">Verdict mix</h2>
          <DataTable
            rows={verdictMix}
            columns={[
              { key: 'verdict', header: 'Verdict', render: (r: MixRow) => <span>{r.verdict}</span> },
              { key: 'event_count', header: 'Events', render: (r: MixRow) => <span>{r.event_count}</span> },
              { key: 'loss_rupees', header: 'Loss', render: (r: MixRow) => <span>{rupees(r.loss_rupees)}</span> },
            ]}
            emptyMessage="No data"
            rowKey={(r: MixRow, i: number) => String(i)}
          />
        </div>
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">High-risk engineers (red & blacklist)</h2>
        <DataTable
          rows={highRisk}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Scorecard) => <span>{r.engineer_name}</span> },
            { key: 'risk_grade', header: 'Grade', render: (r: Scorecard) => <span className="uppercase">{r.risk_grade}</span> },
            { key: 'total_loss_rupees', header: 'Loss', render: (r: Scorecard) => <span>{rupees(r.total_loss_rupees)}</span> },
            { key: 'recommended_action', header: 'Action', render: (r: Scorecard) => <span>{r.recommended_action}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Scorecard, i: number) => String(r.id ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Open borrows (not returned)</h2>
        <DataTable
          rows={openBorrows}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Event) => <span>{r.engineer_name}</span> },
            { key: 'tool_name', header: 'Tool', render: (r: Event) => <span>{r.tool_name}</span> },
            { key: 'borrowed_from', header: 'From', render: (r: Event) => <span>{r.borrowed_from}</span> },
            { key: 'due_back_at', header: 'Due back', render: (r: Event) => <span>{fmtDate(r.due_back_at)}</span> },
            { key: 'loss_value_rupees', header: 'Loss exposure', render: (r: Event) => <span>{rupees(r.loss_value_rupees)}</span> },
            { key: 'verdict', header: 'Verdict', render: (r: Event) => <span className="uppercase">{r.verdict}</span> },
          ]}
          emptyMessage="No data"
          rowKey={(r: Event, i: number) => String(r.id ?? i)}
        />
      </section>
    </div>
  );
}
