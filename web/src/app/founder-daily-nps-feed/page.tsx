import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtNum(n: any): string {
  if (n === null || n === undefined) return "—";
  return String(n);
}

function fmtPct(n: any): string {
  if (n === null || n === undefined) return "—";
  return `${n}%`;
}

function fmtTs(ts: any): string {
  if (!ts) return "—";
  try { return new Date(ts).toLocaleString(); } catch { return String(ts); }
}

export default async function FounderDailyNpsFeedPage() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let recent: any[] = [];
  let detractors: any[] = [];
  let bySource: any[] = [];
  let triageLog: any[] = [];

  try {
    const r = await sb.rpc('rpc_founder_nps_feed_kpis');
    kpis = (r.data && r.data[0]) || {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('rpc_founder_nps_feed_recent', { p_limit: 50 });
    recent = r.data || [];
  } catch { recent = []; }

  try {
    const r = await sb.rpc('rpc_founder_nps_detractor_queue');
    detractors = r.data || [];
  } catch { detractors = []; }

  try {
    const r = await sb.rpc('rpc_founder_nps_by_source');
    bySource = r.data || [];
  } catch { bySource = []; }

  try {
    const r = await sb.rpc('rpc_founder_nps_recent_triage');
    triageLog = r.data || [];
  } catch { triageLog = []; }

  try { await sb.rpc('log_founder_nps_view', { p_filter: '24h' }); } catch {}

  const cards: Kpi[] = [
    { label: 'Responses 24h', value: fmtNum(kpis.total_24h) },
    { label: 'Hospital 24h', value: fmtNum(kpis.hospital_count_24h) },
    { label: 'Engineer 24h', value: fmtNum(kpis.engineer_count_24h) },
    { label: 'Detractors 24h', value: fmtNum(kpis.detractor_24h) },
    { label: 'Passives 24h', value: fmtNum(kpis.passive_24h) },
    { label: 'Promoters 24h', value: fmtNum(kpis.promoter_24h) },
    { label: 'NPS 24h', value: fmtNum(kpis.nps_score_24h) },
    { label: 'Detractor %', value: fmtPct(kpis.detractor_pct_24h) },
    { label: 'Promoter %', value: fmtPct(kpis.promoter_pct_24h) },
    { label: 'Triage open', value: fmtNum(kpis.detractor_open) },
    { label: 'Triage overdue', value: fmtNum(kpis.detractor_overdue) },
    { label: 'Resolved 24h', value: fmtNum(kpis.detractor_resolved_24h) },
    { label: 'Median triage (min)', value: fmtNum(kpis.median_triage_minutes) },
    { label: 'SLA breached 24h', value: fmtNum(kpis.sla_breached_24h) },
    { label: 'Responses 7d', value: fmtNum(kpis.total_7d) },
    { label: 'NPS 7d', value: fmtNum(kpis.nps_score_7d) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'recorded_at', header: 'When', render: (r: any) => fmtTs(r.recorded_at) },
    { key: 'source_kind', header: 'Source', render: (r: any) => r.source_kind ?? "—" },
    { key: 'nps_score', header: 'Score', render: (r: any) => fmtNum(r.nps_score) },
    { key: 'bucket', header: 'Bucket', render: (r: any) => r.bucket ?? "—" },
    { key: 'responder_email', header: 'Responder', render: (r: any) => r.responder_email ?? "—" },
    { key: 'org_name', header: 'Org', render: (r: any) => r.org_name ?? "—" },
    { key: 'verbatim_text', header: 'Verbatim', render: (r: any) => r.verbatim_text ?? "—" },
    { key: 'age_minutes', header: 'Age (min)', render: (r: any) => fmtNum(r.age_minutes) },
    { key: 'triaged', header: 'Triaged', render: (r: any) => r.triaged ? 'yes' : 'no' },
  ];

  const detractorCols: Column<any>[] = [
    { key: 'recorded_at', header: 'When', render: (r: any) => fmtTs(r.recorded_at) },
    { key: 'source_kind', header: 'Source', render: (r: any) => r.source_kind ?? "—" },
    { key: 'nps_score', header: 'Score', render: (r: any) => fmtNum(r.nps_score) },
    { key: 'responder_email', header: 'Responder', render: (r: any) => r.responder_email ?? "—" },
    { key: 'org_name', header: 'Org', render: (r: any) => r.org_name ?? "—" },
    { key: 'verbatim_text', header: 'Verbatim', render: (r: any) => r.verbatim_text ?? "—" },
    { key: 'triage_due_at', header: 'Due', render: (r: any) => fmtTs(r.triage_due_at) },
    { key: 'minutes_to_due', header: 'Min to due', render: (r: any) => fmtNum(r.minutes_to_due) },
    { key: 'overdue', header: 'Overdue', render: (r: any) => r.overdue ? 'YES' : 'no' },
  ];

  const bySourceCols: Column<any>[] = [
    { key: 'source_kind', header: 'Source', render: (r: any) => r.source_kind ?? "—" },
    { key: 'total_24h', header: 'Total 24h', render: (r: any) => fmtNum(r.total_24h) },
    { key: 'detractors', header: 'Detractors', render: (r: any) => fmtNum(r.detractors) },
    { key: 'passives', header: 'Passives', render: (r: any) => fmtNum(r.passives) },
    { key: 'promoters', header: 'Promoters', render: (r: any) => fmtNum(r.promoters) },
    { key: 'nps_score', header: 'NPS', render: (r: any) => fmtNum(r.nps_score) },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => fmtNum(r.avg_score) },
  ];

  const triageCols: Column<any>[] = [
    { key: 'created_at', header: 'When', render: (r: any) => fmtTs(r.created_at) },
    { key: 'action', header: 'Action', render: (r: any) => r.action ?? "—" },
    { key: 'actor_email', header: 'Actor', render: (r: any) => r.actor_email ?? "—" },
    { key: 'source_kind', header: 'Source', render: (r: any) => r.source_kind ?? "—" },
    { key: 'nps_score', header: 'Score', render: (r: any) => fmtNum(r.nps_score) },
    { key: 'notes', header: 'Notes', render: (r: any) => r.notes ?? "—" },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-semibold">Founder Daily NPS Feed</h1>
        <p className="text-sm text-gray-600">Live NPS responses across hospitals + engineers. Triage detractors within 2h SLA.</p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map((k) => (
          <div key={k.label} className="rounded border p-3">
            <div className="text-xs text-gray-500">{k.label}</div>
            <div className="text-lg font-semibold">{k.value}</div>
          </div>
        ))}
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Detractor triage queue (open)</h2>
        <DataTable columns={detractorCols} rows={detractors} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent 24h responses</h2>
        <DataTable columns={recentCols} rows={recent} rowKey={(r: any) => r.id} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By source (24h)</h2>
        <DataTable columns={bySourceCols} rows={bySource} rowKey={(r: any) => r.source_kind} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Recent triage log</h2>
        <DataTable columns={triageCols} rows={triageLog} rowKey={(r: any) => r.log_id} />
      </section>
    </div>
  );
}
