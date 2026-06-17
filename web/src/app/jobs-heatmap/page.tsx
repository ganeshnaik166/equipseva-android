import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";

export const metadata = { title: "Jobs heatmap — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = { weekday: number; hour_ist: number; cnt: number };

const DAYS = ["", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

export default async function JobsHeatmapPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_jobs_heatmap");
  if (error) throw new Error(`founder_jobs_heatmap: ${error.message}`);
  const rows = (data ?? []) as Row[];

  // Build a 7×24 grid keyed by [weekday][hour]
  const grid: Record<number, Record<number, number>> = {};
  for (let d = 1; d <= 7; d++) {
    grid[d] = {};
    for (let h = 0; h < 24; h++) grid[d][h] = 0;
  }
  let maxVal = 0;
  for (const r of rows) {
    grid[r.weekday][r.hour_ist] = r.cnt;
    if (r.cnt > maxVal) maxVal = r.cnt;
  }

  const cellTone = (v: number): string => {
    if (v === 0) return "bg-[var(--color-bg)]";
    const intensity = Math.ceil((v / Math.max(maxVal, 1)) * 5);
    return [
      "bg-[#e0f2fe]", // light
      "bg-[#bae6fd]",
      "bg-[#7dd3fc]",
      "bg-[#38bdf8]",
      "bg-[#0ea5e9]", // dark
    ][Math.max(0, Math.min(intensity - 1, 4))];
  };

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Jobs heatmap (90d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Posted-at hour × weekday (IST) · max in window = {maxVal}</span>
      </header>
      <div className="overflow-x-auto">
        <table className="border-separate border-spacing-0.5 text-[10px]">
          <thead>
            <tr>
              <th></th>
              {Array.from({ length: 24 }, (_, h) => (
                <th key={h} className="px-1 text-center font-mono text-[var(--color-muted)]">{h.toString().padStart(2, "0")}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {[1, 2, 3, 4, 5, 6, 7].map((d) => (
              <tr key={d}>
                <td className="pr-2 text-right font-semibold">{DAYS[d]}</td>
                {Array.from({ length: 24 }, (_, h) => {
                  const v = grid[d][h];
                  return (
                    <td key={h} className={`h-5 w-5 text-center tabular-nums ${cellTone(v)}`} title={`${DAYS[d]} ${h}:00 IST — ${v}`}>
                      {v > 0 ? v : ""}
                    </td>
                  );
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <section className="rounded border border-[var(--color-border)] bg-white p-3 text-xs text-[var(--color-muted)]">
        Darker = more jobs posted at that hour-of-week. Use to staff Code Red SLA window, plan engineer push notifications, and tune cron timings.
      </section>
    </div>
  );
}
