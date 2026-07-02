import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmtInt(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return new Intl.NumberFormat('en-IN').format(n);
}

function fmtRupees(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  if (n >= 10000000) return '₹' + (n / 10000000).toFixed(2) + ' Cr';
  if (n >= 100000) return '₹' + (n / 100000).toFixed(2) + ' L';
  return '₹' + new Intl.NumberFormat('en-IN').format(n);
}

function fmtPct(n: number | null | undefined): string {
  if (n === null || n === undefined) return '—';
  return n.toFixed(0) + '%';
}

function fmtDate(iso: string | null | undefined): string {
  if (!iso) return '—';
  try {
    return new Date(iso).toLocaleDateString('en-IN', { day: '2-digit', month: 'short' });
  } catch {
    return '—';
  }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  const [beatsRes, critiqueRes, summaryRes, proofRes] = await Promise.all([
    sb.rpc('rpc_investor_narrative_beats_list'),
    sb.rpc('rpc_investor_narrative_critique_list'),
    sb.rpc('rpc_investor_narrative_readiness_summary'),
    sb.rpc('rpc_investor_narrative_proof_metrics'),
  ]);

  const beats = (beatsRes.data ?? []) as any[];
  const critique = (critiqueRes.data ?? []) as any[];
  const summary = (summaryRes.data ?? []) as any[];
  const proofs = (proofRes.data ?? []) as any[];

  const totalBeats = beats.length;
  const ready = beats.filter((b) => b.readiness_status === 'ready').length;
  const inReview = beats.filter((b) => b.readiness_status === 'in_review').length;
  const draft = beats.filter((b) => b.readiness_status === 'draft').length;
  const blocked = beats.filter((b) => b.readiness_status === 'blocked').length;
  const pctReady = totalBeats > 0 ? (ready / totalBeats) * 100 : 0;
  const avgScore =
    totalBeats > 0
      ? beats.reduce((a, b) => a + (b.readiness_score ?? 0), 0) / totalBeats
      : 0;

  const critOpen = critique.filter((c) => !c.resolved_at).length;
  const critBlockers = critique.filter((c) => !c.resolved_at && c.severity === 'blocker').length;
  const critMedium = critique.filter((c) => !c.resolved_at && c.severity === 'medium').length;
  const critNits = critique.filter((c) => !c.resolved_at && c.severity === 'nit').length;
  const critResolved = critique.filter((c) => !!c.resolved_at).length;

  const beatsWithProof = beats.filter((b) => b.proof_metric_label).length;
  const beatsWithStoryline = beats.filter((b) => (b.storyline_chars ?? 0) > 0).length;
  const categories = summary.length;

  const lastEdit = beats
    .map((b) => b.last_edited_at)
    .filter(Boolean)
    .sort()
    .reverse()[0];

  const kpis: Kpi[] = [
    { label: 'Total beats', value: fmtInt(totalBeats) },
    { label: 'Ready', value: fmtInt(ready) },
    { label: 'In review', value: fmtInt(inReview) },
    { label: 'Draft', value: fmtInt(draft) },
    { label: 'Blocked', value: fmtInt(blocked) },
    { label: '% ready', value: fmtPct(pctReady) },
    { label: 'Avg readiness score', value: avgScore.toFixed(1) },
    { label: 'Categories', value: fmtInt(categories) },
    { label: 'Beats with proof metric', value: fmtInt(beatsWithProof) },
    { label: 'Beats with storyline', value: fmtInt(beatsWithStoryline) },
    { label: 'Critique items open', value: fmtInt(critOpen) },
    { label: 'Blockers open', value: fmtInt(critBlockers) },
    { label: 'Mediums open', value: fmtInt(critMedium) },
    { label: 'Nits open', value: fmtInt(critNits) },
    { label: 'Critique resolved', value: fmtInt(critResolved) },
    { label: 'Last edit', value: fmtDate(lastEdit) },
  ];

  const beatsCols: Column<any>[] = [
    { key: 'beat_order', header: '#', render: (r: any) => fmtInt(r.beat_order) },
    { key: 'beat_title', header: 'Beat', render: (r: any) => r.beat_title ?? '—' },
    { key: 'beat_category', header: 'Category', render: (r: any) => r.beat_category ?? '—' },
    { key: 'readiness_status', header: 'Status', render: (r: any) => r.readiness_status ?? '—' },
    { key: 'readiness_score', header: 'Score', render: (r: any) => fmtInt(r.readiness_score) },
    { key: 'storyline_chars', header: 'Storyline chars', render: (r: any) => fmtInt(r.storyline_chars) },
    { key: 'proof_metric_label', header: 'Proof metric', render: (r: any) => r.proof_metric_label ?? '—' },
    { key: 'owner_label', header: 'Owner', render: (r: any) => r.owner_label ?? '—' },
    { key: 'last_edited_at', header: 'Last edit', render: (r: any) => fmtDate(r.last_edited_at) },
  ];

  const summaryCols: Column<any>[] = [
    { key: 'beat_category', header: 'Category', render: (r: any) => r.beat_category ?? '—' },
    { key: 'beats_total', header: 'Total', render: (r: any) => fmtInt(r.beats_total) },
    { key: 'beats_ready', header: 'Ready', render: (r: any) => fmtInt(r.beats_ready) },
    { key: 'beats_blocked', header: 'Blocked', render: (r: any) => fmtInt(r.beats_blocked) },
    { key: 'avg_score', header: 'Avg score', render: (r: any) => (r.avg_score === null || r.avg_score === undefined ? '—' : Number(r.avg_score).toFixed(1)) },
  ];

  const proofCols: Column<any>[] = [
    { key: 'beat_title', header: 'Beat', render: (r: any) => r.beat_title ?? '—' },
    { key: 'proof_metric_label', header: 'Metric', render: (r: any) => r.proof_metric_label ?? '—' },
    { key: 'proof_metric_value_rupees', header: 'Value (₹)', render: (r: any) => fmtRupees(r.proof_metric_value_rupees) },
    { key: 'proof_metric_value_count', header: 'Value (count)', render: (r: any) => fmtInt(r.proof_metric_value_count) },
    { key: 'readiness_status', header: 'Status', render: (r: any) => r.readiness_status ?? '—' },
  ];

  const critiqueCols: Column<any>[] = [
    { key: 'beat_title', header: 'Beat', render: (r: any) => r.beat_title ?? '—' },
    { key: 'severity', header: 'Severity', render: (r: any) => r.severity ?? '—' },
    { key: 'critique_text', header: 'Critique', render: (r: any) => r.critique_text ?? '—' },
    { key: 'resolved_at', header: 'Resolved', render: (r: any) => (r.resolved_at ? fmtDate(r.resolved_at) : 'open') },
    { key: 'created_at', header: 'Created', render: (r: any) => fmtDate(r.created_at) },
  ];

  return (
    <main className="mx-auto max-w-7xl px-4 py-8">
      <header className="mb-6">
        <h1 className="text-2xl font-semibold">Investor next-round narrative tracker</h1>
        <p className="text-sm text-neutral-600 mt-1">
          Twelve narrative beats for the next fundraise pitch. Track storyline, proof metrics, readiness, and founder critique.
        </p>
      </header>

      <section className="grid grid-cols-2 sm:grid-cols-4 lg:grid-cols-8 gap-3 mb-8">
        {kpis.map((k) => (
          <div key={k.label} className="rounded-lg border border-neutral-200 bg-white px-3 py-3">
            <div className="text-[11px] uppercase tracking-wide text-neutral-500">{k.label}</div>
            <div className="text-lg font-semibold mt-1">{k.value}</div>
          </div>
        ))}
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">12 narrative beats</h2>
        <DataTable columns={beatsCols} rows={beats} rowKey={(r: any) => r.id} />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Readiness by category</h2>
        <DataTable columns={summaryCols} rows={summary} rowKey={(r: any) => r.beat_category} />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Proof metrics</h2>
        <DataTable columns={proofCols} rows={proofs} rowKey={(r: any) => r.beat_title} />
      </section>

      <section className="mb-8">
        <h2 className="text-lg font-semibold mb-3">Founder critique log</h2>
        <DataTable columns={critiqueCols} rows={critique} rowKey={(r: any) => r.id} />
      </section>
    </main>
  );
}
