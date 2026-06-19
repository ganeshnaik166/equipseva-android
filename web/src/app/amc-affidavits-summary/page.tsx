import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "AMC affidavits summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  total_affidavits: number;
  signed_last_7d: number;
  signed_last_30d: number;
  signed_last_90d: number;
  unique_signer_hospitals: number;
  pct_with_aadhaar_masked: number;
  pct_with_designation: number;
  pct_with_evidence_ledger: number;
  avg_equipment_categories: number;
  top_signer_designation: string;
  amc_contracts_total: number;
  amc_contracts_unsigned: number;
};

function Kpi({ label, value, hint, tone }: { label: string; value: string; hint?: string; tone?: "ok" | "warn" | "danger" | "muted" }) {
  const color =
    tone === "ok" ? "text-[var(--color-ok)]" :
    tone === "warn" ? "text-[var(--color-warn)]" :
    tone === "danger" ? "text-[var(--color-danger)]" :
    tone === "muted" ? "text-[var(--color-muted)]" :
    "";
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">{label}</div>
      <div className={`mt-1 text-lg font-semibold tabular-nums ${color}`}>{value}</div>
      {hint ? <div className="mt-0.5 text-[10px] text-[var(--color-muted)]">{hint}</div> : null}
    </div>
  );
}

export default async function AmcAffidavitsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_amc_affidavits_summary");
  if (error) throw new Error(`founder_amc_affidavits_summary: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const r: Row = rows[0] ?? {
    total_affidavits: 0,
    signed_last_7d: 0,
    signed_last_30d: 0,
    signed_last_90d: 0,
    unique_signer_hospitals: 0,
    pct_with_aadhaar_masked: 0,
    pct_with_designation: 0,
    pct_with_evidence_ledger: 0,
    avg_equipment_categories: 0,
    top_signer_designation: "(none)",
    amc_contracts_total: 0,
    amc_contracts_unsigned: 0,
  };

  const signedTotal = r.amc_contracts_total - r.amc_contracts_unsigned;
  const signedPct = r.amc_contracts_total > 0
    ? Math.round((signedTotal / r.amc_contracts_total) * 1000) / 10
    : 0;
  const unsignedTone: "ok" | "warn" | "danger" =
    r.amc_contracts_unsigned === 0 ? "ok" :
    r.amc_contracts_unsigned <= 5 ? "warn" : "danger";

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">AMC affidavits summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          Digital affidavit signing velocity, declaration capture quality, designation mix & unsigned-AMC backlog
        </span>
      </header>

      <section>
        <h2 className="mb-3 text-[11px] font-semibold uppercase tracking-wide text-[var(--color-muted)]">Volume & velocity</h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Kpi label="Total affidavits" value={formatNumber(r.total_affidavits)} hint="all-time signed" />
          <Kpi label="Signed last 7d" value={formatNumber(r.signed_last_7d)} tone="ok" />
          <Kpi label="Signed last 30d" value={formatNumber(r.signed_last_30d)} />
          <Kpi label="Signed last 90d" value={formatNumber(r.signed_last_90d)} />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-[11px] font-semibold uppercase tracking-wide text-[var(--color-muted)]">Capture quality</h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Kpi
            label="% with Aadhaar masked"
            value={`${r.pct_with_aadhaar_masked}%`}
            tone={r.pct_with_aadhaar_masked >= 80 ? "ok" : r.pct_with_aadhaar_masked >= 50 ? "warn" : "danger"}
            hint="signer identity captured"
          />
          <Kpi
            label="% with designation"
            value={`${r.pct_with_designation}%`}
            tone={r.pct_with_designation >= 80 ? "ok" : "warn"}
            hint="authority-to-sign trail"
          />
          <Kpi
            label="% with evidence ledger"
            value={`${r.pct_with_evidence_ledger}%`}
            tone={r.pct_with_evidence_ledger >= 80 ? "ok" : "warn"}
            hint="rendered PDF + 65B hash"
          />
          <Kpi
            label="Avg equip categories"
            value={r.avg_equipment_categories.toString()}
            hint="per affidavit"
          />
        </div>
      </section>

      <section>
        <h2 className="mb-3 text-[11px] font-semibold uppercase tracking-wide text-[var(--color-muted)]">Signer mix & backlog</h2>
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Kpi label="Unique signer hospitals" value={formatNumber(r.unique_signer_hospitals)} />
          <Kpi label="Top designation" value={r.top_signer_designation} tone="muted" />
          <Kpi
            label="AMC contracts signed"
            value={`${formatNumber(signedTotal)} / ${formatNumber(r.amc_contracts_total)}`}
            hint={`${signedPct}% coverage`}
            tone={signedPct >= 90 ? "ok" : signedPct >= 60 ? "warn" : "danger"}
          />
          <Kpi
            label="Unsigned AMC backlog"
            value={formatNumber(r.amc_contracts_unsigned)}
            tone={unsignedTone}
            hint="contracts missing affidavit"
          />
        </div>
      </section>

      <p className="text-[11px] text-[var(--color-muted)]">
        Source: <code>public.amc_affidavits</code> (round 493). Affidavit table enforces all 4 declarations true via CHECK constraint;
        unsigned-backlog = <code>amc_contracts</code> rows with no matching affidavit. Indian Contract Act §124 indemnity trail.
      </p>
    </div>
  );
}
