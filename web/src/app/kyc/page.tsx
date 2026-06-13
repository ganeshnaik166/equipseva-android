import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";
import { formatRelativeTime } from "@/lib/format";

export const metadata = { title: "KYC & Attendance — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type RenewalRow = {
  engineer_user_id?: string;
  engineer_email: string | null;
  renewal_kind?: string | null;
  status?: string | null;
  due_at?: string | null;
  expires_at?: string | null;
  last_verified_at?: string | null;
};

type AttendanceRow = {
  engineer_email: string | null;
  job_location?: string | null;
  arrival_location?: string | null;
  distance_km: number | null;
  event_kind: string | null;
  created_at: string;
};

export default async function KycPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const [kycRes, attRes] = await Promise.all([
    supabase.rpc("founder_kyc_renewal_queue", { p_days: 14, p_limit: 100 }),
    supabase.rpc("founder_suspicious_attendance_recent", { p_days: 14, p_limit: 50 }),
  ]);
  if (kycRes.error) throw new Error(`founder_kyc_renewal_queue: ${kycRes.error.message}`);
  if (attRes.error) throw new Error(`founder_suspicious_attendance_recent: ${attRes.error.message}`);
  const renewals = (kycRes.data ?? []) as RenewalRow[];
  const attendance = (attRes.data ?? []) as AttendanceRow[];

  const renewalCols: Column<RenewalRow>[] = [
    { key: "email", header: "Engineer", render: (r) => r.engineer_email ?? "—" },
    { key: "kind", header: "Kind", render: (r) => r.renewal_kind ?? "—" },
    {
      key: "status",
      header: "Status",
      render: (r) => {
        const s = (r.status ?? "").toLowerCase();
        const cls =
          s === "expired"
            ? "bg-red-100 text-[var(--color-danger)]"
            : s === "due_soon" || s === "in_grace"
              ? "bg-yellow-100 text-[var(--color-warn)]"
              : "bg-gray-100";
        return <span className={`rounded px-1.5 py-0.5 text-xs ${cls}`}>{r.status ?? "—"}</span>;
      },
    },
    {
      key: "due",
      header: "Due",
      render: (r) => (
        <span title={r.due_at ?? r.expires_at ?? ""}>
          {formatRelativeTime(r.due_at ?? r.expires_at ?? null)}
        </span>
      ),
    },
    {
      key: "last",
      header: "Last verified",
      render: (r) => formatRelativeTime(r.last_verified_at ?? null),
    },
  ];

  const attendanceCols: Column<AttendanceRow>[] = [
    {
      key: "when",
      header: "When",
      render: (r) => <span title={r.created_at}>{formatRelativeTime(r.created_at)}</span>,
    },
    { key: "engineer", header: "Engineer", render: (r) => r.engineer_email ?? "—" },
    {
      key: "kind",
      header: "Event",
      render: (r) => <span className="rounded bg-yellow-100 px-1.5 py-0.5 text-xs">{r.event_kind ?? "—"}</span>,
    },
    {
      key: "dist",
      header: "Distance",
      render: (r) =>
        r.distance_km != null ? <span>{r.distance_km.toFixed(2)} km</span> : "—",
    },
    {
      key: "where",
      header: "Job → Arrival",
      render: (r) => (
        <span className="text-xs text-[var(--color-muted)]">
          {r.job_location ?? "?"} → {r.arrival_location ?? "?"}
        </span>
      ),
    },
  ];

  return (
    <div className="space-y-8">
      <header>
        <h1 className="text-xl font-semibold">KYC & attendance</h1>
        <p className="mt-1 text-sm text-[var(--color-muted)]">
          12-month engineer re-KYC queue (r497) + suspicious GPS attendance events (r496,
          {">"} 500m from job location).
        </p>
      </header>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Re-KYC renewals <span className="text-[var(--color-muted)]">({renewals.length})</span>
        </h2>
        <DataTable
          columns={renewalCols}
          rows={renewals}
          rowKey={(r, i) => `${r.engineer_user_id ?? r.engineer_email ?? "x"}-${r.renewal_kind ?? i}`}
          emptyMessage="No renewals due in window."
        />
      </section>

      <section>
        <h2 className="mb-2 text-sm font-semibold">
          Suspicious attendance <span className="text-[var(--color-muted)]">({attendance.length})</span>
        </h2>
        <DataTable
          columns={attendanceCols}
          rows={attendance}
          rowKey={(r, i) => `${r.engineer_email ?? "x"}-${r.created_at}-${i}`}
          emptyMessage="No suspicious events in window."
        />
      </section>
    </div>
  );
}
