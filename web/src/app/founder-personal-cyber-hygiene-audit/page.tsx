import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type TierRow = {
  risk_tier: string;
  device_count: number;
  avg_risk: number;
  fde_pct: number | null;
  mdm_pct: number | null;
  vpn_pct: number | null;
  pm_pct: number | null;
};

type PatchRow = {
  os_family: string;
  patch_status: string;
  device_count: number;
  critical_or_high: number;
};

type TwofaRow = {
  account_kind: string;
  total_accounts: number;
  twofa_enrolled: number;
  hardware_key_count: number;
  sms_only_count: number;
  coverage_pct: number | null;
};

type PhishRow = {
  phishing_test_result: string;
  tests: number;
  most_recent_quarter: string | null;
};

type LeakRow = {
  account_label: string;
  account_kind: string;
  breach_source: string | null;
  finding_severity: string;
  remediation_status: string;
  last_password_rotation_at: string | null;
};

type RemediationRow = {
  finding_severity: string;
  open_count: number;
  in_progress_count: number;
  blocked_count: number;
  earliest_due: string | null;
};

type BackupRow = {
  device_label: string;
  device_kind: string;
  last_backup_at: string | null;
  days_since_backup: number | null;
  recovery_codes_offline_for_account: number;
  audit_status: string;
};

type SummaryRow = {
  audit_quarter: string;
  total_checks: number;
  p0_count: number;
  p1_count: number;
  open_or_blocked: number;
  hardware_key_pct: number | null;
  passed_phish_pct: number | null;
};

