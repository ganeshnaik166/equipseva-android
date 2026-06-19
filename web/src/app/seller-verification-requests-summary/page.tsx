import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { formatNumber } from "@/lib/format";

export const metadata = { title: "Seller-verification requests summary — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  pending_count: number;
  approved_count: number;
  rejected_count: number;
  total_count: number;
  oldest_pending_age_hours: number;
  pending_with_gst_cert: number;
  pending_with_expiry_date: number;
  approved_30d: number;
  rejected_30d: number;
  submitted_30d: number;
  median_review_hours_30d: number;
  expired_licence_pending: number;
};

export default async function SellerVerificationRequestsSummaryPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_seller_verification_requests_summary");
  if (error) throw new Error(`founder_seller_verification_requests_summary: ${error.message}`);
  const row = ((data ?? [])[0] ?? {
    pending_count: 0,
    approved_count: 0,
    rejected_count: 0,
    total_count: 0,
    oldest_pending_age_hours: 0,
    pending_with_gst_cert: 0,
    pending_with_expiry_date: 0,
    approved_30d: 0,
    rejected_30d: 0,
    submitted_30d: 0,
    median_review_hours_30d: 0,
    expired_licence_pending: 0,
  }) as Row;

  const pending = Number(row.pending_count ?? 0);
  const approved = Number(row.approved_count ?? 0);
  const rejected = Number(row.rejected_count ?? 0);
  const total = Number(row.total_count ?? 0);
  const oldestHours = Number(row.oldest_pending_age_hours ?? 0);
  const pendWithGst = Number(row.pending_with_gst_cert ?? 0);
  const pendWithExpiry = Number(row.pending_with_expiry_date ?? 0);
  const approved30d = Number(row.approved_30d ?? 0);
  const rejected30d = Number(row.rejected_30d ?? 0);
  const submitted30d = Number(row.submitted_30d ?? 0);
  const medianHours = Number(row.median_review_hours_30d ?? 0);
  const expiredLicencePending = Number(row.expired_licence_pending ?? 0);

  const oldestLabel = oldestHours <= 0
    ? "—"
    : oldestHours < 48
      ? `${oldestHours.toFixed(1)} h`
      : `${(oldestHours / 24).toFixed(1)} d`;

  const pendingTone = pending === 0
    ? "var(--color-ok)"
    : pending >= 10
      ? "var(--color-danger)"
      : "var(--color-warn)";

  const oldestTone = oldestHours <= 0
    ? undefined
    : oldestHours >= 72
      ? "var(--color-danger)"
      : oldestHours >= 24
        ? "var(--color-warn)"
        : "var(--color-ok)";

  const decided30d = approved30d + rejected30d;
  const approvalRate30d = decided30d === 0 ? 0 : (approved30d / decided30d) * 100;
  const gstCertCoverage = pending === 0 ? 0 : (pendWithGst / pending) * 100;

  const tiles: Array<{ label: string; value: string; sub?: string; tone?: string }> = [
    {
      label: "Pending (live)",
      value: formatNumber(pending),
      sub: "awaiting founder review",
      tone: pendingTone,
    },
    {
      label: "Oldest pending",
      value: oldestLabel,
      sub: "head-of-queue age",
      tone: oldestTone,
    },
    {
      label: "Approved (lifetime)",
      value: formatNumber(approved),
      sub: "org.verification_status='verified'",
      tone: "var(--color-ok)",
    },
    {
      label: "Rejected (lifetime)",
      value: formatNumber(rejected),
      sub: "with reason captured",
      tone: rejected > 0 ? "var(--color-muted)" : undefined,
    },
    {
      label: "Total submissions",
      value: formatNumber(total),
      sub: "since launch",
    },
    {
      label: "Submitted · 30 d",
      value: formatNumber(submitted30d),
      sub: "new KYC requests",
    },
    {
      label: "Approved · 30 d",
      value: formatNumber(approved30d),
      sub: "rolling window",
      tone: "var(--color-ok)",
    },
    {
      label: "Rejected · 30 d",
      value: formatNumber(rejected30d),
      sub: "rolling window",
      tone: rejected30d > 0 ? "var(--color-warn)" : undefined,
    },
    {
      label: "Approval rate · 30 d",
      value: decided30d === 0 ? "—" : `${approvalRate30d.toFixed(1)}%`,
      sub: "approved / (approved+rejected)",
    },
    {
      label: "Median review latency · 30 d",
      value: medianHours > 0 ? `${medianHours.toFixed(2)} h` : "—",
      sub: "submit to reviewed_at",
    },
    {
      label: "GST cert · pending",
      value: pending === 0 ? "—" : `${pendWithGst}/${pending}`,
      sub: pending === 0 ? "no pending" : `${gstCertCoverage.toFixed(0)}% have cert URL`,
      tone: pending > 0 && gstCertCoverage < 80 ? "var(--color-warn)" : undefined,
    },
    {
      label: "Expired licence · pending",
      value: formatNumber(expiredLicencePending),
      sub: "auto-reject candidate",
      tone: expiredLicencePending > 0 ? "var(--color-danger)" : "var(--color-ok)",
    },
  ];

  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Seller-verification requests summary</h1>
        <span className="text-xs text-[var(--color-muted)]">
          {`Marketplace KYC pipeline · pending=${formatNumber(pending)} · 30d-approved=${formatNumber(approved30d)}`}
        </span>
      </header>

      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {tiles.map((t) => (
          <div
            key={t.label}
            className="rounded-md border border-[var(--color-border)] bg-[var(--color-surface)] p-3"
          >
            <div className="text-[10px] uppercase tracking-wide text-[var(--color-muted)]">
              {t.label}
            </div>
            <div
              className="mt-1 text-lg font-semibold tabular-nums"
              style={t.tone ? { color: t.tone } : undefined}
            >
              {t.value}
            </div>
            {t.sub ? (
              <div className="text-[11px] text-[var(--color-muted)] mt-0.5">{t.sub}</div>
            ) : null}
          </div>
        ))}
      </div>

      <p className="text-[11px] text-[var(--color-muted)]">
        {`Source: public.seller_verification_requests (created 20260425090000) — sellers POST KYC docs, founder approves via admin_set_org_verification(); approval flips organizations.verification_status='verified' which unlocks spare_parts INSERT via RLS. Pending = status='pending'. Median latency = reviewed_at - submitted_at over 30 d. Expired licence flagged when licence_expires_at < today.`}
      </p>
    </div>
  );
}
