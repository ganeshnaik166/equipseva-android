import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const dynamic = "force-dynamic";

type SummaryRow = {
  total_photos: number;
  photos_uploaded: number;
  photos_queued: number;
  photos_passed: number;
  photos_flagged: number;
  photos_rejected: number;
  photos_reviewed: number;
  pass_rate_pct: number;
  flag_rate_pct: number;
  unique_engineers: number;
  unique_jobs: number;
  total_flags: number;
  critical_flags: number;
  major_flags: number;
  photos_24h: number;
  avg_qa_score: number;
};

type PhotoRow = {
  photo_id: string;
  engineer_user_id: string;
  repair_job_id: string | null;
  photo_kind: string;
  photo_uri: string;
  captured_at: string;
  qa_status: string;
  qa_score: number | null;
  notes: string | null;
  created_at: string;
};

type FlagRow = {
  flag_id: string;
  photo_id: string;
  flag_kind: string;
  flag_severity: string;
  notes: string | null;
  flagged_by: string | null;
  flagged_at: string;
  photo_kind: string | null;
  engineer_user_id: string | null;
};

type PendingRow = {
  photo_id: string;
  engineer_user_id: string;
  repair_job_id: string | null;
  photo_kind: string;
  captured_at: string;
  age_hours: number;
  qa_status: string;
};

