import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Founder engineer apprentice program — r1760" };
export const dynamic = "force-dynamic";

type ApprenticeRow = {
  id: string;
  apprentice_user_id: string;
  apprentice_email: string | null;
  mentor_user_id: string | null;
  mentor_email: string | null;
  started_on: string;
  expected_graduation_date: string | null;
  current_phase: string;
  hours_logged: number;
  jobs_completed: number;
  status: string;
  milestone_count: number;
  created_at: string;
};

type TopProgressRow = {
  apprentice_id: string;
  apprentice_email: string | null;
  current_phase: string;
  hours_logged: number;
  jobs_completed: number;
  milestone_count: number;
  progress_score: number;
};

type GraduatedRow = {
  apprentice_id: string;
  apprentice_email: string | null;
  started_on: string;
  graduated_at: string;
  hours_logged: number;
  jobs_completed: number;
  milestone_count: number;
};

function fmtDate(s: string | null): string {
  if (!s) return "—";
  try {
    return new Date(s).toISOString().slice(0, 10);
  } catch {
    return "—";
  }
}

function phaseBadge(phase: string): string {
  if (phase === "shadow") return "text-gray-600";
  if (phase === "co_pilot") return "text-amber-700";
  if (phase === "supervised_solo") return "text-blue-700";
  if (phase === "graduated") return "text-emerald-700";
  if (phase === "dropped") return "text-rose-700";
  return "";
}

function statusBadge(status: string): string {
  if (status === "active") return "text-emerald-700";
  if (status === "paused") return "text-amber-700";
  if (status === "graduated") return "text-blue-700";
  if (status === "dropped") return "text-rose-700";
  return "";
}

