import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable } from '@/components/ui/DataTable';
import type { Column } from '@/components/ui/DataTable';

export const dynamic = 'force-dynamic';

type ThrottleRow = { hospital: string; city: string; sessions: number; peak_mbps: number; throttle_kicks: number; grade: string };
type DisciplineRow = { engineer: string; hospital: string; score: number; status: string; next_action: string };
type GradeRow = { grade: string; hospitals: number; avg_sessions: number };
type IsolationRow = { hospital: string; city: string; policy: string; sessions: number; grade: string };
type EscalatedRow = { engineer: string; hospital: string; score: number; rogue_devices: number; action: string };
type PolicyRow = { tier: string; hospitals: number; avg_kicks: number; avg_cap: number };
type VisitTopRow = { engineer: string; monthly_visits: number; ap_audits: number; patches: number; status: string };

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [throttle, discipline, gradeMix, isolation, escalated, policy, visitTop] = await Promise.all([
    sb.rpc('rpc_r2984_throttle_overview'),
    sb.rpc('rpc_r2984_engineer_discipline'),
    sb.rpc('rpc_r2984_hygiene_grade_mix'),
    sb.rpc('rpc_r2984_isolation_offenders'),
    sb.rpc('rpc_r2984_escalated_engineers'),
    sb.rpc('rpc_r2984_policy_tier_breakdown'),
    sb.rpc('rpc_r2984_monthly_visit_top'),
  ]);

  const throttleCols: Column<ThrottleRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Sessions', accessor: (r) => r.sessions },
    { header: 'Peak Mbps', accessor: (r) => r.peak_mbps },
    { header: 'Throttle Kicks', accessor: (r) => r.throttle_kicks },
    { header: 'Grade', accessor: (r) => r.grade },
  ];
  const disciplineCols: Column<DisciplineRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer },
    { header: 'Hospital', accessor: (r) => r.hospital },
    { header: 'Score', accessor: (r) => r.score },
    { header: 'Status', accessor: (r) => r.status },
    { header: 'Next Action', accessor: (r) => r.next_action },
  ];
  const gradeCols: Column<GradeRow>[] = [
    { header: 'Grade', accessor: (r) => r.grade },
    { header: 'Hospitals', accessor: (r) => r.hospitals },
    { header: 'Avg Sessions', accessor: (r) => r.avg_sessions },
  ];
  const isolationCols: Column<IsolationRow>[] = [
    { header: 'Hospital', accessor: (r) => r.hospital },
    { header: 'City', accessor: (r) => r.city },
    { header: 'Policy', accessor: (r) => r.policy },
    { header: 'Sessions', accessor: (r) => r.sessions },
    { header: 'Grade', accessor: (r) => r.grade },
  ];
  const escalatedCols: Column<EscalatedRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer },
    { header: 'Hospital', accessor: (r) => r.hospital },
    { header: 'Score', accessor: (r) => r.score },
    { header: 'Rogue Devices', accessor: (r) => r.rogue_devices },
    { header: 'Action', accessor: (r) => r.action },
  ];
  const policyCols: Column<PolicyRow>[] = [
    { header: 'Policy Tier', accessor: (r) => r.tier },
    { header: 'Hospitals', accessor: (r) => r.hospitals },
    { header: 'Avg Kicks', accessor: (r) => r.avg_kicks },
    { header: 'Avg Cap Mbps', accessor: (r) => r.avg_cap },
  ];
  const visitTopCols: Column<VisitTopRow>[] = [
    { header: 'Engineer', accessor: (r) => r.engineer },
    { header: 'Monthly Visits', accessor: (r) => r.monthly_visits },
    { header: 'AP Audits', accessor: (r) => r.ap_audits },
    { header: 'Patches', accessor: (r) => r.patches },
    { header: 'Status', accessor: (r) => r.status },
  ];

  return (
    <main style={{ padding: 24, display: 'grid', gap: 24 }}>
      <header>
        <h1 style={{ fontSize: 22, fontWeight: 700 }}>r2984 — Visitor WiFi Throttle & Network Hygiene Discipline</h1>
        <p style={{ color: '#666', fontSize: 13 }}>Batch 420 milestone. Monthly engineer-to-hospital visit discipline plus visitor-WiFi throttling & hygiene grades.</p>
      </header>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Throttle Overview (May 2026)</h2>
        <DataTable
          rows={(throttle.data ?? []) as ThrottleRow[]}
          columns={throttleCols}
          emptyMessage="No throttle events"
          rowKey={(r, i) => String((r as ThrottleRow & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Engineer Discipline (lowest score first)</h2>
        <DataTable
          rows={(discipline.data ?? []) as DisciplineRow[]}
          columns={disciplineCols}
          emptyMessage="No discipline rows"
          rowKey={(r, i) => String((r as DisciplineRow & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Hygiene Grade Mix</h2>
        <DataTable
          rows={(gradeMix.data ?? []) as GradeRow[]}
          columns={gradeCols}
          emptyMessage="No grade data"
          rowKey={(r, i) => String((r as GradeRow & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Isolation Offenders (guest isolation OFF)</h2>
        <DataTable
          rows={(isolation.data ?? []) as IsolationRow[]}
          columns={isolationCols}
          emptyMessage="No offenders"
          rowKey={(r, i) => String((r as IsolationRow & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Escalated Engineers</h2>
        <DataTable
          rows={(escalated.data ?? []) as EscalatedRow[]}
          columns={escalatedCols}
          emptyMessage="No escalations"
          rowKey={(r, i) => String((r as EscalatedRow & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Policy Tier Breakdown</h2>
        <DataTable
          rows={(policy.data ?? []) as PolicyRow[]}
          columns={policyCols}
          emptyMessage="No policy data"
          rowKey={(r, i) => String((r as PolicyRow & { id?: string }).id ?? i)}
        />
      </section>

      <section>
        <h2 style={{ fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Monthly Visit Leaders</h2>
        <DataTable
          rows={(visitTop.data ?? []) as VisitTopRow[]}
          columns={visitTopCols}
          emptyMessage="No visit data"
          rowKey={(r, i) => String((r as VisitTopRow & { id?: string }).id ?? i)}
        />
      </section>
    </main>
  );
}
