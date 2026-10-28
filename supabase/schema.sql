-- CashPilot single-business backend. Run in a dedicated Supabase project.
-- All access passes through the JWT-verified Edge Function; no direct browser table policies.
create schema if not exists cashpilot;
revoke all on schema cashpilot from public,anon,authenticated;
grant usage on schema cashpilot to service_role;
create table cashpilot.profiles(id uuid primary key references auth.users(id) on delete restrict,name text not null check(length(name)>0),role text not null check(role in ('OWNER','FINANCE ADMIN','STAFF','VIEWER')),active boolean not null default true);
create table cashpilot.meta(id boolean primary key default true check(id),revision bigint not null default 0,settings jsonb not null,sequences jsonb not null default '{}',requests jsonb not null default '[]',read_alerts jsonb not null default '[]',updated_at timestamptz not null default now(),last_result jsonb);
insert into cashpilot.meta(id,settings) values(true,'{"businessName":"AKSA Studio","currency":"IDR","minimumCashBuffer":5000000,"invoicePrefix":"INV","invoiceTerms":14,"defaultTax":0,"paymentInstructions":"Please include the invoice number in your payment reference. Contact AKSA Studio for verified payment details.","address":"Yogyakarta, Indonesia","email":"hello@aksa.example","phone":"","logo":null}');
create table cashpilot.accounts(id text primary key,data jsonb not null,name text generated always as(lower(data->>'name')) stored unique not null);
create table cashpilot.categories(id text primary key,data jsonb not null,name text generated always as(lower(data->>'name')) stored not null,type text generated always as(data->>'type') stored check(type in ('income','expense')),unique(name,type));
create table cashpilot.customers(id text primary key,data jsonb not null);
create table cashpilot.suppliers(id text primary key,data jsonb not null);
create table cashpilot.invoices(id text primary key,data jsonb not null,number text generated always as(data->>'number') stored unique not null,customer_id text generated always as(data->>'customerId') stored references cashpilot.customers(id),account_id text generated always as(data->>'accountId') stored references cashpilot.accounts(id),category_id text generated always as(data->>'categoryId') stored references cashpilot.categories(id),share_token text generated always as(data->>'shareToken') stored unique,check((data->>'total')::bigint>0));
create table cashpilot.invoice_items(id text primary key,invoice_id text not null references cashpilot.invoices(id),data jsonb not null,check((data->>'quantity')::numeric>0),check((data->>'rate')::bigint>=0));
create table cashpilot.bills(id text primary key,data jsonb not null,number text generated always as(data->>'number') stored unique not null,supplier_id text generated always as(data->>'supplierId') stored references cashpilot.suppliers(id),account_id text generated always as(data->>'accountId') stored references cashpilot.accounts(id),category_id text generated always as(data->>'categoryId') stored references cashpilot.categories(id),external_number text generated always as(lower(data->>'externalNumber')) stored,unique(supplier_id,external_number),check((data->>'total')::bigint>0));
create table cashpilot.transactions(id text primary key,data jsonb not null,account_id text generated always as(data->>'accountId') stored not null references cashpilot.accounts(id),category_id text generated always as(nullif(data->>'categoryId','')) stored references cashpilot.categories(id),amount bigint generated always as((data->>'amount')::bigint) stored check(amount<>0),posted_date date generated always as(make_date(substring(data->>'date',1,4)::int,substring(data->>'date',6,2)::int,substring(data->>'date',9,2)::int)) stored,import_key text generated always as(nullif(data->>'importKey','')) stored unique);
create index account_date on cashpilot.transactions(account_id,posted_date);
create table cashpilot.invoice_payments(id text primary key,data jsonb not null,document_id text generated always as(data->>'documentId') stored not null references cashpilot.invoices(id),transaction_id text generated always as(data->>'transactionId') stored unique not null references cashpilot.transactions(id),amount bigint generated always as((data->>'amount')::bigint) stored check(amount>0),token text generated always as(data->>'token') stored unique not null);
create unique index unique_customer_payment_reference on cashpilot.invoice_payments(document_id,(data->>'reference')) where coalesce(data->>'reference','')<>'';
create table cashpilot.bill_payments(id text primary key,data jsonb not null,document_id text generated always as(data->>'documentId') stored not null references cashpilot.bills(id),transaction_id text generated always as(data->>'transactionId') stored unique not null references cashpilot.transactions(id),amount bigint generated always as((data->>'amount')::bigint) stored check(amount>0));
create unique index unique_supplier_payment_reference on cashpilot.bill_payments(document_id,(data->>'reference')) where coalesce(data->>'reference','')<>'';
create table cashpilot.transfers(id text primary key,data jsonb not null,from_id text generated always as(data->>'fromId') stored references cashpilot.accounts(id),to_id text generated always as(data->>'toId') stored references cashpilot.accounts(id),check(from_id<>to_id),check((data->>'amount')::bigint>0));
create table cashpilot.recurring_transactions(id text primary key,data jsonb not null,account_id text generated always as(data->>'accountId') stored references cashpilot.accounts(id),check((data->>'amount')::bigint>0));
create table cashpilot.recurring_posts(id text primary key,data jsonb not null,recurring_id text generated always as(data->>'recurringId') stored references cashpilot.recurring_transactions(id),transaction_id text generated always as(data->>'transactionId') stored unique references cashpilot.transactions(id),occurrence text generated always as(data->>'occurrenceDate') stored,unique(recurring_id,occurrence));
create table cashpilot.forecast_events(id text primary key,data jsonb not null,account_id text generated always as(data->>'accountId') stored references cashpilot.accounts(id),check((data->>'amount')::bigint>0));
create table cashpilot.budgets(id text primary key,data jsonb not null,category_id text generated always as(data->>'categoryId') stored references cashpilot.categories(id),month text generated always as(data->>'month') stored,unique(category_id,month),check((data->>'amount')::bigint>0));
create table cashpilot.reversals(id text primary key,data jsonb not null,transaction_id text generated always as(data->>'transactionId') stored unique references cashpilot.transactions(id),reversal_id text generated always as(data->>'reversalId') stored unique references cashpilot.transactions(id));
create table cashpilot.reconciliations(id text primary key,data jsonb not null,account_id text generated always as(data->>'accountId') stored references cashpilot.accounts(id));
create table cashpilot.audit_logs(id text primary key,data jsonb not null);
create view cashpilot.account_balances as select a.id,coalesce(sum(t.amount) filter(where t.posted_date<=current_date),0) balance from cashpilot.accounts a left join cashpilot.transactions t on t.account_id=a.id group by a.id;
insert into cashpilot.accounts(id,data) values('acc-cash','{"id":"acc-cash","name":"Cash","type":"Cash","active":true,"allowOverdraft":false,"notes":""}');
insert into cashpilot.accounts(id,data) values('acc-bank','{"id":"acc-bank","name":"Main Bank","type":"Bank Account","active":true,"allowOverdraft":false,"notes":""}');
insert into cashpilot.accounts(id,data) values('acc-wallet','{"id":"acc-wallet","name":"Digital Wallet","type":"Digital Wallet","active":true,"allowOverdraft":false,"notes":""}');
insert into cashpilot.categories(id,data) values('cat-income-0','{"id":"cat-income-0","name":"AI Creative Services","type":"income","active":true}');
insert into cashpilot.categories(id,data) values('cat-income-1','{"id":"cat-income-1","name":"Design Projects","type":"income","active":true}');
insert into cashpilot.categories(id,data) values('cat-income-2','{"id":"cat-income-2","name":"Digital Products","type":"income","active":true}');
insert into cashpilot.categories(id,data) values('cat-income-3','{"id":"cat-income-3","name":"Training","type":"income","active":true}');
insert into cashpilot.categories(id,data) values('cat-income-4','{"id":"cat-income-4","name":"Retainers","type":"income","active":true}');
insert into cashpilot.categories(id,data) values('cat-income-5','{"id":"cat-income-5","name":"Other Income","type":"income","active":true}');
insert into cashpilot.categories(id,data) values('cat-expense-0','{"id":"cat-expense-0","name":"Software","type":"expense","active":true}');
insert into cashpilot.categories(id,data) values('cat-expense-1','{"id":"cat-expense-1","name":"Marketing","type":"expense","active":true}');
insert into cashpilot.categories(id,data) values('cat-expense-2','{"id":"cat-expense-2","name":"Rent","type":"expense","active":true}');
insert into cashpilot.categories(id,data) values('cat-expense-3','{"id":"cat-expense-3","name":"Utilities","type":"expense","active":true}');
insert into cashpilot.categories(id,data) values('cat-expense-4','{"id":"cat-expense-4","name":"Contractors","type":"expense","active":true}');
insert into cashpilot.categories(id,data) values('cat-expense-5','{"id":"cat-expense-5","name":"Salary","type":"expense","active":true}');
insert into cashpilot.categories(id,data) values('cat-expense-6','{"id":"cat-expense-6","name":"Transportation","type":"expense","active":true}');
insert into cashpilot.categories(id,data) values('cat-expense-7','{"id":"cat-expense-7","name":"Equipment","type":"expense","active":true}');
insert into cashpilot.categories(id,data) values('cat-expense-8','{"id":"cat-expense-8","name":"Inventory","type":"expense","active":true}');
insert into cashpilot.categories(id,data) values('cat-expense-9','{"id":"cat-expense-9","name":"Professional Services","type":"expense","active":true}');
insert into cashpilot.categories(id,data) values('cat-expense-10','{"id":"cat-expense-10","name":"Other Expenses","type":"expense","active":true}');
do $$ declare t record; begin for t in select tablename from pg_tables where schemaname='cashpilot' loop execute format('alter table cashpilot.%I enable row level security',t.tablename); end loop; end $$;
grant all on all tables in schema cashpilot to service_role;
create or replace function public.cashpilot_profile(p_user uuid) returns jsonb language sql security definer set search_path=cashpilot,pg_temp as $$
select jsonb_build_object('id',id,'name',name,'role',role) from cashpilot.profiles where id=p_user and active;
$$;
create or replace function public.cashpilot_read() returns jsonb language plpgsql security definer set search_path=cashpilot,pg_temp as $$
declare m cashpilot.meta;s jsonb;t text;k text;v jsonb;
begin
select * into m from cashpilot.meta where id=true;
s=jsonb_build_object('schemaVersion',1,'revision',m.revision,'settings',m.settings,'sequences',m.sequences,'requests',m.requests,'readAlerts',m.read_alerts,'updatedAt',m.updated_at,'lastResult',m.last_result);
for t,k in select * from (values('accounts','accounts'),('categories','categories'),('customers','customers'),('suppliers','suppliers'),('transactions','transactions'),('invoices','invoices'),('bills','bills'),('invoice_payments','invoicePayments'),('bill_payments','billPayments'),('transfers','transfers'),('recurring_transactions','recurring'),('recurring_posts','recurringPosts'),('forecast_events','events'),('budgets','budgets'),('reversals','reversals'),('reconciliations','reconciliations'),('audit_logs','audit')) v(t,k) loop
execute format('select coalesce(jsonb_agg(data order by coalesce(data->>''at'',data->>''createdAt'',''''),id),''[]''::jsonb) from cashpilot.%I',t) into v;
s=jsonb_set(s,array[k],v);
end loop;
select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'role',role) order by name),'[]'::jsonb) into v from cashpilot.profiles where active;
return jsonb_set(s,array['profiles'],v);
end $$;
create or replace function public.cashpilot_commit(p_state jsonb,p_expected bigint) returns void language plpgsql security definer set search_path=cashpilot,pg_temp as $$
declare rev bigint;t text;k text;r jsonb;old jsonb;n int;line jsonb;
begin
select revision into rev from cashpilot.meta where id=true for update;
if rev<>p_expected then raise exception 'WORKSPACE_CONFLICT: refresh and retry';end if;
if (p_state->>'revision')::bigint<>p_expected+1 then raise exception 'Invalid revision';end if;
-- Mutable master records and unpaid documents; command rules authorize individual edits.
for t,k in select * from (values('accounts','accounts'),('categories','categories'),('customers','customers'),('suppliers','suppliers'),('invoices','invoices'),('bills','bills'),('recurring_transactions','recurring'),('forecast_events','events'),('budgets','budgets')) v(t,k) loop
for r in select value from jsonb_array_elements(p_state->k) loop
execute format('insert into cashpilot.%I(id,data) values($1,$2) on conflict(id) do update set data=excluded.data',t) using r->>'id',r;
end loop;
end loop;
-- Financial history is append-only: reject changes or omission of any existing row.
for t,k in select * from (values('transactions','transactions'),('invoice_payments','invoicePayments'),('bill_payments','billPayments'),('transfers','transfers'),('recurring_posts','recurringPosts'),('reversals','reversals'),('reconciliations','reconciliations'),('audit_logs','audit')) v(t,k) loop
execute format('select count(*) from cashpilot.%I a where not exists(select 1 from jsonb_array_elements($1) x where x->>''id''=a.id)',t) into n using p_state->k;
if n>0 then raise exception 'Financial history cannot be deleted';end if;
for r in select value from jsonb_array_elements(p_state->k) loop
execute format('select data from cashpilot.%I where id=$1',t) into old using r->>'id';
if old is not null and old<>r then raise exception 'Financial history is immutable';end if;
execute format('insert into cashpilot.%I(id,data) values($1,$2) on conflict(id) do nothing',t) using r->>'id',r;
end loop;
end loop;
for r in select value from jsonb_array_elements(p_state->'invoices') loop
delete from cashpilot.invoice_items where invoice_id=r->>'id';n=0;
for line in select value from jsonb_array_elements(r->'items') loop
insert into cashpilot.invoice_items(id,invoice_id,data) values((r->>'id')||'-'||n,r->>'id',line);n=n+1;
end loop;end loop;
if exists(select 1 from cashpilot.invoices i join lateral(select coalesce(sum(amount),0) n from cashpilot.invoice_payments where document_id=i.id) p on true where p.n>(i.data->>'total')::bigint)
or exists(select 1 from cashpilot.bills b join lateral(select coalesce(sum(amount),0) n from cashpilot.bill_payments where document_id=b.id) p on true where p.n>(b.data->>'total')::bigint) then raise exception 'Document overpayment';end if;
if exists(select 1 from cashpilot.invoice_payments p join cashpilot.transactions t on t.id=p.transaction_id where t.amount<>p.amount or t.data->>'sourceId'<>p.id or t.account_id<>p.data->>'accountId')
or exists(select 1 from cashpilot.bill_payments p join cashpilot.transactions t on t.id=p.transaction_id where t.amount<>-p.amount or t.data->>'sourceId'<>p.id or t.account_id<>p.data->>'accountId') then raise exception 'Payment ledger mismatch';end if;
if exists(select 1 from cashpilot.accounts a join cashpilot.account_balances b on b.id=a.id where not coalesce((a.data->>'allowOverdraft')::boolean,false) and b.balance<0) then raise exception 'Negative account balance';end if;
if exists(select 1 from cashpilot.transfers r where (select count(*) from cashpilot.transactions t where t.data->>'sourceType'='transfer' and t.data->>'sourceId'=r.id)<>2 or (select sum(amount) from cashpilot.transactions t where t.data->>'sourceId'=r.id)<>0) then raise exception 'Broken transfer';end if;
update cashpilot.meta set revision=(p_state->>'revision')::bigint,settings=p_state->'settings',sequences=p_state->'sequences',requests=p_state->'requests',read_alerts=p_state->'readAlerts',last_result=p_state->'lastResult',updated_at=now() where id=true;
end $$;
revoke all on function public.cashpilot_profile(uuid),public.cashpilot_read(),public.cashpilot_commit(jsonb,bigint) from public,anon,authenticated;
grant execute on function public.cashpilot_profile(uuid),public.cashpilot_read(),public.cashpilot_commit(jsonb,bigint) to service_role;
-- Private storage. Only the server function creates short-lived signed URLs after permission filtering.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('cashpilot-documents','cashpilot-documents',false,2097152,array['image/jpeg','image/png','image/webp','application/pdf']) on conflict(id) do nothing;
-- After creating an Auth user, provision a role through trusted SQL, e.g.
-- insert into cashpilot.profiles(id,name,role) values('<auth-user-uuid>','Business Owner','OWNER');
