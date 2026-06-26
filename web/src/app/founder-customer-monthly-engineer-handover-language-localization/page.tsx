import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

type Overview = {
  total_handovers: number;
  avg_quality: number;
  avg_comprehension: number;
  avg_satisfaction: number;
  clear_outcome_pct: number;
  retranslate_pct: number;
};

type ByLanguage = {
  target_language: string;
  sessions: number;
  avg_quality: number;
  avg_comprehension: number;
  avg_duration: number;
  outcome_clear: number;
};

type ByMethod = {
  translation_method: string;
  sessions: number;
  avg_quality: number;
  avg_satisfaction: number;
  avg_followups: number;
};

type RegionQuality = {
  language_code: string;
  region: string;
  total_handovers: number;
  avg_quality_score: number;
  native_engineer_pct: number;
  retranslate_rate_pct: number;
  status: string;
};

type AtRisk = {
  session_code: string;
  engineer_name: string;
  customer_org: string;
  target_language: string;
  quality_score: number;
  comprehension_score: number;
  outcome: string;
};

type Leader = {
  engineer_name: string;
  engineer_id_code: string;
  sessions: number;
  avg_quality: number;
  avg_satisfaction: number;
  clear_count: number;
};

type GlossaryGap = {
  language_code: string;
  region: string;
  glossary_terms_loaded: number;
  machine_fallback_pct: number;
  gap_severity: string;
};

