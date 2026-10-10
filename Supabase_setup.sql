-- DailyBudget schema. Run once in Supabase > SQL Editor.
create table public.profiles(id uuid primary key references auth.users(id) on delete cascade, display_name text, created_at timestamptz default now());
create table public.preferences(user_id uuid primary key references auth.users(id) on delete cascade, currency text not null default 'USD', daily_limit numeric(12,2) not null default 0 check(daily_limit>=0), rollover boolean not null default false, updated_at timestamptz default now());
create table public.transactions(id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 type text not null check(type in('income','expense')), amount numeric(12,2) not null check(amount>0 and amount<1e10), currency text not null default 'USD',
 tx_date date not null, category text not null, description text, payment_method text, essential boolean not null default true, notes text,
 created_at timestamptz default now(), updated_at timestamptz default now());
create table public.budgets(id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 month text not null check(month ~ '^\d{4}-\d{2}$'), category text not null, limit_amount numeric(12,2) not null check(limit_amount>=0), unique(user_id,month,category));
create table public.bills(id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null, amount numeric(12,2) not null check(amount>0), due_date date not null, recurrence text not null default 'none' check(recurrence in('none','weekly','monthly','annually')),
 status text not null default 'unpaid' check(status in('unpaid','paid')), notes text,
 last_paid_transaction_id uuid references public.transactions(id) on delete set null, created_at timestamptz default now());
create table public.goals(id uuid primary key default gen_random_uuid(), user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
 name text not null, target_amount numeric(12,2) not null check(target_amount>0), saved_amount numeric(12,2) not null default 0 check(saved_amount>=0), target_date date, description text, created_at timestamptz default now());
create index on public.transactions(user_id,tx_date desc); create index on public.budgets(user_id,month); create index on public.bills(user_id,due_date); create index on public.goals(user_id);

do $$ declare t text; begin
 foreach t in array array['profiles','preferences','transactions','budgets','bills','goals'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('create policy "sel" on public.%I for select to authenticated using (%s = auth.uid())',t,case when t='profiles' then 'id' else case when t='preferences' then 'user_id' else 'user_id' end end);
  execute format('create policy "ins" on public.%I for insert to authenticated with check (%s = auth.uid())',t,case when t='profiles' then 'id' else 'user_id' end);
  execute format('create policy "upd" on public.%I for update to authenticated using (%s = auth.uid()) with check (%s = auth.uid())',t,case when t='profiles' then 'id' else 'user_id' end,case when t='profiles' then 'id' else 'user_id' end);
  execute format('create policy "del" on public.%I for delete to authenticated using (%s = auth.uid())',t,case when t='profiles' then 'id' else 'user_id' end);
 end loop; end $$;

-- Account deletion (cascades to all user rows)
create or replace function public.delete_my_account() returns void language sql security definer set search_path='' as $$ delete from auth.users where id=auth.uid(); $$;
revoke all on function public.delete_my_account() from public, anon; grant execute on function public.delete_my_account() to authenticated;