export default async function Page() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();

  const [summaryRes, photosRes, flagsRes, pendingRes] = await Promise.all([
    supabase.rpc("founder_engineer_photo_qa_summary"),
    supabase.rpc("founder_engineer_photos_recent", { p_limit: 40 }),
    supabase.rpc("founder_engineer_photo_qa_flags_recent", { p_limit: 30 }),
    supabase.rpc("founder_engineer_photo_qa_pending_review", { p_limit: 30 }),
  ]);

  const s: SummaryRow = (summaryRes.data?.[0] as SummaryRow) ?? {
    total_photos: 0, photos_uploaded: 0, photos_queued: 0, photos_passed: 0,
    photos_flagged: 0, photos_rejected: 0, photos_reviewed: 0,
    pass_rate_pct: 0, flag_rate_pct: 0, unique_engineers: 0, unique_jobs: 0,
    total_flags: 0, critical_flags: 0, major_flags: 0, photos_24h: 0, avg_qa_score: 0,
  };
  const photos: PhotoRow[] = (photosRes.data as PhotoRow[]) ?? [];
  const flags: FlagRow[] = (flagsRes.data as FlagRow[]) ?? [];
  const pending: PendingRow[] = (pendingRes.data as PendingRow[]) ?? [];

  const cards: { label: string; value: string; tone?: string }[] = [
    { label: "Total photos", value: formatNumber(s.total_photos) },
    { label: "Uploaded", value: formatNumber(s.photos_uploaded) },
    { label: "Queued", value: formatNumber(s.photos_queued), tone: "amber" },
    { label: "Passed", value: formatNumber(s.photos_passed), tone: "emerald" },
    { label: "Flagged", value: formatNumber(s.photos_flagged), tone: "amber" },
    { label: "Rejected", value: formatNumber(s.photos_rejected), tone: "rose" },
    { label: "Reviewed", value: formatNumber(s.photos_reviewed) },
    { label: "Pass rate", value: `${formatNumber(s.pass_rate_pct)}%`, tone: "emerald" },
    { label: "Flag rate", value: `${formatNumber(s.flag_rate_pct)}%`, tone: "amber" },
    { label: "Unique engineers", value: formatNumber(s.unique_engineers) },
    { label: "Unique jobs", value: formatNumber(s.unique_jobs) },
    { label: "Total flags", value: formatNumber(s.total_flags) },
    { label: "Critical flags", value: formatNumber(s.critical_flags), tone: "rose" },
    { label: "Major flags", value: formatNumber(s.major_flags), tone: "amber" },
    { label: "Photos 24h", value: formatNumber(s.photos_24h) },
    { label: "Avg QA score", value: formatNumber(s.avg_qa_score) },
  ];

  const toneClass = (t?: string) => {
    if (t === "emerald") return "border-emerald-500/40 bg-emerald-500/5";
    if (t === "amber") return "border-amber-500/40 bg-amber-500/5";
    if (t === "rose") return "border-rose-500/40 bg-rose-500/5";
    return "border-zinc-700 bg-zinc-900";
  };

  const statusBadge = (st: string) => {
    if (st === "passed" || st === "reviewed") return "text-emerald-300 bg-emerald-900/40";
    if (st === "flagged" || st === "queued_for_review") return "text-amber-300 bg-amber-900/40";
    if (st === "rejected") return "text-rose-300 bg-rose-900/40";
    return "text-zinc-300 bg-zinc-800";
  };

  const sevBadge = (sv: string) => {
    if (sv === "critical") return "text-rose-300 bg-rose-900/40";
    if (sv === "major") return "text-amber-300 bg-amber-900/40";
    if (sv === "minor") return "text-yellow-300 bg-yellow-900/30";
    return "text-zinc-300 bg-zinc-800";
  };

  return (
    <main className="min-h-screen bg-zinc-950 text-zinc-100 p-6 space-y-6">
      <header className="space-y-2">
        <p className="text-xs uppercase tracking-wider text-zinc-500">r1420 · HEAVY</p>
        <h1 className="text-2xl font-semibold">Engineer field photo QA pipeline</h1>
        <p className="text-sm text-zinc-400">Field photo uploads + reviewer-gated QA states · 8 photo kinds · 8 flag kinds × 4 severities · pending review SLA tracker</p>
      </header>

      {pending.length > 0 && (
        <div className="rounded-lg border border-amber-500/40 bg-amber-500/10 px-4 py-3">
          <p className="text-sm text-amber-200">
            <span className="font-semibold">{formatNumber(pending.length)}</span> photo{pending.length === 1 ? "" : "s"} awaiting QA review. Oldest captured {formatNumber(pending[0]?.age_hours ?? 0)} hours ago.
          </p>
        </div>
      )}

      <section className="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
        {cards.map((c) => (
          <div key={c.label} className={`rounded-lg border px-4 py-3 ${toneClass(c.tone)}`}>
            <p className="text-xs text-zinc-400">{c.label}</p>
            <p className="text-xl font-semibold mt-1">{c.value}</p>
          </div>
        ))}
      </section>

      <section className="rounded-lg border border-zinc-800 bg-zinc-900/50">
        <div className="px-4 py-3 border-b border-zinc-800 flex items-center justify-between">
          <h2 className="text-sm font-semibold">Pending QA review queue</h2>
          <span className="text-xs text-zinc-500">{formatNumber(pending.length)} pending</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead className="text-zinc-500 text-left">
              <tr className="border-b border-zinc-800">
                <th className="px-4 py-2 font-medium">Photo</th>
                <th className="px-4 py-2 font-medium">Engineer</th>
                <th className="px-4 py-2 font-medium">Kind</th>
                <th className="px-4 py-2 font-medium">Captured</th>
                <th className="px-4 py-2 font-medium">Age (h)</th>
                <th className="px-4 py-2 font-medium">Status</th>
              </tr>
            </thead>
            <tbody>
              {pending.length === 0 ? (
                <tr><td colSpan={6} className="px-4 py-6 text-center text-zinc-500">No photos pending review.</td></tr>
              ) : pending.map((r) => (
                <tr key={r.photo_id} className="border-b border-zinc-800/60 hover:bg-zinc-900">
                  <td className="px-4 py-2 font-mono text-[10px] text-zinc-400">{r.photo_id.slice(0, 8)}</td>
                  <td className="px-4 py-2 font-mono text-[10px] text-zinc-400">{r.engineer_user_id.slice(0, 8)}</td>
                  <td className="px-4 py-2">{r.photo_kind}</td>
                  <td className="px-4 py-2 text-zinc-400">{new Date(r.captured_at).toISOString().slice(0, 16).replace("T", " ")}</td>
                  <td className="px-4 py-2 text-zinc-300">{formatNumber(r.age_hours)}</td>
                  <td className="px-4 py-2"><span className={`px-2 py-0.5 rounded ${statusBadge(r.qa_status)}`}>{r.qa_status}</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded-lg border border-zinc-800 bg-zinc-900/50">
        <div className="px-4 py-3 border-b border-zinc-800 flex items-center justify-between">
          <h2 className="text-sm font-semibold">Recent photo uploads</h2>
          <span className="text-xs text-zinc-500">{formatNumber(photos.length)} rows</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead className="text-zinc-500 text-left">
              <tr className="border-b border-zinc-800">
                <th className="px-4 py-2 font-medium">Photo</th>
                <th className="px-4 py-2 font-medium">Engineer</th>
                <th className="px-4 py-2 font-medium">Job</th>
                <th className="px-4 py-2 font-medium">Kind</th>
                <th className="px-4 py-2 font-medium">Captured</th>
                <th className="px-4 py-2 font-medium">Status</th>
                <th className="px-4 py-2 font-medium">Score</th>
              </tr>
            </thead>
            <tbody>
              {photos.length === 0 ? (
                <tr><td colSpan={7} className="px-4 py-6 text-center text-zinc-500">No photo uploads yet.</td></tr>
              ) : photos.map((r) => (
                <tr key={r.photo_id} className="border-b border-zinc-800/60 hover:bg-zinc-900">
                  <td className="px-4 py-2 font-mono text-[10px] text-zinc-400">{r.photo_id.slice(0, 8)}</td>
                  <td className="px-4 py-2 font-mono text-[10px] text-zinc-400">{r.engineer_user_id.slice(0, 8)}</td>
                  <td className="px-4 py-2 font-mono text-[10px] text-zinc-400">{r.repair_job_id ? r.repair_job_id.slice(0, 8) : "-"}</td>
                  <td className="px-4 py-2">{r.photo_kind}</td>
                  <td className="px-4 py-2 text-zinc-400">{new Date(r.captured_at).toISOString().slice(0, 16).replace("T", " ")}</td>
                  <td className="px-4 py-2"><span className={`px-2 py-0.5 rounded ${statusBadge(r.qa_status)}`}>{r.qa_status}</span></td>
                  <td className="px-4 py-2 text-zinc-300">{r.qa_score != null ? formatNumber(r.qa_score) : "-"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>

      <section className="rounded-lg border border-zinc-800 bg-zinc-900/50">
        <div className="px-4 py-3 border-b border-zinc-800 flex items-center justify-between">
          <h2 className="text-sm font-semibold">Recent QA flags</h2>
          <span className="text-xs text-zinc-500">{formatNumber(flags.length)} rows</span>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-xs">
            <thead className="text-zinc-500 text-left">
              <tr className="border-b border-zinc-800">
                <th className="px-4 py-2 font-medium">Flag</th>
                <th className="px-4 py-2 font-medium">Photo</th>
                <th className="px-4 py-2 font-medium">Kind</th>
                <th className="px-4 py-2 font-medium">Severity</th>
                <th className="px-4 py-2 font-medium">Photo kind</th>
                <th className="px-4 py-2 font-medium">Engineer</th>
                <th className="px-4 py-2 font-medium">Flagged at</th>
                <th className="px-4 py-2 font-medium">Notes</th>
              </tr>
            </thead>
            <tbody>
              {flags.length === 0 ? (
                <tr><td colSpan={8} className="px-4 py-6 text-center text-zinc-500">No QA flags raised.</td></tr>
              ) : flags.map((r) => (
                <tr key={r.flag_id} className="border-b border-zinc-800/60 hover:bg-zinc-900">
                  <td className="px-4 py-2 font-mono text-[10px] text-zinc-400">{r.flag_id.slice(0, 8)}</td>
                  <td className="px-4 py-2 font-mono text-[10px] text-zinc-400">{r.photo_id.slice(0, 8)}</td>
                  <td className="px-4 py-2">{r.flag_kind}</td>
                  <td className="px-4 py-2"><span className={`px-2 py-0.5 rounded ${sevBadge(r.flag_severity)}`}>{r.flag_severity}</span></td>
                  <td className="px-4 py-2">{r.photo_kind ?? "-"}</td>
                  <td className="px-4 py-2 font-mono text-[10px] text-zinc-400">{r.engineer_user_id ? r.engineer_user_id.slice(0, 8) : "-"}</td>
                  <td className="px-4 py-2 text-zinc-400">{new Date(r.flagged_at).toISOString().slice(0, 16).replace("T", " ")}</td>
                  <td className="px-4 py-2 text-zinc-300">{r.notes ?? "-"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  );
}
