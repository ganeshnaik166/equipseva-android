import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Engineer skills matrix — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type SummaryRow = {
  total_skills: number;
  active_skills: number;
  critical_skills: number;
  high_skills: number;
  medium_skills: number;
  low_skills: number;
  total_engineers_assessed: number;
  total_proficiency_rows: number;
  expert_count: number;
  proficient_count: number;
  familiar_count: number;
  aware_count: number;
  trainer_count: number;
  founder_assessed_count: number;
  self_assessed_count: number;
  avg_skills_per_engineer: number;
  generated_at: string;
};

type TaxonomyRow = {
  id: string;
  skill_label: string;
  skill_kind: string;
  importance_band: string;
  is_active: boolean;
  engineers_with_skill: number;
  created_at: string;
};

type ProficiencyRow = {
  id: string;
  engineer_user_id: string;
  engineer_name: string;
  skill_label: string;
  skill_kind: string;
  importance_band: string;
  proficiency_level: string;
  self_assessed_at: string | null;
  founder_assessed_at: string | null;
  evidence_count: number;
  updated_at: string;
};

type CoverageRow = {
  skill_id: string;
  skill_label: string;
  skill_kind: string;
  importance_band: string;
  total_engineers: number;
  proficient_or_above: number;
  coverage_pct: number;
  expert_count: number;
  trainer_count: number;
};

