import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Compliance evidence snapshot summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  evidence_rows_all_time: number;
  evidence_rows_24h: number;
  evidence_rows_7d: number;
  evidence_rows_30d: number;
  dpdp_grievances_open: number;
  dpdp_grievances_breach_open: number;
  dpdp_grievances_within_72h: number;
  dpdp_grievances_overdue: number;
  consent_revocations_24h: number;
  consents_granted_24h: number;
  dsr_pending_hospital_sign: number;
  dsr_signed_30d: number;
  nabh_exports_30d: number;
  founder_actions_24h: number;
  founder_actions_7d: number;
};

function Card({ title, val, sub, danger, ok }: { title: string; val: string; sub?: string; danger?: boolean; ok?: boolean }) {
  return (
    <div className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-4">
      <div className="text-xs text-[var(--color-muted)]">{title}</div>
      <div className={`mt-1 text-2xl font-semibold tabular-nums ${danger ? "text-[var(--color-danger)]" : ok ? "text-[var(--color-ok)]" : ""}`}>{val}</div>
      {sub ? <div className="text-xs tabular-nums text-[var(--color-muted)]">{sub}</div> : null}
    </div>
  );
}

export default async function ComplianceEvidenceSnapshotSnapshotSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_compliance_evidence_snapshot_summary");
  if (error) throw new Error(`founder_compliance_evidence_snapshot_summary: ${error.message}`);
  const r = (data?.[0] ?? null) as Row | null;
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Compliance evidence snapshot summary</h1>
        <span className="text-xs text-[var(--color-muted)]">15-KPI regulatory backbone · §65B evidence + DPDP + consent + DSR + NABH + founder audit</span>
      </header>
      {r ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <Card title="Evidence rows all-time" val={formatNumber(r.evidence_rows_all_time)} sub="§65B ledger" />
          <Card title="Evidence rows 24h" val={formatNumber(r.evidence_rows_24h)} sub="last day" ok={r.evidence_rows_24h > 0} />
          <Card title="Evidence rows 7d" val={formatNumber(r.evidence_rows_7d)} sub="rolling week" />
          <Card title="Evidence rows 30d" val={formatNumber(r.evidence_rows_30d)} sub="rolling month" />
          <Card title="DPDP grievances open" val={formatNumber(r.dpdp_grievances_open)} sub="open + in_review" danger={r.dpdp_grievances_open > 0} />
          <Card title="DPDP breach open" val={formatNumber(r.dpdp_grievances_breach_open)} sub="72h SLA clock" danger={r.dpdp_grievances_breach_open > 0} />
          <Card title="DPDP deadline <72h" val={formatNumber(r.dpdp_grievances_within_72h)} sub="approaching SLA" danger={r.dpdp_grievances_within_72h > 0} />
          <Card title="DPDP overdue" val={formatNumber(r.dpdp_grievances_overdue)} sub="penalty risk ₹250 Cr" danger={r.dpdp_grievances_overdue > 0} />
          <Card title="Consent revocations 24h" val={formatNumber(r.consent_revocations_24h)} sub="withdraw events" danger={r.consent_revocations_24h > 0} />
          <Card title="Consents granted 24h" val={formatNumber(r.consents_granted_24h)} sub="grant events" ok={r.consents_granted_24h > 0} />
          <Card title="DSR pending sign" val={formatNumber(r.dsr_pending_hospital_sign)} sub="hospital sign-off queue" danger={r.dsr_pending_hospital_sign > 5} />
          <Card title="DSR signed 30d" val={formatNumber(r.dsr_signed_30d)} sub="NABH-eligible reports" ok />
          <Card title="NABH exports 30d" val={formatNumber(r.nabh_exports_30d)} sub="auditor ZIP pulls" />
          <Card title="Founder actions 24h" val={formatNumber(r.founder_actions_24h)} sub="privileged ops" />
          <Card title="Founder actions 7d" val={formatNumber(r.founder_actions_7d)} sub="rolling week" />
        </div>
      ) : <p className="text-sm text-[var(--color-muted)]">No data.</p>}
    </div>
  );
}