-- Round r3021: Founder Quarterly Strategic Engineering Open-Source Contribution & Public-Speaking Audit
-- HEAVY ★★★★ — 2 tables + 7 RPCs + seeds

create table if not exists engineer_oss_contributions_r3021 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  quarter text not null check (quarter in ('Q1-2026','Q2-2026','Q3-2026','Q4-2026')),
  engineer_name text not null,
  github_handle text not null,
  repo_slug text not null,
  contribution_type text not null check (contribution_type in ('pr_merged','issue_filed','maintainer','talk','blog','doc_pr')),
  upstream_stars int not null check (upstream_stars between 0 and 500000),
  prs_merged int not null check (prs_merged between 0 and 200),
  lines_added int not null check (lines_added between 0 and 100000),
  lines_removed int not null check (lines_removed between 0 and 100000),
  approved_hours int not null check (approved_hours between 0 and 400),
  strategic_score int not null check (strategic_score between 0 and 100),
  ceo_endorsed boolean not null default false,
  endorsed_at timestamptz
);

create table if not exists engineer_public_speaking_r3021 (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz default now(),
  quarter text not null check (quarter in ('Q1-2026','Q2-2026','Q3-2026','Q4-2026')),
  speaker_name text not null,
  event_name text not null,
  event_city text not null,
  event_country text not null check (event_country in ('IN','SG','US','DE','UK','AE','AU','JP')),
  talk_format text not null check (talk_format in ('keynote','session','workshop','panel','lightning')),
  attendee_count int not null check (attendee_count between 0 and 50000),
  video_views int not null check (video_views between 0 and 5000000),
  cta_conversions int not null check (cta_conversions between 0 and 5000),
  pipeline_inr int not null check (pipeline_inr between 0 and 500000000),
  brand_lift_score int not null check (brand_lift_score between 0 and 100),
  approved_by_founder boolean not null default false,
  event_date date
);

alter table engineer_oss_contributions_r3021 enable row level security;
alter table engineer_public_speaking_r3021 enable row level security;

drop policy if exists oss_founder_read_r3021 on engineer_oss_contributions_r3021;
create policy oss_founder_read_r3021 on engineer_oss_contributions_r3021 for select using (is_founder());

drop policy if exists speak_founder_read_r3021 on engineer_public_speaking_r3021;
create policy speak_founder_read_r3021 on engineer_public_speaking_r3021 for select using (is_founder());

insert into engineer_oss_contributions_r3021 (quarter, engineer_name, github_handle, repo_slug, contribution_type, upstream_stars, prs_merged, lines_added, lines_removed, approved_hours, strategic_score, ceo_endorsed, endorsed_at) values
('Q2-2026','Arjun Mehta','arjunm','supabase/supabase','pr_merged',74000,4,820,210,32,88,true,'2026-04-12'::timestamptz),
('Q2-2026','Priya Rao','priyar','vercel/next.js','pr_merged',122000,2,310,90,24,82,true,'2026-04-22'::timestamptz),
('Q2-2026','Kiran Shah','kirans','postgrest/postgrest','maintainer',23000,7,1240,440,48,91,true,'2026-05-02'::timestamptz),
('Q2-2026','Neha Iyer','nehai','prisma/prisma','pr_merged',39000,3,560,180,28,75,false,null),
('Q2-2026','Rohit Bansal','rohitb','expo/expo','doc_pr',31000,1,90,20,8,58,false,null),
('Q2-2026','Sneha Kapoor','snehak','flutter/flutter','pr_merged',164000,2,420,150,30,84,true,'2026-05-18'::timestamptz),
('Q2-2026','Vikram Singh','vikrams','dgraph-io/badger','issue_filed',14000,0,0,0,4,42,false,null),
('Q2-2026','Aishwarya Pillai','aishp','grafana/grafana','pr_merged',62000,5,910,260,40,86,true,'2026-05-25'::timestamptz),
('Q2-2026','Manish Gupta','manishg','open-telemetry/opentelemetry-collector','pr_merged',5200,3,470,120,26,72,false,null),
('Q1-2026','Arjun Mehta','arjunm','tailwindlabs/tailwindcss','blog',82000,0,0,0,10,64,true,'2026-02-08'::timestamptz),
('Q1-2026','Priya Rao','priyar','TanStack/query','pr_merged',43000,2,280,80,20,69,false,null),
('Q1-2026','Kiran Shah','kirans','postgrest/postgrest','talk',23000,0,0,0,12,77,true,'2026-03-14'::timestamptz),
('Q1-2026','Tanvi Joshi','tanvij','shadcn-ui/ui','pr_merged',71000,4,640,210,30,80,true,'2026-03-20'::timestamptz),
('Q3-2026','Rahul Verma','rahulv','redis/redis','pr_merged',66000,1,180,50,18,70,false,null),
('Q3-2026','Shalini Reddy','shalinir','clickhouse/clickhouse','doc_pr',37000,2,140,30,12,55,false,null);