function Card({ label, value, tone, sub }: { label: string; value: string | number; tone?: string; sub?: string }) {
  return (
    <div className={`rounded-lg border ${tone ?? "border-[var(--color-border)]"} bg-[var(--color-surface)] p-4`}>
      <div className="text-[10px] uppercase tracking-wider text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-2xl font-bold tabular-nums">{value}</div>
      {sub ? <div className="mt-1 text-[10px] text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

const BAND_TONE: Record<string, string> = {
  critical: "border-[var(--color-danger)] text-[var(--color-danger)]",
  high:     "border-[var(--color-warn)]   text-[var(--color-warn)]",
  medium:   "border-[var(--color-info)]   text-[var(--color-info)]",
  low:      "border-[var(--color-muted)]  text-[var(--color-muted)]",
};

const KIND_BADGE: Record<string, string> = {
  equipment_specific: "border-[var(--color-accent)] text-[var(--color-accent)]",
  technical_repair:   "border-[var(--color-info)]   text-[var(--color-info)]",
  calibration:        "border-[var(--color-info)]   text-[var(--color-info)]",
  soft_skill:         "border-[var(--color-muted)]  text-[var(--color-muted)]",
  language:           "border-[var(--color-muted)]  text-[var(--color-muted)]",
  certification:      "border-[var(--color-ok)]     text-[var(--color-ok)]",
  tool_proficiency:   "border-[var(--color-warn)]   text-[var(--color-warn)]",
  safety:             "border-[var(--color-danger)] text-[var(--color-danger)]",
};

const LEVEL_TONE: Record<string, string> = {
  none:       "text-[var(--color-muted)]",
  aware:      "text-[var(--color-muted)]",
  familiar:   "text-[var(--color-warn)]",
  proficient: "text-[var(--color-info)]",
  expert:     "text-[var(--color-ok)]",
  trainer:    "text-[var(--color-accent)]",
};

function coverageTone(pct: number, band: string): string {
  const floor = band === "critical" ? 70 : 50;
  if (pct >= floor)       return "text-[var(--color-ok)]";
  if (pct >= floor - 20)  return "text-[var(--color-warn)]";
  return "text-[var(--color-danger)]";
}

function coverageBorder(pct: number, band: string): string {
  const floor = band === "critical" ? 70 : 50;
  if (pct >= floor)       return "border-[var(--color-ok)]";
  if (pct >= floor - 20)  return "border-[var(--color-warn)]";
  return "border-[var(--color-danger)]";
}

function fmtAge(iso: string | null): string {
  if (!iso) return "—";
  const d = new Date(iso).getTime();
  const mins = Math.floor((Date.now() - d) / 60_000);
  if (mins < 60)   return `${mins}m ago`;
  if (mins < 1440) return `${Math.floor(mins / 60)}h ago`;
  return `${Math.floor(mins / 1440)}d ago`;
}

export default async function FounderEngineerSkillsMatrixPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, taxonomyRes, profRes, coverageRes] = await Promise.all([
    supabase.rpc("founder_engineer_skills_matrix_summary"),
    supabase.rpc("founder_engineer_skills_taxonomy_recent",       { p_limit: 80 }),
    supabase.rpc("founder_engineer_skills_proficiency_recent",    { p_limit: 80 }),
    supabase.rpc("founder_engineer_skills_critical_skill_coverage"),
  ]);
  if (summaryRes.error)  throw new Error(`founder_engineer_skills_matrix_summary: ${summaryRes.error.message}`);
  if (taxonomyRes.error) throw new Error(`founder_engineer_skills_taxonomy_recent: ${taxonomyRes.error.message}`);
  if (profRes.error)     throw new Error(`founder_engineer_skills_proficiency_recent: ${profRes.error.message}`);
  if (coverageRes.error) throw new Error(`founder_engineer_skills_critical_skill_coverage: ${coverageRes.error.message}`);

  const s        = ((summaryRes.data ?? [])[0] ?? {}) as SummaryRow;
  const taxonomy = (taxonomyRes.data ?? []) as TaxonomyRow[];
  const prof     = (profRes.data ?? []) as ProficiencyRow[];
  const coverage = (coverageRes.data ?? []) as CoverageRow[];

  const criticalWeak = coverage.filter((c) => c.importance_band === "critical" && Number(c.coverage_pct) < 70).length;
  const criticalTone = criticalWeak > 0 ? "border-[var(--color-danger)]" : "border-[var(--color-ok)]";

  // per-engineer grid: pivot prof rows by engineer
  const engineers = new Map<string, { name: string; rows: ProficiencyRow[] }>();
  for (const p of prof) {
    const e = engineers.get(p.engineer_user_id);
    if (e) e.rows.push(p);
    else   engineers.set(p.engineer_user_id, { name: p.engineer_name, rows: [p] });
  }

  return (
    <div className="space-y-6">
      <header>
        <h1 className="text-xl font-semibold">Engineer skills & competency matrix ★★★★ r1426</h1>
        <p className="text-xs text-[var(--color-muted)] mt-1">
          Skill taxonomy (8 kinds · 4 importance bands) + per-engineer proficiency (6 levels: none → trainer) +
          founder-verified critical-skill coverage. Register skills via{" "}
          <code className="font-mono">log_founder_skills_register_skill</code>, assess engineers via{" "}
          <code className="font-mono">log_founder_skills_assess_engineer</code>. Engineers self-view via{" "}
          <code className="font-mono">engineer_skills_my_proficiencies</code>.
        </p>
      </header>

      {criticalWeak > 0 ? (
        <div className={`rounded-lg border ${criticalTone} bg-[var(--color-surface)] p-4`}>
          <div className="text-[11px] uppercase tracking-wider text-[var(--color-danger)]">Critical skill gap</div>
          <div className="mt-1 text-sm">
            <span className="text-lg font-bold tabular-nums">{formatNumber(criticalWeak)}</span>{" "}
            <span className="text-[var(--color-muted)]">
              critical skills below 70% engineer coverage — training pipeline backlog.
            </span>
          </div>
        </div>
      ) : null}

      <section className="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-8 gap-3">
        <Card label="Total skills"        value={formatNumber(s.total_skills ?? 0)} />
        <Card label="Active"              value={formatNumber(s.active_skills ?? 0)} />
        <Card label="Critical"            value={formatNumber(s.critical_skills ?? 0)} tone="border-[var(--color-danger)]" />
        <Card label="High"                value={formatNumber(s.high_skills ?? 0)}     tone="border-[var(--color-warn)]" />
        <Card label="Medium"              value={formatNumber(s.medium_skills ?? 0)} />
        <Card label="Low"                 value={formatNumber(s.low_skills ?? 0)} />
        <Card label="Engineers assessed"  value={formatNumber(s.total_engineers_assessed ?? 0)} />
        <Card label="Total assessments"   value={formatNumber(s.total_proficiency_rows ?? 0)} />
        <Card label="Trainers"            value={formatNumber(s.trainer_count ?? 0)} tone="border-[var(--color-accent)]" sub="can teach others" />
        <Card label="Experts"             value={formatNumber(s.expert_count ?? 0)}  tone="border-[var(--color-ok)]" />
        <Card label="Proficient"          value={formatNumber(s.proficient_count ?? 0)} />
        <Card label="Familiar"            value={formatNumber(s.familiar_count ?? 0)} />
        <Card label="Aware"               value={formatNumber(s.aware_count ?? 0)} />
        <Card label="Founder-verified"    value={formatNumber(s.founder_assessed_count ?? 0)} sub="vs self-only" />
        <Card label="Self-assessed"       value={formatNumber(s.self_assessed_count ?? 0)} />
        <Card label="Avg skills / eng"    value={formatNumber(Number(s.avg_skills_per_engineer ?? 0))} sub="breadth indicator" />
      </section>

      <section>
        <div className="mb-2 text-sm font-semibold">
          Critical & high-importance skill coverage · {coverage.length} skill{coverage.length === 1 ? "" : "s"}
        </div>
        {coverage.length === 0 ? (
          <p className="text-xs text-[var(--color-muted)]">
            No critical or high skills in taxonomy yet — register via{" "}
            <code className="font-mono">log_founder_skills_register_skill(label, kind, 'critical')</code>.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-[var(--color-muted)] uppercase tracking-wider text-[10px]">
                <tr className="text-left">
                  <th className="py-2 pr-3">Skill</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Band</th>
                  <th className="py-2 pr-3 text-right">Engineers</th>
                  <th className="py-2 pr-3 text-right">Proficient+</th>
                  <th className="py-2 pr-3 text-right">Coverage</th>
                  <th className="py-2 pr-3 text-right">Expert</th>
                  <th className="py-2 pr-3 text-right">Trainer</th>
                </tr>
              </thead>
              <tbody>
                {coverage.map((c) => {
                  const pct = Number(c.coverage_pct ?? 0);
                  return (
                    <tr key={c.skill_id} className={`border-t border-l-2 ${coverageBorder(pct, c.importance_band)} border-r border-b border-[var(--color-border)]`}>
                      <td className="py-2 pr-3 pl-2 font-medium">{c.skill_label}</td>
                      <td className="py-2 pr-3">
                        <span className={`inline-block px-1.5 py-0.5 rounded border text-[10px] uppercase ${KIND_BADGE[c.skill_kind] ?? "border-[var(--color-border)]"}`}>
                          {c.skill_kind}
                        </span>
                      </td>
                      <td className="py-2 pr-3">
                        <span className={`inline-block px-1.5 py-0.5 rounded border text-[10px] uppercase ${BAND_TONE[c.importance_band] ?? "border-[var(--color-border)]"}`}>
                          {c.importance_band}
                        </span>
                      </td>
                      <td className="py-2 pr-3 text-right tabular-nums text-[var(--color-muted)]">
                        {formatNumber(c.total_engineers ?? 0)}
                      </td>
                      <td className="py-2 pr-3 text-right tabular-nums">
                        {formatNumber(c.proficient_or_above ?? 0)}
                      </td>
                      <td className={`py-2 pr-3 text-right tabular-nums font-semibold ${coverageTone(pct, c.importance_band)}`}>
                        {formatNumber(Math.round(pct))}%
                      </td>
                      <td className="py-2 pr-3 text-right tabular-nums text-[var(--color-ok)]">
                        {formatNumber(c.expert_count ?? 0)}
                      </td>
                      <td className="py-2 pr-3 text-right tabular-nums text-[var(--color-accent)]">
                        {formatNumber(c.trainer_count ?? 0)}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section>
        <div className="mb-2 text-sm font-semibold">
          Per-engineer proficiency grid · {engineers.size} engineer{engineers.size === 1 ? "" : "s"}
        </div>
        {engineers.size === 0 ? (
          <p className="text-xs text-[var(--color-muted)]">No proficiency assessments yet.</p>
        ) : (
          <div className="space-y-3">
            {Array.from(engineers.entries()).map(([uid, eng]) => (
              <div key={uid} className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-3">
                <div className="text-xs font-semibold mb-2">{eng.name}</div>
                <div className="flex flex-wrap gap-1.5">
                  {eng.rows.map((r) => (
                    <span
                      key={r.id}
                      title={`${r.skill_kind} · ${r.importance_band} · ${fmtAge(r.founder_assessed_at ?? r.self_assessed_at)}`}
                      className={`inline-block px-1.5 py-0.5 rounded border text-[10px] ${BAND_TONE[r.importance_band] ?? "border-[var(--color-border)]"}`}
                    >
                      {r.skill_label}{" "}
                      <span className={`font-semibold ${LEVEL_TONE[r.proficiency_level] ?? ""}`}>· {r.proficiency_level}</span>
                      {r.founder_assessed_at ? <span className="text-[var(--color-ok)]"> ✓</span> : null}
                    </span>
                  ))}
                </div>
              </div>
            ))}
          </div>
        )}
      </section>

      <section>
        <div className="mb-2 text-sm font-semibold">Skill taxonomy · {taxonomy.length}</div>
        {taxonomy.length === 0 ? (
          <p className="text-xs text-[var(--color-muted)]">No skills registered yet.</p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-[var(--color-muted)] uppercase tracking-wider text-[10px]">
                <tr className="text-left">
                  <th className="py-2 pr-3">Skill</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Band</th>
                  <th className="py-2 pr-3 text-right">Engineers</th>
                  <th className="py-2 pr-3">Status</th>
                  <th className="py-2 pr-3">Registered</th>
                </tr>
              </thead>
              <tbody>
                {taxonomy.map((t) => (
                  <tr key={t.id} className="border-t border-[var(--color-border)]">
                    <td className="py-2 pr-3 font-medium">{t.skill_label}</td>
                    <td className="py-2 pr-3">
                      <span className={`inline-block px-1.5 py-0.5 rounded border text-[10px] uppercase ${KIND_BADGE[t.skill_kind] ?? "border-[var(--color-border)]"}`}>
                        {t.skill_kind}
                      </span>
                    </td>
                    <td className="py-2 pr-3">
                      <span className={`inline-block px-1.5 py-0.5 rounded border text-[10px] uppercase ${BAND_TONE[t.importance_band] ?? "border-[var(--color-border)]"}`}>
                        {t.importance_band}
                      </span>
                    </td>
                    <td className="py-2 pr-3 text-right tabular-nums">{formatNumber(t.engineers_with_skill ?? 0)}</td>
                    <td className="py-2 pr-3">
                      {t.is_active
                        ? <span className="text-[var(--color-ok)]">active</span>
                        : <span className="text-[var(--color-muted)]">retired</span>}
                    </td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">{fmtAge(t.created_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section>
        <div className="mb-2 text-sm font-semibold">Recent proficiency assessments · {prof.length}</div>
        {prof.length === 0 ? (
          <p className="text-xs text-[var(--color-muted)]">
            No assessments yet. Founder assesses via{" "}
            <code className="font-mono">log_founder_skills_assess_engineer(engineer_user_id, skill_id, level)</code>.
          </p>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-xs">
              <thead className="text-[var(--color-muted)] uppercase tracking-wider text-[10px]">
                <tr className="text-left">
                  <th className="py-2 pr-3">Engineer</th>
                  <th className="py-2 pr-3">Skill</th>
                  <th className="py-2 pr-3">Kind</th>
                  <th className="py-2 pr-3">Band</th>
                  <th className="py-2 pr-3">Level</th>
                  <th className="py-2 pr-3 text-right">Evidence</th>
                  <th className="py-2 pr-3">Source</th>
                  <th className="py-2 pr-3">Updated</th>
                </tr>
              </thead>
              <tbody>
                {prof.map((p) => (
                  <tr key={p.id} className="border-t border-[var(--color-border)] align-top">
                    <td className="py-2 pr-3 font-medium">{p.engineer_name}</td>
                    <td className="py-2 pr-3">{p.skill_label}</td>
                    <td className="py-2 pr-3">
                      <span className={`inline-block px-1.5 py-0.5 rounded border text-[10px] uppercase ${KIND_BADGE[p.skill_kind] ?? "border-[var(--color-border)]"}`}>
                        {p.skill_kind}
                      </span>
                    </td>
                    <td className="py-2 pr-3">
                      <span className={`inline-block px-1.5 py-0.5 rounded border text-[10px] uppercase ${BAND_TONE[p.importance_band] ?? "border-[var(--color-border)]"}`}>
                        {p.importance_band}
                      </span>
                    </td>
                    <td className={`py-2 pr-3 font-semibold ${LEVEL_TONE[p.proficiency_level] ?? ""}`}>
                      {p.proficiency_level}
                    </td>
                    <td className="py-2 pr-3 text-right tabular-nums text-[var(--color-muted)]">
                      {formatNumber(p.evidence_count ?? 0)}
                    </td>
                    <td className="py-2 pr-3">
                      {p.founder_assessed_at
                        ? <span className="text-[var(--color-ok)]">founder ✓</span>
                        : p.self_assessed_at
                          ? <span className="text-[var(--color-muted)]">self</span>
                          : <span className="text-[var(--color-muted)]">—</span>}
                    </td>
                    <td className="py-2 pr-3 text-[var(--color-muted)]">{fmtAge(p.updated_at)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <footer className="text-[10px] text-[var(--color-muted)]">
        Generated {s.generated_at ? new Date(s.generated_at).toISOString() : "—"} · founder-only · engineer self-view via{" "}
        <code className="font-mono">engineer_skills_my_proficiencies()</code> · r1426
      </footer>
    </div>
  );
}