export default async function Page() {
  const supabase = await getSupabaseServerClient();

  const [
    tierRes,
    patchRes,
    twofaRes,
    phishRes,
    leakRes,
    remediationRes,
    backupRes,
    summaryRes,
  ] = await Promise.all([
    supabase.rpc('founder_r3121_device_tier_rollup'),
    supabase.rpc('founder_r3121_patch_posture'),
    supabase.rpc('founder_r3121_twofa_coverage'),
    supabase.rpc('founder_r3121_phishing_summary'),
    supabase.rpc('founder_r3121_leaked_credentials'),
    supabase.rpc('founder_r3121_open_remediations'),
    supabase.rpc('founder_r3121_backup_recovery_health'),
    supabase.rpc('founder_r3121_quarter_executive_summary'),
  ]);

  const tierRows = (tierRes.data ?? []) as TierRow[];
  const patchRows = (patchRes.data ?? []) as PatchRow[];
  const twofaRows = (twofaRes.data ?? []) as TwofaRow[];
  const phishRows = (phishRes.data ?? []) as PhishRow[];
  const leakRows = (leakRes.data ?? []) as LeakRow[];
  const remediationRows = (remediationRes.data ?? []) as RemediationRow[];
  const backupRows = (backupRes.data ?? []) as BackupRow[];
  const summaryRows = (summaryRes.data ?? []) as SummaryRow[];

  const pct = (n: number | null | undefined) =>
    n === null || n === undefined ? '—' : `${Number(n).toFixed(1)}%`;

  const tierCols: Column<TierRow>[] = [
    { key: 'risk_tier', header: 'Risk tier' },
    { key: 'device_count', header: 'Devices' },
    { key: 'avg_risk', header: 'Avg risk' },
    { key: 'fde_pct', header: 'FDE %', render: (r) => pct(r.fde_pct) },
    { key: 'mdm_pct', header: 'MDM %', render: (r) => pct(r.mdm_pct) },
    { key: 'vpn_pct', header: 'VPN %', render: (r) => pct(r.vpn_pct) },
    { key: 'pm_pct', header: 'PwdMgr %', render: (r) => pct(r.pm_pct) },
  ];

  const patchCols: Column<PatchRow>[] = [
    { key: 'os_family', header: 'OS family' },
    { key: 'patch_status', header: 'Patch status' },
    { key: 'device_count', header: 'Devices' },
    { key: 'critical_or_high', header: 'High/critical' },
  ];

  const twofaCols: Column<TwofaRow>[] = [
    { key: 'account_kind', header: 'Account kind' },
    { key: 'total_accounts', header: 'Total' },
    { key: 'twofa_enrolled', header: '2FA on' },
    { key: 'hardware_key_count', header: 'Hardware key' },
    { key: 'sms_only_count', header: 'SMS only' },
    { key: 'coverage_pct', header: 'Coverage', render: (r) => pct(r.coverage_pct) },
  ];

  const phishCols: Column<PhishRow>[] = [
    { key: 'phishing_test_result', header: 'Result' },
    { key: 'tests', header: 'Tests' },
    { key: 'most_recent_quarter', header: 'Most recent quarter' },
  ];

  const leakCols: Column<LeakRow>[] = [
    { key: 'account_label', header: 'Account' },
    { key: 'account_kind', header: 'Kind' },
    { key: 'breach_source', header: 'Breach source' },
    { key: 'finding_severity', header: 'Severity' },
    { key: 'remediation_status', header: 'Remediation' },
    { key: 'last_password_rotation_at', header: 'Last rotation' },
  ];

  const remediationCols: Column<RemediationRow>[] = [
    { key: 'finding_severity', header: 'Severity' },
    { key: 'open_count', header: 'Open' },
    { key: 'in_progress_count', header: 'In progress' },
    { key: 'blocked_count', header: 'Blocked' },
    { key: 'earliest_due', header: 'Earliest due' },
  ];

  const backupCols: Column<BackupRow>[] = [
    { key: 'device_label', header: 'Device' },
    { key: 'device_kind', header: 'Kind' },
    { key: 'last_backup_at', header: 'Last backup' },
    {
      key: 'days_since_backup',
      header: 'Days since',
      render: (r) =>
        r.days_since_backup === null || r.days_since_backup === undefined
          ? '—'
          : String(r.days_since_backup),
    },
    { key: 'recovery_codes_offline_for_account', header: 'Recovery codes offline' },
    { key: 'audit_status', header: 'Status' },
  ];

  const summaryCols: Column<SummaryRow>[] = [
    { key: 'audit_quarter', header: 'Quarter' },
    { key: 'total_checks', header: 'Checks' },
    { key: 'p0_count', header: 'P0' },
    { key: 'p1_count', header: 'P1' },
    { key: 'open_or_blocked', header: 'Open/blocked' },
    { key: 'hardware_key_pct', header: 'Hardware-key %', render: (r) => pct(r.hardware_key_pct) },
    { key: 'passed_phish_pct', header: 'Passed phish %', render: (r) => pct(r.passed_phish_pct) },
  ];

  return (
    <main className="mx-auto max-w-7xl space-y-10 p-6">
      <header className="space-y-2">
        <h1 className="text-2xl font-semibold">
          Founder personal cyber + device hygiene audit (r3121)
        </h1>
        <p className="text-sm text-neutral-600">
          Quarterly review of founder devices, OS patch level, 2FA coverage, VPN posture,
          phishing simulation results, backups, leaked-credential exposure, and recovery
          readiness. All sections are founder-gated.
        </p>
      </header>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Device risk-tier rollup</h2>
        <DataTable
          rows={tierRows}
          columns={tierCols}
          emptyMessage="No devices tracked."
          rowKey={(r, i) => String(r.risk_tier ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">OS patch posture</h2>
        <DataTable
          rows={patchRows}
          columns={patchCols}
          emptyMessage="No patch records."
          rowKey={(r, i) => `${r.os_family}-${r.patch_status}-${i}`}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">2FA coverage by account kind</h2>
        <DataTable
          rows={twofaRows}
          columns={twofaCols}
          emptyMessage="No accounts tracked."
          rowKey={(r, i) => String(r.account_kind ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Phishing simulation summary</h2>
        <DataTable
          rows={phishRows}
          columns={phishCols}
          emptyMessage="No phishing tests recorded."
          rowKey={(r, i) => String(r.phishing_test_result ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Leaked-credential exposure</h2>
        <DataTable
          rows={leakRows}
          columns={leakCols}
          emptyMessage="No leaked credentials detected."
          rowKey={(r, i) => `${r.account_label}-${i}`}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Open remediations by severity</h2>
        <DataTable
          rows={remediationRows}
          columns={remediationCols}
          emptyMessage="No open remediations."
          rowKey={(r, i) => String(r.finding_severity ?? i)}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Backup + recovery readiness</h2>
        <DataTable
          rows={backupRows}
          columns={backupCols}
          emptyMessage="No backup data."
          rowKey={(r, i) => `${r.device_label}-${i}`}
        />
      </section>

      <section className="space-y-3">
        <h2 className="text-lg font-medium">Quarterly executive summary</h2>
        <DataTable
          rows={summaryRows}
          columns={summaryCols}
          emptyMessage="No quarter recorded."
          rowKey={(r, i) => String(r.audit_quarter ?? i)}
        />
      </section>
    </main>
  );
}
