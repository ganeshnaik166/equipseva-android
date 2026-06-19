import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";
import Link from "next/link";

export const metadata = { title: "Founder Cohort Retention" };
export const dynamic = "force-dynamic";

type CohortRow = {
  cohort_month: string;
  cohort_size: number;
  m0_active: number;
  m1_active: number;
  m2_active: number;
  m3_active: number;
  m4_active: number;
  m5_active: number;
  m6_active: number;
  m12_active: number;
  retention_pct_m1: number;
  retention_pct_m3: number;
  retention_pct_m6: number;
};

function pct(active: number, size: number): number {
  if (!size || size <= 0) return 0;
  return Math.round((active / size) * 1000) / 10;
}

function bandClass(p: number, size: number): string {
  if (!size || size <= 0) return "text-[var(--color-muted)]";
  if (p >= 60) return "text-[var(--color-ok)] font-semibold";
  if (p >= 40) return "text-[var(--color-info)]";
  if (p >= 20) return "text-[var(--color-warn)]";
  return "text-[var(--color-danger)]";
}

function fmtMonth(iso: string): string {
  const d = new Date(iso);
  return d.toLocaleDateString("en-IN", { year: "numeric", month: "short" });
}

function CohortTable({ title, rows }: { title: string; rows: CohortRow[] }) {
  return (
    <section className="rounded border border-[var(--color-border)] bg-white">
      <header className="border-b border-[var(--color-border)] px-3 py-2 text-sm font-semibold">{title}</header>
      <div className="overflow-x-auto">
        <table className="w-full text-xs">
          <thead className="bg-[var(--color-bg-soft)] text-left text-[var(--color-muted)]">
            <tr>
              <th className="px-2 py-2">Cohort</th>
              <th className="px-2 py-2 text-right">Size</th>
              <th className="px-2 py-2 text-right">M0</th>
              <th className="px-2 py-2 text-right">M1</th>
              <th className="px-2 py-2 text-right">M2</th>
              <th className="px-2 py-2 text-right">M3</th>
              <th className="px-2 py-2 text-right">M4</th>
              <th className="px-2 py-2 text-right">M5</th>
              <th className="px-2 py-2 text-right">M6</th>
              <th className="px-2 py-2 text-right">M12</th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 ? (
              <tr>
                <td className="px-2 py-3 text-[var(--color-muted)]" colSpan={10}>No cohorts in window.</td>
              </tr>
            ) : (
              rows.map((r) => {
                const p0 = pct(r.m0_active, r.cohort_size);
                const p1 = pct(r.m1_active, r.cohort_size);
                const p2 = pct(r.m2_active, r.cohort_size);
                const p3 = pct(r.m3_active, r.cohort_size);
                const p4 = pct(r.m4_active, r.cohort_size);
                const p5 = pct(r.m5_active, r.cohort_size);
                const p6 = pct(r.m6_active, r.cohort_size);
                const p12 = pct(r.m12_active, r.cohort_size);
                return (
                  <tr key={r.cohort_month} className="border-t border-[var(--color-border)]">
                    <td className="px-2 py-2 font-medium">{fmtMonth(r.cohort_month)}</td>
                    <td className="px-2 py-2 text-right">{formatNumber(r.cohort_size)}</td>
                    <td className={`px-2 py-2 text-right ${bandClass(p0, r.cohort_size)}`}>{formatNumber(r.m0_active)} · {p0}%</td>
                    <td className={`px-2 py-2 text-right ${bandClass(p1, r.cohort_size)}`}>{formatNumber(r.m1_active)} · {p1}%</td>
                    <td className={`px-2 py-2 text-right ${bandClass(p2, r.cohort_size)}`}>{formatNumber(r.m2_active)} · {p2}%</td>
                    <td className={`px-2 py-2 text-right ${bandClass(p3, r.cohort_size)}`}>{formatNumber(r.m3_active)} · {p3}%</td>
                    <td className={`px-2 py-2 text-right ${bandClass(p4, r.cohort_size)}`}>{formatNumber(r.m4_active)} · {p4}%</td>
                    <td className={`px-2 py-2 text-right ${bandClass(p5, r.cohort_size)}`}>{formatNumber(r.m5_active)} · {p5}%</td>
                    <td className={`px-2 py-2 text-right ${bandClass(p6, r.cohort_size)}`}>{formatNumber(r.m6_active)} · {p6}%</td>
                    <td className={`px-2 py-2 text-right ${bandClass(p12, r.cohort_size)}`}>{formatNumber(r.m12_active)} · {p12}%</td>
                  </tr>
                );
              })
            )}
          </tbody>
        </table>
      </div>
    </section>
  );
}