insert into engineer_public_speaking_r3021 (quarter, speaker_name, event_name, event_city, event_country, talk_format, attendee_count, video_views, cta_conversions, pipeline_inr, brand_lift_score, approved_by_founder, event_date) values
('Q2-2026','Arjun Mehta','PgConf India 2026','Bengaluru','IN','keynote',1200,42000,180,12400000,86,true,'2026-04-18'::date),
('Q2-2026','Priya Rao','React India','Goa','IN','session',800,28000,140,8200000,78,true,'2026-04-26'::date),
('Q2-2026','Kiran Shah','Postgres Conf SG','Singapore','SG','session',420,18000,72,5600000,74,true,'2026-05-08'::date),
('Q2-2026','Neha Iyer','DroidCon Berlin','Berlin','DE','workshop',300,9500,44,3100000,68,false,'2026-05-15'::date),
('Q2-2026','Sneha Kapoor','FlutterCon Mumbai','Mumbai','IN','session',650,22000,110,7400000,80,true,'2026-05-22'::date),
('Q2-2026','Aishwarya Pillai','GrafanaCON','London','UK','lightning',2200,64000,210,18200000,90,true,'2026-06-04'::date),
('Q2-2026','Manish Gupta','KubeCon EU','Paris','DE','session',9000,180000,420,42000000,92,true,'2026-06-11'::date),
('Q2-2026','Vikram Singh','RootConf','Bengaluru','IN','panel',500,12000,38,2400000,60,false,'2026-06-18'::date),
('Q1-2026','Arjun Mehta','DevConf India','Hyderabad','IN','keynote',1500,52000,220,15800000,84,true,'2026-02-11'::date),
('Q1-2026','Tanvi Joshi','Next.js Conf','San Francisco','US','session',4500,110000,310,28400000,88,true,'2026-03-05'::date),
('Q1-2026','Priya Rao','JSConf Asia','Singapore','SG','workshop',280,8400,52,3600000,66,false,'2026-03-19'::date),
('Q3-2026','Rahul Verma','RedisDays Dubai','Dubai','AE','lightning',380,6200,28,1800000,58,false,'2026-07-10'::date),
('Q3-2026','Shalini Reddy','ClickHouse Meetup','Tokyo','JP','session',220,4400,18,1100000,52,false,'2026-08-04'::date),
('Q4-2026','Kiran Shah','AWS reInvent','Las Vegas','US','panel',12000,240000,540,62000000,94,true,'2026-12-02'::date);

