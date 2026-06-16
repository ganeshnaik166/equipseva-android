import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { StatCard } from "@/components/StatCard";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Profile completeness — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_engineers: number;
  with_bio: number;
  with_rate: number;
  with_city: number;
  with_specs: number;
  with_phone: number;
  with_avatar: number;
  fully_complete: number;
};

export default async function ProfileCompletenessPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_engineer_profile_completeness");
  if (error) throw new Error(`founder_engineer_profile_completeness: ${error.message}`);
  const r = (Array.isArray(data) ? data[0] : data) as Row | null;
  if (!r || r.total_engineers === 0) {
    return (
      <div className="space-y-6">
        <h1 className="text-xl font-semibold">Profile completeness</h1>
        <p className="text-sm text-[var(--color-muted)]">No verified engineers yet.</p>
      </div>
    );
  }
  const pct = (n: number) => Math.round((n / r.total_engineers) * 100);
  const fields: { label: string; v: number }[] = [
    { label: "With bio", v: r.with_bio },
    { label: "With rate", v: r.with_rate },
    { label: "With city", v: r.with_city },
    { label: "With specializations", v: r.with_specs },
    { label: "With phone", v: r.with_phone },
    { label: "With avatar", v: r.with_avatar },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Profile completeness</h1>
        <span className="text-xs text-[var(--color-muted)]">verified engineers · {formatNumber(r.total_engineers)} total</span>
      </header>
      <section>
        <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
          <StatCard label="Verified engineers" value={formatNumber(r.total_engineers)} />
          <StatCard label="Fully complete" value={formatNumber(r.fully_complete)} subtext={`${pct(r.fully_complete)}%`} tone={pct(r.fully_complete) >= 80 ? "ok" : pct(r.fully_complete) >= 50 ? "warn" : "danger"} />
          <StatCard label="Missing rate" value={formatNumber(r.total_engineers - r.with_rate)} tone={r.with_rate < r.total_engineers ? "warn" : "ok"} />
          <StatCard label="Missing avatar" value={formatNumber(r.total_engineers - r.with_avatar)} />
        </div>
      </section>
      <section>
        <h2 className="mb-2 text-sm font-semibold">Per-field coverage</h2>
        <div className="space-y-2">
          {fields.map((f) => {
            const p = pct(f.v);
            const tone = p >= 80 ? "bg-[var(--color-ok)]" : p >= 50 ? "bg-[var(--color-warn)]" : "bg-[var(--color-danger)]";
            return (
              <div key={f.label} className="flex items-center gap-3">
                <div className="w-40 text-xs">{f.label}</div>
                <div className="h-2 flex-1 rounded-full bg-gray-100">
                  <div className={`h-2 rounded-full ${tone}`} style={{ width: `${p}%` }} />
                </div>
                <div className="w-20 text-right text-xs tabular-nums">
                  {formatNumber(f.v)} <span className="text-[var(--color-muted)]">({p}%)</span>
                </div>
              </div>
            );
          })}
        </div>
      </section>
    </div>
  );
}