type OutcomeMix = {
  outcome: string;
  sessions: number;
  share_pct: number;
  avg_followups: number;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    overviewRes,
    byLanguageRes,
    byMethodRes,
    regionRes,
    atRiskRes,
    leaderRes,
    glossaryRes,
    outcomeRes,
  ] = await Promise.all([
    supabase.rpc('founder_r2864_overview'),
    supabase.rpc('founder_r2864_by_language'),
    supabase.rpc('founder_r2864_by_method'),
    supabase.rpc('founder_r2864_region_quality'),
    supabase.rpc('founder_r2864_at_risk'),
    supabase.rpc('founder_r2864_engineer_leaderboard'),
    supabase.rpc('founder_r2864_glossary_gaps'),
    supabase.rpc('founder_r2864_outcome_mix'),
  ]);

  const overview = (overviewRes.data ?? [])[0] as Overview | undefined;
  const byLanguage = (byLanguageRes.data ?? []) as ByLanguage[];
  const byMethod = (byMethodRes.data ?? []) as ByMethod[];
  const region = (regionRes.data ?? []) as RegionQuality[];
  const atRisk = (atRiskRes.data ?? []) as AtRisk[];
  const leaders = (leaderRes.data ?? []) as Leader[];
  const glossary = (glossaryRes.data ?? []) as GlossaryGap[];
  const outcomes = (outcomeRes.data ?? []) as OutcomeMix[];

  return (
    <div className="p-6 space-y-6">
      <header className="space-y-1">
        <h1 className="text-2xl font-semibold">
          Customer Monthly Engineer Handover — Language Localization
        </h1>
        <p className="text-sm text-gray-600">
          Engineer × customer × language × translation quality × comprehension × outcome.
          Track whether monthly handovers actually land in the customer's native language.
        </p>
      </header>

      <section className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
        <Kpi label="Handovers" value={String(overview?.total_handovers ?? 0)} />
        <Kpi label="Avg Quality" value={`${overview?.avg_quality ?? 0} / 5`} />
        <Kpi label="Avg Comprehension" value={`${overview?.avg_comprehension ?? 0} / 5`} />
        <Kpi label="Avg Satisfaction" value={`${overview?.avg_satisfaction ?? 0} / 5`} />
        <Kpi label="Clear Outcome" value={`${overview?.clear_outcome_pct ?? 0}%`} />
        <Kpi label="Retranslate / Escalate" value={`${overview?.retranslate_pct ?? 0}%`} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Target Language</h2>
        <DataTable
          rows={byLanguage}
          columns={[
            { key: 'target_language', header: 'Language', render: (r: ByLanguage) => r.target_language },
            { key: 'sessions', header: 'Sessions', render: (r: ByLanguage) => String(r.sessions) },
            { key: 'avg_quality', header: 'Avg Quality', render: (r: ByLanguage) => String(r.avg_quality) },
            { key: 'avg_comprehension', header: 'Comprehension', render: (r: ByLanguage) => String(r.avg_comprehension) },
            { key: 'avg_duration', header: 'Avg Duration (min)', render: (r: ByLanguage) => String(r.avg_duration) },
            { key: 'outcome_clear', header: 'Clear', render: (r: ByLanguage) => String(r.outcome_clear) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByLanguage, i: number) => String(r.target_language ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">By Translation Method</h2>
        <DataTable
          rows={byMethod}
          columns={[
            { key: 'translation_method', header: 'Method', render: (r: ByMethod) => r.translation_method },
            { key: 'sessions', header: 'Sessions', render: (r: ByMethod) => String(r.sessions) },
            { key: 'avg_quality', header: 'Avg Quality', render: (r: ByMethod) => String(r.avg_quality) },
            { key: 'avg_satisfaction', header: 'Avg Satisfaction', render: (r: ByMethod) => String(r.avg_satisfaction) },
            { key: 'avg_followups', header: 'Avg Follow-ups', render: (r: ByMethod) => String(r.avg_followups) },
          ]}
          emptyMessage="No data"
          rowKey={(r: ByMethod, i: number) => String(r.translation_method ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Regional Language Quality</h2>
        <DataTable
          rows={region}
          columns={[
            { key: 'language_code', header: 'Language', render: (r: RegionQuality) => r.language_code },
            { key: 'region', header: 'Region', render: (r: RegionQuality) => r.region },
            { key: 'total_handovers', header: 'Handovers', render: (r: RegionQuality) => String(r.total_handovers) },
            { key: 'avg_quality_score', header: 'Avg Quality', render: (r: RegionQuality) => String(r.avg_quality_score) },
            { key: 'native_engineer_pct', header: 'Native Eng %', render: (r: RegionQuality) => `${r.native_engineer_pct}%` },
            { key: 'retranslate_rate_pct', header: 'Retranslate %', render: (r: RegionQuality) => `${r.retranslate_rate_pct}%` },
            { key: 'status', header: 'Status', render: (r: RegionQuality) => r.status },
          ]}
          emptyMessage="No data"
          rowKey={(r: RegionQuality, i: number) => String(r.language_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">At-Risk Sessions (quality &lt; 4.0 or escalated)</h2>
        <DataTable
          rows={atRisk}
          columns={[
            { key: 'session_code', header: 'Session', render: (r: AtRisk) => r.session_code },
            { key: 'engineer_name', header: 'Engineer', render: (r: AtRisk) => r.engineer_name },
            { key: 'customer_org', header: 'Customer', render: (r: AtRisk) => r.customer_org },
            { key: 'target_language', header: 'Language', render: (r: AtRisk) => r.target_language },
            { key: 'quality_score', header: 'Quality', render: (r: AtRisk) => String(r.quality_score) },
            { key: 'comprehension_score', header: 'Comprehension', render: (r: AtRisk) => String(r.comprehension_score) },
            { key: 'outcome', header: 'Outcome', render: (r: AtRisk) => r.outcome },
          ]}
          emptyMessage="No at-risk sessions"
          rowKey={(r: AtRisk, i: number) => String(r.session_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Engineer Leaderboard</h2>
        <DataTable
          rows={leaders}
          columns={[
            { key: 'engineer_name', header: 'Engineer', render: (r: Leader) => r.engineer_name },
            { key: 'engineer_id_code', header: 'ID', render: (r: Leader) => r.engineer_id_code },
            { key: 'sessions', header: 'Sessions', render: (r: Leader) => String(r.sessions) },
            { key: 'avg_quality', header: 'Avg Quality', render: (r: Leader) => String(r.avg_quality) },
            { key: 'avg_satisfaction', header: 'Avg Satisfaction', render: (r: Leader) => String(r.avg_satisfaction) },
            { key: 'clear_count', header: 'Clear', render: (r: Leader) => String(r.clear_count) },
          ]}
          emptyMessage="No engineers"
          rowKey={(r: Leader, i: number) => String(r.engineer_id_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Glossary Coverage Gaps</h2>
        <DataTable
          rows={glossary}
          columns={[
            { key: 'language_code', header: 'Language', render: (r: GlossaryGap) => r.language_code },
            { key: 'region', header: 'Region', render: (r: GlossaryGap) => r.region },
            { key: 'glossary_terms_loaded', header: 'Glossary Terms', render: (r: GlossaryGap) => String(r.glossary_terms_loaded) },
            { key: 'machine_fallback_pct', header: 'Machine Fallback %', render: (r: GlossaryGap) => `${r.machine_fallback_pct}%` },
            { key: 'gap_severity', header: 'Severity', render: (r: GlossaryGap) => r.gap_severity },
          ]}
          emptyMessage="No glossary data"
          rowKey={(r: GlossaryGap, i: number) => String(r.language_code ?? i)}
        />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-2">Outcome Mix</h2>
        <DataTable
          rows={outcomes}
          columns={[
            { key: 'outcome', header: 'Outcome', render: (r: OutcomeMix) => r.outcome },
            { key: 'sessions', header: 'Sessions', render: (r: OutcomeMix) => String(r.sessions) },
            { key: 'share_pct', header: 'Share %', render: (r: OutcomeMix) => `${r.share_pct}%` },
            { key: 'avg_followups', header: 'Avg Follow-ups', render: (r: OutcomeMix) => String(r.avg_followups) },
          ]}
          emptyMessage="No outcomes"
          rowKey={(r: OutcomeMix, i: number) => String(r.outcome ?? i)}
        />
      </section>
    </div>
  );
}

function Kpi({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-gray-200 bg-white p-4 shadow-sm">
      <div className="text-xs uppercase tracking-wide text-gray-500">{label}</div>
      <div className="mt-1 text-xl font-semibold text-gray-900">{value}</div>
    </div>
  );
}