-- RPC 1
create or replace function r3021_quarterly_oss_summary()
returns table(quarter text, contributions int, prs_merged_total int, hours_total int, endorsed int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select o.quarter,
         count(*)::int,
         coalesce(sum(o.prs_merged),0)::int,
         coalesce(sum(o.approved_hours),0)::int,
         (count(*) filter (where o.ceo_endorsed))::int
  from engineer_oss_contributions_r3021 o
  group by o.quarter order by o.quarter;
end $$;

-- RPC 2
create or replace function r3021_top_oss_engineers()
returns table(engineer_name text, contributions int, avg_score numeric, total_lines int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select o.engineer_name,
         count(*)::int,
         round(avg(o.strategic_score)::numeric,1),
         coalesce(sum(o.lines_added + o.lines_removed),0)::int
  from engineer_oss_contributions_r3021 o
  group by o.engineer_name
  order by avg(o.strategic_score) desc nulls last;
end $$;

-- RPC 3
create or replace function r3021_oss_by_type()
returns table(contribution_type text, n int, endorsed int, avg_hours numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select o.contribution_type,
         count(*)::int,
         (count(*) filter (where o.ceo_endorsed))::int,
         round(avg(o.approved_hours)::numeric,1)
  from engineer_oss_contributions_r3021 o
  group by o.contribution_type order by count(*) desc;
end $$;

-- RPC 4
create or replace function r3021_speaking_quarterly()
returns table(quarter text, talks int, attendees int, views int, pipeline_inr_total bigint)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select s.quarter,
         count(*)::int,
         coalesce(sum(s.attendee_count),0)::int,
         coalesce(sum(s.video_views),0)::int,
         coalesce(sum(s.pipeline_inr),0)::bigint
  from engineer_public_speaking_r3021 s
  group by s.quarter order by s.quarter;
end $$;

-- RPC 5
create or replace function r3021_top_talks_by_pipeline()
returns table(speaker_name text, event_name text, event_city text, pipeline_inr int, brand_lift_score int)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select s.speaker_name, s.event_name, s.event_city, s.pipeline_inr, s.brand_lift_score
  from engineer_public_speaking_r3021 s
  order by s.pipeline_inr desc nulls last
  limit 10;
end $$;

-- RPC 6
create or replace function r3021_speaking_by_country()
returns table(event_country text, talks int, attendees int, avg_brand_lift numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  select s.event_country,
         count(*)::int,
         coalesce(sum(s.attendee_count),0)::int,
         round(avg(s.brand_lift_score)::numeric,1)
  from engineer_public_speaking_r3021 s
  group by s.event_country order by sum(s.attendee_count) desc nulls last;
end $$;

-- RPC 7
create or replace function r3021_engineer_combined_impact()
returns table(engineer_name text, oss_contribs int, talks int, total_pipeline_inr bigint, avg_strategic_score numeric)
language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not is_founder() then raise exception 'not founder'; end if;
  return query
  with o as (
    select engineer_name, count(*)::int as cnt, avg(strategic_score)::numeric as avg_s
    from engineer_oss_contributions_r3021 group by engineer_name
  ), s as (
    select speaker_name as engineer_name, count(*)::int as cnt, coalesce(sum(pipeline_inr),0)::bigint as pipe
    from engineer_public_speaking_r3021 group by speaker_name
  )
  select coalesce(o.engineer_name, s.engineer_name),
         coalesce(o.cnt,0)::int,
         coalesce(s.cnt,0)::int,
         coalesce(s.pipe,0)::bigint,
         round(coalesce(o.avg_s,0),1)
  from o full outer join s on o.engineer_name = s.engineer_name
  order by coalesce(s.pipe,0) desc, coalesce(o.avg_s,0) desc;
end $$;

revoke all on function r3021_quarterly_oss_summary() from public, anon;
revoke all on function r3021_top_oss_engineers() from public, anon;
revoke all on function r3021_oss_by_type() from public, anon;
revoke all on function r3021_speaking_quarterly() from public, anon;
revoke all on function r3021_top_talks_by_pipeline() from public, anon;
revoke all on function r3021_speaking_by_country() from public, anon;
revoke all on function r3021_engineer_combined_impact() from public, anon;

grant execute on function r3021_quarterly_oss_summary() to authenticated;
grant execute on function r3021_top_oss_engineers() to authenticated;
grant execute on function r3021_oss_by_type() to authenticated;
grant execute on function r3021_speaking_quarterly() to authenticated;
grant execute on function r3021_top_talks_by_pipeline() to authenticated;
grant execute on function r3021_speaking_by_country() to authenticated;
grant execute on function r3021_engineer_combined_impact() to authenticated;
