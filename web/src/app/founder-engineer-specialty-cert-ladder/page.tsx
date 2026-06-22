import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function FounderEngineerSpecialtyCertLadderPage() {
  const sb = await getSupabaseServerClient();

  const [laddersRes, tierRes, recentRes] = await Promise.all([
    sb.rpc('list_specialty_ladders_r1972'),
    sb.rpc('specialty_engineers_at_tier_r1972'),
    sb.rpc('specialty_recent_milestones_r1972'),
  ]);

  const ladders = (laddersRes.data as any[]) ?? [];
  const tiers = (tierRes.data as any[]) ?? [];
  const recent = (recentRes.data as any[]) ?? [];

  const ladderCols: Column<any>[] = [
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => <span className="font-mono text-xs">{String(r.engineer_user_id ?? '').slice(0, 8)}</span> },
    { key: 'specialty', header: 'Specialty', render: (r: any) => <span>{r.specialty}</span> },
    { key: 'current_tier', header: 'Current Tier', render: (r: any) => <span className="font-semibold">{r.current_tier}</span> },
    { key: 'target_tier', header: 'Target Tier', render: (r: any) => <span>{r.target_tier}</span> },
    { key: 'target_completion_date', header: 'Target Date', render: (r: any) => <span>{r.target_completion_date ?? '-'}</span> },
    { key: 'status', header: 'Status', render: (r: any) => <span>{r.status}</span> },
    { key: 'last_assessment_at', header: 'Last Assessment', render: (r: any) => <span>{r.last_assessment_at ? new Date(r.last_assessment_at).toLocaleDateString() : '-'}</span> },
    { key: 'created_at', header: 'Created', render: (r: any) => <span>{new Date(r.created_at).toLocaleDateString()}</span> },
  ];

  const tierCols: Column<any>[] = [
    { key: 'current_tier', header: 'Tier', render: (r: any) => <span className="font-semibold">{r.current_tier}</span> },
    { key: 'specialty', header: 'Specialty', render: (r: any) => <span>{r.specialty}</span> },
    { key: 'engineer_count', header: 'Engineers', render: (r: any) => <span className="font-mono">{r.engineer_count}</span> },
  ];

  const recentCols: Column<any>[] = [
    { key: 'milestone_at', header: 'When', render: (r: any) => <span>{new Date(r.milestone_at).toLocaleString()}</span> },
    { key: 'milestone_type', header: 'Type', render: (r: any) => <span>{r.milestone_type}</span> },
    { key: 'by_email', header: 'By', render: (r: any) => <span>{r.by_email ?? '-'}</span> },
    { key: 'score', header: 'Score', render: (r: any) => <span className="font-mono">{r.score ?? '-'}</span> },
    { key: 'ladder_id', header: 'Ladder', render: (r: any) => <span className="font-mono text-xs">{String(r.ladder_id ?? '').slice(0, 8)}</span> },
  ];

  return (
    <div className="p-6 space-y-8">
      <header>
        <h1 className="text-2xl font-bold">Engineer Specialty Certification Ladder</h1>
        <p className="text-sm text-gray-600 mt-1">Track engineer specialty cert progression across imaging, ventilator, anesthesia, lab, monitor and multi modality tracks.</p>
      </header>

      <section>
        <h2 className="text-lg font-semibold mb-3">Engineers at Tier</h2>
        <DataTable rows={tiers} columns={tierCols} rowKey={(r: any, i: number) => String((r.current_tier ?? '') + '-' + (r.specialty ?? '') + '-' + i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Active Ladders</h2>
        <DataTable rows={ladders} columns={ladderCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section>
        <h2 className="text-lg font-semibold mb-3">Recent Milestones</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </div>
  );
}
