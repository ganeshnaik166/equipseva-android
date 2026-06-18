import { requireFounder } from "@/lib/auth/requireFounder";
import { getSupabaseServerClient } from "@/lib/supabase/server";
import { DataTable, type Column } from "@/components/DataTable";

export const metadata = { title: "Referrals recent — EquipSeva Founder Console" };
export const dynamic = "force-dynamic";

type Row = {
  id: string;
  referrer_name: string;
  referee_name: string;
  referee_first_completed_at: string | null;
  bounty_eligible: boolean;
  bounty_paid: boolean;
  created_at: string;
};

export default async function ReferralsRecentPage() {
  await requireFounder();
  const supabase = await getSupabaseServerClient();
  const { data, error } = await supabase.rpc("founder_referrals_recent");
  if (error) throw new Error(`founder_referrals_recent: ${error.message}`);
  const rows = (data ?? []) as Row[];
  const cols: Column<Row>[] = [
    { key: "t", header: "Created", render: (r) => <span className="text-xs tabular-nums text-[var(--color-muted)]">{new Date(r.created_at).toLocaleString()}</span> },
    { key: "r", header: "Referrer", render: (r) => <span className="text-xs font-semibold">{r.referrer_name}</span> },
    { key: "e", header: "Referee", render: (r) => <span className="text-xs">{r.referee_name}</span> },
    { key: "f", header: "First job done",
      render: (r) => r.referee_first_completed_at
        ? <span className="text-xs text-[var(--color-ok)]">{new Date(r.referee_first_completed_at).toLocaleDateString()}</span>
        : <span className="text-xs text-[var(--color-muted)]">—</span>
    },
    { key: "el", header: "Eligible",
      render: (r) => r.bounty_eligible
        ? <span className="text-xs text-[var(--color-ok)]">✓</span>
        : <span className="text-xs text-[var(--color-muted)]">—</span>
    },
    { key: "p", header: "Paid",
      render: (r) => r.bounty_paid
        ? <span className="text-xs text-[var(--color-ok)]">✓</span>
        : <span className="text-xs text-[var(--color-muted)]">—</span>
    },
  ];
  return (
    <div className="space-y-6">
      <header className="flex items-baseline justify-between">
        <h1 className="text-xl font-semibold">Referrals recent (30d)</h1>
        <span className="text-xs text-[var(--color-muted)]">Last 100 referral events with eligibility + payout state</span>
      </header>
      <DataTable columns={cols} rows={rows} rowKey={(r) => r.id} emptyMessage="No referrals." />
    </div>
  );
}