function avgPct(rows: CohortRow[], key: "retention_pct_m1" | "retention_pct_m3" | "retention_pct_m6"): number {
  const filtered = rows.filter((r) => r.cohort_size > 0);
  if (filtered.length === 0) return 0;
  const sum = filtered.reduce((acc, r) => acc + Number(r[key] || 0), 0);
  return Math.round((sum / filtered.length) * 10) / 10;
}

function Card({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="rounded border border-[var(--color-border)] bg-white p-3">
      <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{label}</div>
      <div className="mt-1 text-xl font-semibold">{value}</div>
      {sub ? <div className="mt-0.5 text-[10px] text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function FounderCohortRetentionPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [engRes, hospRes] = await Promise.all([
    supabase.rpc("founder_engineer_cohort_retention", { p_months: 12 }),
    supabase.rpc("founder_hospital_cohort_retention", { p_months: 12 }),
  ]);

  const engRows: CohortRow[] = Array.isArray(engRes.data) ? (engRes.data as CohortRow[]) : [];
  const hospRows: CohortRow[] = Array.isArray(hospRes.data) ? (hospRes.data as CohortRow[]) : [];

  const latestEng = engRows[0];
  const latestHosp = hospRows[0];

  const engM3 = avgPct(engRows, "retention_pct_m3");
  const engM6 = avgPct(engRows, "retention_pct_m6");
  const hospM3 = avgPct(hospRows, "retention_pct_m3");
  const hospM6 = avgPct(hospRows, "retention_pct_m6");

  return (
    <main className="mx-auto max-w-7xl space-y-4 p-4">
      <header className="space-y-1">
        <div className="flex items-center justify-between gap-2">
          <h1 className="text-lg font-semibold">Founder cohort retention</h1>
          <Link href="/ops-index" className="text-xs text-[var(--color-muted)] hover:underline">ops-index</Link>
        </div>
        <p className="text-xs text-[var(--color-muted)]">
          12-month cohort retention curves for engineers + hospitals · M0/M1/M2/M3/M4/M5/M6/M12 active in completed jobs · band-coloured cells.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-2 md:grid-cols-3 lg:grid-cols-6">
        <Card label="Latest eng cohort" value={latestEng ? fmtMonth(latestEng.cohort_month) : "—"} sub={latestEng ? `${formatNumber(latestEng.cohort_size)} new engineers` : ""} />
        <Card label="Latest hosp cohort" value={latestHosp ? fmtMonth(latestHosp.cohort_month) : "—"} sub={latestHosp ? `${formatNumber(latestHosp.cohort_size)} new hospitals` : ""} />
        <Card label="Avg eng M3 retention" value={`${engM3}%`} sub="across 12 cohorts" />
        <Card label="Avg eng M6 retention" value={`${engM6}%`} sub="across 12 cohorts" />
        <Card label="Avg hosp M3 retention" value={`${hospM3}%`} sub="across 12 cohorts" />
        <Card label="Avg hosp M6 retention" value={`${hospM6}%`} sub="across 12 cohorts" />
      </section>

      <CohortTable title="Engineer cohorts · % completing a repair job in month M" rows={engRows} />
      <CohortTable title="Hospital cohorts · % posting a completed job in month M" rows={hospRows} />

      <section className="rounded border border-[var(--color-border)] bg-[var(--color-bg-soft)] p-3 text-xs text-[var(--color-muted)] space-y-1">
        <div className="font-semibold text-[var(--color-fg)]">Reading the bands</div>
        <div><span className="text-[var(--color-ok)] font-semibold">green</span> {">="} 60% · <span className="text-[var(--color-info)]">blue</span> 40-59% · <span className="text-[var(--color-warn)]">amber</span> 20-39% · <span className="text-[var(--color-danger)]">red</span> {"<"} 20%</div>
        <div>Engineer cohort = grouped by signup month (engineers.created_at); active = any repair_jobs.completed_at in that month.</div>
        <div>Hospital cohort = organizations.kind='hospital' grouped by signup month; active = any repair_jobs.hospital_org_id match with completed_at in month.</div>
        <div>M12 column is sparse for younger cohorts — only the oldest 1-2 cohorts will populate it in a 12-month window.</div>
      </section>
    </main>
  );
}
