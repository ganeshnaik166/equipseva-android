import { requireFounder } from '@/lib/auth/requireFounder';
import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Kpi = { label: string; value: string };

function fmt(n: any): string {
  if (n === null || n === undefined) return '—';
  if (typeof n === 'number') return n.toLocaleString('en-IN');
  return String(n);
}

function fmtTs(t: any): string {
  if (!t) return '—';
  try { return new Date(t).toLocaleString('en-IN'); } catch { return '—'; }
}

export default async function Page() {
  await requireFounder();
  const sb = await getSupabaseServerClient();

  let kpis: any = {};
  let quarters: any[] = [];
  let objectives: any[] = [];
  let recipes: any[] = [];
  let trend: any[] = [];

  try {
    const r = await sb.rpc('founder_okr_eoq_kpis');
    kpis = (r.data as any) ?? {};
  } catch { kpis = {}; }

  try {
    const r = await sb.rpc('founder_okr_eoq_quarters');
    quarters = (r.data as any[]) ?? [];
  } catch { quarters = []; }

  const latestQ = quarters[0]?.quarter_label ?? null;

  if (latestQ) {
    try {
      const r = await sb.rpc('founder_okr_eoq_objectives', { p_quarter_label: latestQ });
      objectives = (r.data as any[]) ?? [];
    } catch { objectives = []; }
  }

  try {
    const r = await sb.rpc('founder_okr_eoq_recipe_analysis');
    recipes = (r.data as any[]) ?? [];
  } catch { recipes = []; }

  try {
    const r = await sb.rpc('founder_okr_eoq_grade_trend');
    trend = (r.data as any[]) ?? [];
  } catch { trend = []; }

  const cards: Kpi[] = [
    { label: 'Quarters total',       value: fmt(kpis.quarters_total) },
    { label: 'Quarters closed',      value: fmt(kpis.quarters_closed) },
    { label: 'Quarters open',        value: fmt(kpis.quarters_open) },
    { label: 'Objectives total',     value: fmt(kpis.objectives_total) },
    { label: 'Grade A',              value: fmt(kpis.objectives_a) },
    { label: 'Grade B',              value: fmt(kpis.objectives_b) },
    { label: 'Grade C',              value: fmt(kpis.objectives_c) },
    { label: 'Grade D',              value: fmt(kpis.objectives_d) },
    { label: 'Grade F',              value: fmt(kpis.objectives_f) },
    { label: 'GPA lifetime',         value: fmt(kpis.gpa_lifetime) },
    { label: 'GPA last quarter',     value: fmt(kpis.gpa_last_quarter) },
    { label: 'Top recipe tag',       value: fmt(kpis.top_recipe_tag) },
    { label: 'Recipe tags distinct', value: fmt(kpis.recipe_tags_distinct) },
    { label: 'Objectives no recipe', value: fmt(kpis.objectives_no_recipe) },
    { label: 'Last grade at',        value: fmtTs(kpis.last_grade_at) },
    { label: 'Last retro close at',  value: fmtTs(kpis.last_retro_close_at) },
  ];

  const qCols: Column<any>[] = [
    { key: 'quarter_label',    header: 'Quarter',   render: (r: any) => r.quarter_label ?? '—' },
    { key: 'quarter_start',    header: 'Start',     render: (r: any) => r.quarter_start ?? '—' },
    { key: 'quarter_end',      header: 'End',       render: (r: any) => r.quarter_end ?? '—' },
    { key: 'aggregate_letter', header: 'Letter',    render: (r: any) => r.aggregate_letter ?? '—' },
    { key: 'aggregate_gpa',    header: 'GPA',       render: (r: any) => fmt(r.aggregate_gpa) },
    { key: 'objectives_count', header: 'Objs',      render: (r: any) => fmt(r.objectives_count) },
    { key: 'top_recipe_tag',   header: 'Recipe',    render: (r: any) => r.top_recipe_tag ?? '—' },
    { key: 'closed_at',        header: 'Closed',    render: (r: any) => fmtTs(r.closed_at) },
  ];

  const oCols: Column<any>[] = [
    { key: 'objective_key',   header: 'Key',     render: (r: any) => r.objective_key ?? '—' },
    { key: 'objective_title', header: 'Title',   render: (r: any) => r.objective_title ?? '—' },
    { key: 'grade',           header: 'Grade',   render: (r: any) => r.grade ?? '—' },
    { key: 'grade_points',    header: 'Points',  render: (r: any) => fmt(r.grade_points) },
    { key: 'weight',          header: 'Weight',  render: (r: any) => fmt(r.weight) },
    { key: 'recipe_tag',      header: 'Recipe',  render: (r: any) => r.recipe_tag ?? '—' },
    { key: 'target_text',     header: 'Target',  render: (r: any) => r.target_text ?? '—' },
    { key: 'actual_text',     header: 'Actual',  render: (r: any) => r.actual_text ?? '—' },
  ];

  const rCols: Column<any>[] = [
    { key: 'recipe_tag',    header: 'Recipe',      render: (r: any) => r.recipe_tag ?? '—' },
    { key: 'occurrences',   header: 'Occurrences', render: (r: any) => fmt(r.occurrences) },
    { key: 'avg_gpa',       header: 'Avg GPA',     render: (r: any) => fmt(r.avg_gpa) },
    { key: 'best_grade',    header: 'Best',        render: (r: any) => r.best_grade ?? '—' },
    { key: 'worst_grade',   header: 'Worst',       render: (r: any) => r.worst_grade ?? '—' },
    { key: 'quarters_seen', header: 'Quarters',    render: (r: any) => fmt(r.quarters_seen) },
  ];

  const tCols: Column<any>[] = [
    { key: 'quarter_label', header: 'Quarter', render: (r: any) => r.quarter_label ?? '—' },
    { key: 'a_count',       header: 'A',       render: (r: any) => fmt(r.a_count) },
    { key: 'b_count',       header: 'B',       render: (r: any) => fmt(r.b_count) },
    { key: 'c_count',       header: 'C',       render: (r: any) => fmt(r.c_count) },
    { key: 'd_count',       header: 'D',       render: (r: any) => fmt(r.d_count) },
    { key: 'f_count',       header: 'F',       render: (r: any) => fmt(r.f_count) },
    { key: 'gpa',           header: 'GPA',     render: (r: any) => fmt(r.gpa) },
  ];

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-2xl font-bold">Founder OKR — End-of-Quarter Retro</h1>
        <p className="text-sm text-gray-600">Grade every objective A/B/C/D/F · roll up to quarter GPA · spot the recipes that keep working.</p>
      </div>

      <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
        {cards.map((c) => (
          <div key={c.label} className="rounded-lg border p-3 bg-white">
            <div className="text-xs text-gray-500">{c.label}</div>
            <div className="text-lg font-semibold">{c.value}</div>
          </div>
        ))}
      </div>

      <div>
        <h2 className="text-lg font-semibold mb-2">Quarter summaries</h2>
        <DataTable rows={quarters} columns={qCols} rowKey={(r: any) => r.quarter_label} />
      </div>

      <div>
        <h2 className="text-lg font-semibold mb-2">Objectives — latest quarter {latestQ ? '(' + latestQ + ')' : ''}</h2>
        <DataTable rows={objectives} columns={oCols} rowKey={(r: any) => r.id} />
      </div>

      <div>
        <h2 className="text-lg font-semibold mb-2">Recipe analysis</h2>
        <DataTable rows={recipes} columns={rCols} rowKey={(r: any) => r.recipe_tag} />
      </div>

      <div>
        <h2 className="text-lg font-semibold mb-2">Grade distribution trend</h2>
        <DataTable rows={trend} columns={tCols} rowKey={(r: any) => r.quarter_label} />
      </div>
    </div>
  );
}
