import { getSupabaseServerClient } from '@/lib/supabase/server';
import { DataTable, type Column } from '@/components/DataTable';

export const dynamic = 'force-dynamic';

export default async function Page() {
  const sb = await getSupabaseServerClient();

  const [postsRes, topRes, recentRes] = await Promise.all([
    sb.rpc('list_posts_r2076'),
    sb.rpc('top_posts_r2076'),
    sb.rpc('recent_reactions_r2076'),
  ]);

  const posts: any[] = Array.isArray(postsRes.data) ? postsRes.data : [];
  const top: any[] = Array.isArray(topRes.data) ? topRes.data : [];
  const recent: any[] = Array.isArray(recentRes.data) ? recentRes.data : [];

  const postCols: Column<any>[] = [
    { key: 'captured_at', header: 'Captured', render: (r: any) => String(r.captured_at ?? '').slice(0, 19).replace('T', ' ') },
    { key: 'post_title', header: 'Title', render: (r: any) => String(r.post_title ?? '') },
    { key: 'post_category', header: 'Category', render: (r: any) => String(r.post_category ?? '') },
    { key: 'status', header: 'Status', render: (r: any) => String(r.status ?? '') },
    { key: 'engineer_user_id', header: 'Engineer', render: (r: any) => String(r.engineer_user_id ?? '').slice(0, 8) },
  ];

  const topCols: Column<any>[] = [
    { key: 'post_title', header: 'Title', render: (r: any) => String(r.post_title ?? '') },
    { key: 'post_category', header: 'Category', render: (r: any) => String(r.post_category ?? '') },
    { key: 'reaction_count', header: 'Reactions', render: (r: any) => String(r.reaction_count ?? 0) },
  ];

  const recentCols: Column<any>[] = [
    { key: 'taken_at', header: 'When', render: (r: any) => String(r.taken_at ?? '').slice(0, 19).replace('T', ' ') },
    { key: 'reaction_type', header: 'Reaction', render: (r: any) => String(r.reaction_type ?? '') },
    { key: 'by_email', header: 'By', render: (r: any) => String(r.by_email ?? '') },
    { key: 'post_id', header: 'Post', render: (r: any) => String(r.post_id ?? '').slice(0, 8) },
  ];

  return (
    <main style={{ padding: 24, fontFamily: 'ui-sans-serif, system-ui', maxWidth: 1200, margin: '0 auto' }}>
      <h1 style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>Engineer Knowledge Sharing Forum</h1>
      <p style={{ color: '#555', marginBottom: 24 }}>
        Founder console for engineer posts covering tips, troubleshooting, safety, customer stories, innovation, and questions.
      </p>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent posts</h2>
        <DataTable rows={posts} columns={postCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Top posts by reactions</h2>
        <DataTable rows={top} columns={topCols} rowKey={(r: any, i: number) => String(r.post_id ?? i)} />
      </section>

      <section style={{ marginBottom: 32 }}>
        <h2 style={{ fontSize: 18, fontWeight: 600, marginBottom: 12 }}>Recent reactions</h2>
        <DataTable rows={recent} columns={recentCols} rowKey={(r: any, i: number) => String(r.id ?? i)} />
      </section>
    </main>
  );
}
