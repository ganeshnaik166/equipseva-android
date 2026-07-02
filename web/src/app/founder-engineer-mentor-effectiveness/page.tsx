import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const dynamic = "force-dynamic";

type MentorRow = {
  mentor_user_id: string;
  mentor_email: string | null;
  mentor_tier: string | null;
  apprentice_count: number;
  graduated_count: number;
  graduation_rate: number;
  apprentice_jobs_total: number;
  apprentice_jobs_success: number;
  job_success_rate: number;
  effectiveness_score: number;
};

type ApprenticeRow = {
  link_id: string;
  mentor_user_id: string;
  mentor_email: string | null;
  apprentice_user_id: string;
  apprentice_email: string | null;
  apprentice_tier: string | null;
  assigned_at: string;
  graduated_at: string | null;
  jobs_completed: number;
};

type UnassignedRow = {
  apprentice_user_id: string;
  apprentice_email: string | null;
  cached_highest_tier: string | null;
  jobs_completed: number;
};

export default async function FounderEngineerMentorEffectivenessPage() {
  const sb = await getSupabaseServerClient();

  let mentors: MentorRow[] = [];
  let apprentices: ApprenticeRow[] = [];
  let unassigned: UnassignedRow[] = [];
  let err: string | null = null;

  try {
    const r = await sb.rpc("founder_mentor_effectiveness_list");
    if (r.error) throw r.error;
    mentors = (r.data as MentorRow[]) ?? [];
  } catch (e: any) {
    err = e?.message ?? "failed to load mentors";
  }

  try {
    const r = await sb.rpc("founder_mentor_apprentices_list");
    if (!r.error) apprentices = (r.data as ApprenticeRow[]) ?? [];
  } catch {}

  try {
    const r = await sb.rpc("founder_mentor_unassigned_apprentices");
    if (!r.error) unassigned = (r.data as UnassignedRow[]) ?? [];
  } catch {}

  const totalMentors = mentors.length;
  const avgScore = mentors.length
    ? (mentors.reduce((s, m) => s + Number(m.effectiveness_score ?? 0), 0) / mentors.length).toFixed(2)
    : "0";
  const totalGraduated = mentors.reduce((s, m) => s + (m.graduated_count ?? 0), 0);

  const mentorCols: Column<MentorRow>[] = [
    { key: "mentor_email", header: "Mentor", render: (r) => r.mentor_email ?? "—" },
    { key: "mentor_tier", header: "Tier", render: (r) => r.mentor_tier ?? "—" },
    { key: "apprentice_count", header: "Apprentices", render: (r) => String(r.apprentice_count ?? 0) },
    { key: "graduated_count", header: "Graduated", render: (r) => String(r.graduated_count ?? 0) },
    { key: "graduation_rate", header: "Grad %", render: (r) => `${r.graduation_rate ?? 0}%` },
    { key: "job_success_rate", header: "Job Success %", render: (r) => `${r.job_success_rate ?? 0}%` },
    { key: "effectiveness_score", header: "Score", render: (r) => String(r.effectiveness_score ?? 0) },
  ];

  const apprenticeCols: Column<ApprenticeRow>[] = [
    { key: "apprentice_email", header: "Apprentice", render: (r) => r.apprentice_email ?? "—" },
    { key: "apprentice_tier", header: "Tier", render: (r) => r.apprentice_tier ?? "—" },
    { key: "mentor_email", header: "Mentor", render: (r) => r.mentor_email ?? "—" },
    { key: "assigned_at", header: "Assigned", render: (r) => new Date(r.assigned_at).toLocaleDateString() },
    { key: "graduated_at", header: "Graduated", render: (r) => r.graduated_at ? new Date(r.graduated_at).toLocaleDateString() : "—" },
    { key: "jobs_completed", header: "Jobs Done", render: (r) => String(r.jobs_completed ?? 0) },
  ];

  const unassignedCols: Column<UnassignedRow>[] = [
    { key: "apprentice_email", header: "Apprentice", render: (r) => r.apprentice_email ?? "—" },
    { key: "cached_highest_tier", header: "Tier", render: (r) => r.cached_highest_tier ?? "—" },
    { key: "jobs_completed", header: "Jobs Done", render: (r) => String(r.jobs_completed ?? 0) },
  ];

  return (
    <main style={{ padding: 24, maxWidth: 1280, margin: "0 auto" }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 4 }}>Engineer Mentor Effectiveness</h1>
      <p style={{ color: "#666", marginBottom: 16 }}>
        Rate mentors by apprentice graduation rate and job-success rate. Rebalance assignments.
      </p>

      {err ? (
        <div style={{ padding: 12, background: "#fee", border: "1px solid #fcc", borderRadius: 6, marginBottom: 16 }}>
          {err}
        </div>
      ) : null}

      <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: 12, marginBottom: 24 }}>
        <div style={{ padding: 16, background: "#f5f5f5", borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: "#666" }}>Mentors Tracked</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalMentors}</div>
        </div>
        <div style={{ padding: 16, background: "#f5f5f5", borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: "#666" }}>Avg Effectiveness Score</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{avgScore}</div>
        </div>
        <div style={{ padding: 16, background: "#f5f5f5", borderRadius: 8 }}>
          <div style={{ fontSize: 12, color: "#666" }}>Total Graduated</div>
          <div style={{ fontSize: 28, fontWeight: 700 }}>{totalGraduated}</div>
        </div>
      </div>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Mentor Scoreboard</h2>
        <DataTable<MentorRow>
          rows={mentors}
          columns={mentorCols}
          rowKey={(r: any, i: number) => String(r.mentor_user_id ?? r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Active Apprentice Pairings</h2>
        <DataTable<ApprenticeRow>
          rows={apprentices}
          columns={apprenticeCols}
          rowKey={(r: any, i: number) => String(r.link_id ?? r.id ?? i)}
        />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 8 }}>Unassigned Apprentices</h2>
        <DataTable<UnassignedRow>
          rows={unassigned}
          columns={unassignedCols}
          rowKey={(r: any, i: number) => String(r.apprentice_user_id ?? r.id ?? i)}
        />
      </section>

      <div style={{ fontSize: 12, color: "#888" }}>r1631 · founder-only</div>
    </main>
  );
}