export default async function FounderEngineerApprenticeProgramPage() {
  const sb = await getSupabaseServerClient();
  const [apprenticesRes, topProgressRes, recentGradRes] = await Promise.all([
    sb.rpc("list_apprentices_r1760"),
    sb.rpc("top_progress_apprentices_r1760"),
    sb.rpc("recently_graduated_r1760"),
  ]);

  if (apprenticesRes.error) throw new Error(`list_apprentices_r1760: ${apprenticesRes.error.message}`);
  if (topProgressRes.error) throw new Error(`top_progress_apprentices_r1760: ${topProgressRes.error.message}`);
  if (recentGradRes.error) throw new Error(`recently_graduated_r1760: ${recentGradRes.error.message}`);

  const apprentices = (apprenticesRes.data ?? []) as ApprenticeRow[];
  const topProgress = (topProgressRes.data ?? []) as TopProgressRow[];
  const recentGrad = (recentGradRes.data ?? []) as GraduatedRow[];

  const totalCount = apprentices.length;
  const activeCount = apprentices.filter((a) => a.status === "active").length;
  const pausedCount = apprentices.filter((a) => a.status === "paused").length;
  const graduatedCount = apprentices.filter((a) => a.status === "graduated").length;
  const droppedCount = apprentices.filter((a) => a.status === "dropped").length;
  const shadowCount = apprentices.filter((a) => a.current_phase === "shadow").length;
  const coPilotCount = apprentices.filter((a) => a.current_phase === "co_pilot").length;
  const soloCount = apprentices.filter((a) => a.current_phase === "supervised_solo").length;

  const apprenticeColumns: Column<ApprenticeRow>[] = [
    {
      key: "apprentice_email",
      header: "Apprentice",
      render: (r: any) => <span className="font-medium">{r.apprentice_email ?? r.apprentice_user_id}</span>,
    },
    { key: "mentor_email", header: "Mentor", render: (r: any) => r.mentor_email ?? "—" },
    {
      key: "current_phase",
      header: "Phase",
      render: (r: any) => <span className={phaseBadge(r.current_phase)}>{r.current_phase}</span>,
    },
    {
      key: "status",
      header: "Status",
      render: (r: any) => <span className={statusBadge(r.status)}>{r.status}</span>,
    },
    { key: "started_on", header: "Started", render: (r: any) => fmtDate(r.started_on) },
    {
      key: "expected_graduation_date",
      header: "Expected grad",
      render: (r: any) => fmtDate(r.expected_graduation_date),
    },
    { key: "hours_logged", header: "Hours", render: (r: any) => String(r.hours_logged) },
    { key: "jobs_completed", header: "Jobs", render: (r: any) => String(r.jobs_completed) },
    { key: "milestone_count", header: "Milestones", render: (r: any) => String(r.milestone_count) },
  ];

  const topProgressColumns: Column<TopProgressRow>[] = [
    {
      key: "apprentice_email",
      header: "Apprentice",
      render: (r: any) => <span className="font-medium">{r.apprentice_email ?? r.apprentice_id}</span>,
    },
    {
      key: "current_phase",
      header: "Phase",
      render: (r: any) => <span className={phaseBadge(r.current_phase)}>{r.current_phase}</span>,
    },
    { key: "hours_logged", header: "Hours", render: (r: any) => String(r.hours_logged) },
    { key: "jobs_completed", header: "Jobs", render: (r: any) => String(r.jobs_completed) },
    { key: "milestone_count", header: "Milestones", render: (r: any) => String(r.milestone_count) },
    {
      key: "progress_score",
      header: "Score",
      render: (r: any) => <span className="font-semibold">{r.progress_score}</span>,
    },
  ];

  const graduatedColumns: Column<GraduatedRow>[] = [
    {
      key: "apprentice_email",
      header: "Apprentice",
      render: (r: any) => <span className="font-medium">{r.apprentice_email ?? r.apprentice_id}</span>,
    },
    { key: "started_on", header: "Started", render: (r: any) => fmtDate(r.started_on) },
    { key: "graduated_at", header: "Graduated", render: (r: any) => fmtDate(r.graduated_at) },
    { key: "hours_logged", header: "Hours", render: (r: any) => String(r.hours_logged) },
    { key: "jobs_completed", header: "Jobs", render: (r: any) => String(r.jobs_completed) },
    { key: "milestone_count", header: "Milestones", render: (r: any) => String(r.milestone_count) },
  ];

  return (
    <div className="space-y-6 p-6">
      <header>
        <h1 className="text-xl font-semibold">Founder engineer apprentice program — r1760</h1>
        <p className="mt-1 text-xs text-gray-500">
          Track new engineer apprentices through 4 phases: shadow → co-pilot → supervised solo →
          graduated. Log hours, jobs & milestones; advance phases when ready.
        </p>
      </header>

      <section className="grid grid-cols-2 gap-3 md:grid-cols-4 lg:grid-cols-8">
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Total</div>
          <div className="mt-1 text-lg font-semibold">{totalCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Active</div>
          <div className="mt-1 text-lg font-semibold text-emerald-700">{activeCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Paused</div>
          <div className="mt-1 text-lg font-semibold text-amber-700">{pausedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Graduated</div>
          <div className="mt-1 text-lg font-semibold text-blue-700">{graduatedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Dropped</div>
          <div className="mt-1 text-lg font-semibold text-rose-700">{droppedCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Shadow</div>
          <div className="mt-1 text-lg font-semibold">{shadowCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Co-pilot</div>
          <div className="mt-1 text-lg font-semibold">{coPilotCount}</div>
        </div>
        <div className="rounded border border-gray-200 bg-white p-3">
          <div className="text-xs text-gray-500">Solo</div>
          <div className="mt-1 text-lg font-semibold">{soloCount}</div>
        </div>
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">All apprentices</h2>
        <p className="text-xs text-gray-500">
          Founder-only roster of every apprentice across all phases. Add new apprentices via add_apprentice_r1760 and
          advance phase via advance_phase_r1760.
        </p>
        <DataTable
          rows={apprentices}
          columns={apprenticeColumns}
          rowKey={(r: any, i: number) => String(r.id ?? i)}
          emptyMessage="No apprentices enrolled yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Top progress (active)</h2>
        <p className="text-xs text-gray-500">
          Active apprentices ranked by composite progress score (hours + jobs*10 + milestones*25). Use
          this to spot apprentices ready to advance.
        </p>
        <DataTable
          rows={topProgress}
          columns={topProgressColumns}
          rowKey={(r: any, i: number) => String(r.apprentice_id ?? i)}
          emptyMessage="No active apprentices yet."
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-base font-semibold">Recently graduated</h2>
        <p className="text-xs text-gray-500">
          Last 20 apprentices who completed the program. Celebrate & promote to full engineer roster.
        </p>
        <DataTable
          rows={recentGrad}
          columns={graduatedColumns}
          rowKey={(r: any, i: number) => String(r.apprentice_id ?? i)}
          emptyMessage="No graduates yet."
        />
      </section>
    </div>
  );
}
