
create schema if not exists sp_private;
revoke all on schema sp_private from public, anon, authenticated;
grant usage on schema sp_private to authenticated;

create table public.sp_workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 1 and 120),
  currency text not null default 'EUR' check (currency in ('EUR','XOF')),
  created_by uuid not null references auth.users(id),
  next_order_number bigint not null default 1 check(next_order_number > 0),
  created_at timestamptz not null default now()
);
create table public.sp_members (
  workspace_id uuid not null references public.sp_workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('owner','manager','viewer')),
  joined_at timestamptz not null default now(),
  primary key(workspace_id,user_id)
);
create index sp_members_user_idx on public.sp_members(user_id,workspace_id);
create index sp_workspaces_creator_idx on public.sp_workspaces(created_by);

create table public.sp_basins (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.sp_workspaces(id),
  name text not null check(length(btrim(name)) between 1 and 100),
  volume_l numeric(14,2) not null check(volume_l > 0),
  active boolean not null default true,
  notes text not null default '' check(length(notes)<=2000),
  version bigint not null default 1 check(version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,id)
);
create unique index sp_basins_name_idx on public.sp_basins(workspace_id,lower(btrim(name)));
create table public.sp_harvests (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.sp_workspaces(id),
  basin_id uuid not null,
  harvested_on date not null,
  fresh_weight_g bigint not null check(fresh_weight_g between 1 and 100000000),
  notes text not null default '' check(length(notes)<=2000),
  version bigint not null default 1 check(version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,id),
  unique(workspace_id,id,basin_id),
  foreign key(workspace_id,basin_id) references public.sp_basins(workspace_id,id)
);
create index sp_harvests_basin_idx on public.sp_harvests(workspace_id,basin_id);
create table public.sp_lots (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.sp_workspaces(id),
  reference text not null check(length(btrim(reference)) between 1 and 60),
  basin_id uuid not null,
  harvest_id uuid,
  produced_on date not null,
  dry_weight_g bigint not null check(dry_weight_g between 1 and 100000000),
  status text not null default 'analysis' check(status in ('analysis','released','blocked')),
  analysis_notes text not null default '' check(length(analysis_notes)<=2000),
  certificate_reference text not null default '' check(length(certificate_reference)<=120),
  certificate_expires_on date,
  version bigint not null default 1 check(version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,id),
  foreign key(workspace_id,basin_id) references public.sp_basins(workspace_id,id),
  foreign key(workspace_id,harvest_id,basin_id) references public.sp_harvests(workspace_id,id,basin_id)
);
create unique index sp_lots_reference_idx on public.sp_lots(workspace_id,lower(btrim(reference)));
create index sp_lots_basin_idx on public.sp_lots(workspace_id,basin_id);
create index sp_lots_harvest_idx on public.sp_lots(workspace_id,harvest_id,basin_id);
create table public.sp_clients (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.sp_workspaces(id),
  name text not null check(length(btrim(name)) between 1 and 120),
  email text not null default '' check(length(email)<=200 and (email='' or email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')),
  phone text not null default '' check(length(phone)<=50),
  address text not null default '' check(length(address)<=500),
  notes text not null default '' check(length(notes)<=2000),
  version bigint not null default 1 check(version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,id)
);
create table public.sp_orders (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.sp_workspaces(id),
  number text not null,
  client_id uuid not null,
  ordered_on date not null,
  currency text not null check(currency in ('EUR','XOF')),
  status text not null default 'draft' check(status in ('draft','confirmed','shipped','cancelled')),
  notes text not null default '' check(length(notes)<=2000),
  version bigint not null default 1 check(version > 0),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,id),
  unique(workspace_id,number),
  foreign key(workspace_id,client_id) references public.sp_clients(workspace_id,id)
);
create index sp_orders_client_idx on public.sp_orders(workspace_id,client_id);
create index sp_orders_created_by_idx on public.sp_orders(created_by);
create table public.sp_order_items (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null,
  order_id uuid not null,
  lot_id uuid not null,
  quantity_g bigint not null check(quantity_g between 1 and 100000000),
  unit_price_minor bigint not null check(unit_price_minor between 0 and 10000000),
  line_total_minor bigint generated always as (round(quantity_g::numeric * unit_price_minor / 1000)::bigint) stored,
  foreign key(workspace_id,order_id) references public.sp_orders(workspace_id,id) on delete cascade,
  foreign key(workspace_id,lot_id) references public.sp_lots(workspace_id,id)
);
create index sp_order_items_order_idx on public.sp_order_items(workspace_id,order_id);
create index sp_order_items_lot_idx on public.sp_order_items(workspace_id,lot_id);
create table public.sp_events (
  id bigint generated always as identity primary key,
  workspace_id uuid not null references public.sp_workspaces(id),
  actor_id uuid references auth.users(id) on delete set null,
  entity_type text not null,
  entity_id uuid not null,
  action text not null,
  changes jsonb not null default '{}',
  created_at timestamptz not null default now()
);
create index sp_events_workspace_idx on public.sp_events(workspace_id,created_at desc);
create index sp_events_actor_idx on public.sp_events(actor_id);

create function sp_private.workspace_ids() returns setof uuid
language sql stable security definer set search_path=''
as $$ select workspace_id from public.sp_members where user_id=(select auth.uid()) $$;
create function sp_private.member_role(p_workspace uuid) returns text
language sql stable security definer set search_path=''
as $$ select role from public.sp_members where workspace_id=p_workspace and user_id=(select auth.uid()) $$;
create function sp_private.lock_workspace(p_workspace uuid,p_roles text[]) returns text
language plpgsql security definer set search_path=''
as $$
declare r text;
begin
  if auth.uid() is null or not coalesce(sp_private.member_role(p_workspace)=any(p_roles),false) then
    raise exception 'Accès refusé à cet espace.' using errcode='42501';
  end if;
  perform 1 from public.sp_workspaces where id=p_workspace for update;
  select role into r from public.sp_members where workspace_id=p_workspace and user_id=auth.uid();
  if not coalesce(r=any(p_roles),false) then raise exception 'Accès refusé.' using errcode='42501'; end if;
  return r;
end $$;
create function sp_private.check_version(p_old jsonb,p_expected bigint) returns void
language plpgsql set search_path=''
as $$
begin
  if p_old is null and p_expected is not null then raise exception 'Élément introuvable.' using errcode='40001'; end if;
  if p_old is not null and (p_expected is null or (p_old->>'version')::bigint<>p_expected) then
    raise exception 'Cet élément a été modifié. Actualisez avant de réessayer.' using errcode='40001';
  end if;
end $$;
create function sp_private.record_event(p_workspace uuid,p_type text,p_id uuid,p_action text,p_before jsonb,p_after jsonb) returns void
language sql security definer set search_path=''
as $$
  insert into public.sp_events(workspace_id,actor_id,entity_type,entity_id,action,changes)
  values(p_workspace,auth.uid(),p_type,p_id,p_action,jsonb_build_object('before',p_before,'after',p_after))
$$;

alter table public.sp_workspaces enable row level security;
create policy sp_workspace_read on public.sp_workspaces for select to authenticated
using(id in (select sp_private.workspace_ids()));
do $$
declare t text;
begin
  foreach t in array array['sp_members','sp_basins','sp_harvests','sp_lots','sp_clients','sp_orders','sp_order_items'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('create policy sp_tenant_read on public.%I for select to authenticated using (workspace_id in (select sp_private.workspace_ids()))',t);
  end loop;
end $$;
alter table public.sp_events enable row level security;
create policy sp_event_read on public.sp_events for select to authenticated
using(sp_private.member_role(workspace_id) in ('owner','manager'));

create function public.sp_create_workspace(p_name text,p_currency text default 'EUR') returns uuid
language plpgsql security definer set search_path=''
as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Connexion requise.' using errcode='42501'; end if;
  if not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then
    raise exception 'Confirmez votre adresse e-mail avant de créer un espace.' using errcode='42501';
  end if;
  insert into public.sp_workspaces(name,currency,created_by) values(btrim(p_name),p_currency,auth.uid()) returning id into v_id;
  insert into public.sp_members(workspace_id,user_id,role) values(v_id,auth.uid(),'owner');
  perform sp_private.record_event(v_id,'workspace',v_id,'created',null,jsonb_build_object('name',btrim(p_name),'currency',p_currency));
  return v_id;
end $$;

create function public.sp_save_record(p_workspace uuid,p_kind text,p_record jsonb,p_expected_version bigint default null) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_table text; v_id uuid; v_old jsonb; v_new jsonb; v_engaged bigint;
begin
  perform sp_private.lock_workspace(p_workspace,array['owner','manager']);
  v_table:=case p_kind when 'basin' then 'sp_basins' when 'harvest' then 'sp_harvests' when 'lot' then 'sp_lots' when 'client' then 'sp_clients' else null end;
  if v_table is null or jsonb_typeof(p_record) is distinct from 'object' then raise exception 'Type ou données invalides.'; end if;
  v_id:=coalesce(nullif(p_record->>'id','')::uuid,gen_random_uuid());
  execute format('select to_jsonb(t) from public.%I t where workspace_id=$1 and id=$2',v_table) into v_old using p_workspace,v_id;
  perform sp_private.check_version(v_old,p_expected_version);

  if p_kind='basin' then
    insert into public.sp_basins as t(id,workspace_id,name,volume_l,active,notes)
    values(v_id,p_workspace,btrim(p_record->>'name'),(p_record->>'volume_l')::numeric,coalesce((p_record->>'active')::boolean,true),coalesce(p_record->>'notes',''))
    on conflict(id) do update set name=excluded.name,volume_l=excluded.volume_l,active=excluded.active,notes=excluded.notes,version=t.version+1,updated_at=now()
    where t.workspace_id=excluded.workspace_id returning to_jsonb(t) into v_new;
  elsif p_kind='harvest' then
    insert into public.sp_harvests as t(id,workspace_id,basin_id,harvested_on,fresh_weight_g,notes)
    values(v_id,p_workspace,(p_record->>'basin_id')::uuid,(p_record->>'harvested_on')::date,(p_record->>'fresh_weight_g')::bigint,coalesce(p_record->>'notes',''))
    on conflict(id) do update set basin_id=excluded.basin_id,harvested_on=excluded.harvested_on,fresh_weight_g=excluded.fresh_weight_g,notes=excluded.notes,version=t.version+1,updated_at=now()
    where t.workspace_id=excluded.workspace_id returning to_jsonb(t) into v_new;
  elsif p_kind='lot' then
    select coalesce(sum(i.quantity_g),0) into v_engaged
    from public.sp_order_items i join public.sp_orders o on o.workspace_id=i.workspace_id and o.id=i.order_id
    where i.workspace_id=p_workspace and i.lot_id=v_id and o.status in ('confirmed','shipped');
    if (p_record->>'dry_weight_g')::bigint<v_engaged then raise exception 'La masse ne peut pas être inférieure aux quantités réservées ou expédiées.'; end if;
    if v_old is not null and exists(select 1 from public.sp_order_items where workspace_id=p_workspace and lot_id=v_id) and
      ((v_old->>'reference') is distinct from btrim(p_record->>'reference')
       or (v_old->>'basin_id')::uuid is distinct from (p_record->>'basin_id')::uuid
       or (v_old->>'harvest_id')::uuid is distinct from nullif(p_record->>'harvest_id','')::uuid
       or (v_old->>'produced_on')::date is distinct from (p_record->>'produced_on')::date) then
      raise exception 'La provenance d''un lot lié à une commande est protégée.';
    end if;
    insert into public.sp_lots as t(id,workspace_id,reference,basin_id,harvest_id,produced_on,dry_weight_g,status,analysis_notes,certificate_reference,certificate_expires_on)
    values(v_id,p_workspace,btrim(p_record->>'reference'),(p_record->>'basin_id')::uuid,nullif(p_record->>'harvest_id','')::uuid,(p_record->>'produced_on')::date,
      (p_record->>'dry_weight_g')::bigint,coalesce(p_record->>'status','analysis'),coalesce(p_record->>'analysis_notes',''),coalesce(p_record->>'certificate_reference',''),nullif(p_record->>'certificate_expires_on','')::date)
    on conflict(id) do update set reference=excluded.reference,basin_id=excluded.basin_id,harvest_id=excluded.harvest_id,produced_on=excluded.produced_on,
      dry_weight_g=excluded.dry_weight_g,status=excluded.status,analysis_notes=excluded.analysis_notes,certificate_reference=excluded.certificate_reference,
      certificate_expires_on=excluded.certificate_expires_on,version=t.version+1,updated_at=now()
    where t.workspace_id=excluded.workspace_id returning to_jsonb(t) into v_new;
  else
    insert into public.sp_clients as t(id,workspace_id,name,email,phone,address,notes)
    values(v_id,p_workspace,btrim(p_record->>'name'),btrim(coalesce(p_record->>'email','')),coalesce(p_record->>'phone',''),coalesce(p_record->>'address',''),coalesce(p_record->>'notes',''))
    on conflict(id) do update set name=excluded.name,email=excluded.email,phone=excluded.phone,address=excluded.address,notes=excluded.notes,version=t.version+1,updated_at=now()
    where t.workspace_id=excluded.workspace_id returning to_jsonb(t) into v_new;
  end if;
  if v_new is null then raise exception 'Identifiant déjà utilisé.'; end if;
  perform sp_private.record_event(p_workspace,p_kind,v_id,case when v_old is null then 'created' else 'updated' end,v_old,v_new);
  return v_new;
end $$;

create function public.sp_save_order(p_workspace uuid,p_order jsonb,p_items jsonb,p_expected_version bigint default null) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_id uuid; v_old jsonb; v_new jsonb; v_number text; v_next bigint; v_currency text; v_line record; v_count integer;
begin
  perform sp_private.lock_workspace(p_workspace,array['owner','manager']);
  if jsonb_typeof(p_order) is distinct from 'object' or jsonb_typeof(p_items) is distinct from 'array' then raise exception 'Commande invalide.'; end if;
  v_count:=jsonb_array_length(p_items);
  if v_count not between 1 and 50 then raise exception 'Une commande doit contenir entre 1 et 50 lignes.'; end if;
  v_id:=coalesce(nullif(p_order->>'id','')::uuid,gen_random_uuid());
  select to_jsonb(o) into v_old from public.sp_orders o where workspace_id=p_workspace and id=v_id;
  perform sp_private.check_version(v_old,p_expected_version);
  if v_old is not null and v_old->>'status'<>'draft' then raise exception 'Seuls les brouillons sont modifiables.'; end if;
  for v_line in select * from jsonb_to_recordset(p_items) as x(lot_id uuid,quantity_g bigint,unit_price_minor bigint) loop
    if v_line.quantity_g is null or v_line.quantity_g not between 1 and 100000000 or v_line.unit_price_minor is null or v_line.unit_price_minor not between 0 and 10000000 then raise exception 'Quantité ou prix invalide.'; end if;
    if not exists(select 1 from public.sp_lots where workspace_id=p_workspace and id=v_line.lot_id and status='released') then raise exception 'Le lot est introuvable ou non libéré.'; end if;
  end loop;
  select currency into v_currency from public.sp_workspaces where id=p_workspace;
  if v_old is null then
    update public.sp_workspaces set next_order_number=next_order_number+1 where id=p_workspace returning next_order_number-1 into v_next;
    v_number:='SP-'||extract(year from current_date)::text||'-'||lpad(v_next::text,greatest(6,length(v_next::text)),'0');
    insert into public.sp_orders(id,workspace_id,number,client_id,ordered_on,currency,notes,created_by)
    values(v_id,p_workspace,v_number,(p_order->>'client_id')::uuid,(p_order->>'ordered_on')::date,v_currency,coalesce(p_order->>'notes',''),auth.uid());
  else
    update public.sp_orders set client_id=(p_order->>'client_id')::uuid,ordered_on=(p_order->>'ordered_on')::date,
      notes=coalesce(p_order->>'notes',''),version=version+1,updated_at=now()
    where workspace_id=p_workspace and id=v_id;
    delete from public.sp_order_items where workspace_id=p_workspace and order_id=v_id;
  end if;
  insert into public.sp_order_items(workspace_id,order_id,lot_id,quantity_g,unit_price_minor)
  select p_workspace,v_id,x.lot_id,x.quantity_g,x.unit_price_minor
  from jsonb_to_recordset(p_items) as x(lot_id uuid,quantity_g bigint,unit_price_minor bigint);
  select to_jsonb(o) into v_new from public.sp_orders o where workspace_id=p_workspace and id=v_id;
  v_new:=v_new||jsonb_build_object('items',(select jsonb_agg(to_jsonb(i)) from public.sp_order_items i where workspace_id=p_workspace and order_id=v_id));
  perform sp_private.record_event(p_workspace,'order',v_id,case when v_old is null then 'created' else 'updated' end,v_old,v_new);
  return v_new;
end $$;

create function public.sp_transition_order(p_workspace uuid,p_order uuid,p_status text,p_expected_version bigint) returns jsonb
language plpgsql security definer set search_path=''
as $$
declare v_old jsonb; v_new jsonb; v_line record; v_used bigint; v_mass bigint;
begin
  perform sp_private.lock_workspace(p_workspace,array['owner','manager']);
  select to_jsonb(o) into v_old from public.sp_orders o where workspace_id=p_workspace and id=p_order;
  if v_old is null then raise exception 'Commande introuvable.'; end if;
  perform sp_private.check_version(v_old,p_expected_version);
  if not coalesce(((v_old->>'status'='draft' and p_status in ('confirmed','cancelled')) or
    (v_old->>'status'='confirmed' and p_status in ('shipped','cancelled'))),false) then raise exception 'Changement de statut interdit.'; end if;
  if p_status in ('confirmed','shipped') then
    if not exists(select 1 from public.sp_order_items where workspace_id=p_workspace and order_id=p_order) then raise exception 'Commande vide.'; end if;
    for v_line in select lot_id,sum(quantity_g) as requested from public.sp_order_items where workspace_id=p_workspace and order_id=p_order group by lot_id order by lot_id loop
      select dry_weight_g into v_mass from public.sp_lots where workspace_id=p_workspace and id=v_line.lot_id and status='released';
      if v_mass is null then raise exception 'Un lot est bloqué ou en analyse.'; end if;
      if p_status='confirmed' then
        select coalesce(sum(i.quantity_g),0) into v_used from public.sp_order_items i
        join public.sp_orders o on o.workspace_id=i.workspace_id and o.id=i.order_id
        where i.workspace_id=p_workspace and i.lot_id=v_line.lot_id and i.order_id<>p_order and o.status in ('confirmed','shipped');
        if v_used+v_line.requested>v_mass then raise exception 'Stock insuffisant pour le lot %.',v_line.lot_id; end if;
      end if;
    end loop;
  end if;
  update public.sp_orders as o set status=p_status,version=version+1,updated_at=now()
  where workspace_id=p_workspace and id=p_order returning to_jsonb(o) into v_new;
  perform sp_private.record_event(p_workspace,'order',p_order,'status_changed',v_old,v_new);
  return v_new;
end $$;

create function public.sp_delete_record(p_workspace uuid,p_kind text,p_id uuid,p_expected_version bigint) returns void
language plpgsql security definer set search_path=''
as $$
declare v_table text; v_old jsonb;
begin
  perform sp_private.lock_workspace(p_workspace,array['owner','manager']);
  v_table:=case p_kind when 'basin' then 'sp_basins' when 'harvest' then 'sp_harvests' when 'lot' then 'sp_lots' when 'client' then 'sp_clients' when 'order' then 'sp_orders' else null end;
  if v_table is null then raise exception 'Type inconnu.'; end if;
  execute format('select to_jsonb(t) from public.%I t where workspace_id=$1 and id=$2',v_table) into v_old using p_workspace,p_id;
  if v_old is null then raise exception 'Élément introuvable.'; end if;
  perform sp_private.check_version(v_old,p_expected_version);
  if p_kind='order' and v_old->>'status'<>'draft' then raise exception 'Seuls les brouillons peuvent être supprimés.'; end if;
  execute format('delete from public.%I where workspace_id=$1 and id=$2',v_table) using p_workspace,p_id;
  perform sp_private.record_event(p_workspace,p_kind,p_id,'deleted',v_old,null);
end $$;

create view public.sp_lot_stock with(security_invoker=true) as
select l.*, coalesce(s.reserved_g,0)::bigint as reserved_g,coalesce(s.shipped_g,0)::bigint as shipped_g,
  (l.dry_weight_g-coalesce(s.shipped_g,0))::bigint as physical_g,
  (l.dry_weight_g-coalesce(s.shipped_g,0)-coalesce(s.reserved_g,0))::bigint as available_g,
  (case when l.status='released' then l.dry_weight_g-coalesce(s.shipped_g,0)-coalesce(s.reserved_g,0) else 0 end)::bigint as sellable_g
from public.sp_lots l left join lateral (
  select sum(i.quantity_g) filter(where o.status='confirmed') as reserved_g,sum(i.quantity_g) filter(where o.status='shipped') as shipped_g
  from public.sp_order_items i join public.sp_orders o on o.workspace_id=i.workspace_id and o.id=i.order_id
  where i.workspace_id=l.workspace_id and i.lot_id=l.id
) s on true;
create view public.sp_order_totals with(security_invoker=true) as
select o.*,coalesce(s.total_minor,0)::bigint as total_minor,coalesce(s.quantity_g,0)::bigint as quantity_g
from public.sp_orders o left join lateral(
 select sum(line_total_minor) as total_minor,sum(quantity_g) as quantity_g from public.sp_order_items i where i.workspace_id=o.workspace_id and i.order_id=o.id
) s on true;

revoke all on public.sp_workspaces,public.sp_members,public.sp_basins,public.sp_harvests,public.sp_lots,public.sp_clients,public.sp_orders,public.sp_order_items,public.sp_events,public.sp_lot_stock,public.sp_order_totals from public,anon,authenticated;
grant select on public.sp_workspaces,public.sp_members,public.sp_basins,public.sp_harvests,public.sp_lots,public.sp_clients,public.sp_orders,public.sp_order_items,public.sp_events,public.sp_lot_stock,public.sp_order_totals to authenticated;
revoke all on sequence public.sp_events_id_seq from public,anon,authenticated;
revoke all on all functions in schema sp_private from public,anon,authenticated;
grant execute on function sp_private.workspace_ids(),sp_private.member_role(uuid) to authenticated;
revoke all on function public.sp_create_workspace(text,text),public.sp_save_record(uuid,text,jsonb,bigint),public.sp_save_order(uuid,jsonb,jsonb,bigint),public.sp_transition_order(uuid,uuid,text,bigint),public.sp_delete_record(uuid,text,uuid,bigint) from public,anon,authenticated;
grant execute on function public.sp_create_workspace(text,text),public.sp_save_record(uuid,text,jsonb,bigint),public.sp_save_order(uuid,jsonb,jsonb,bigint),public.sp_transition_order(uuid,uuid,text,bigint),public.sp_delete_record(uuid,text,uuid,bigint) to authenticated;
comment on function public.sp_save_order(uuid,jsonb,jsonb,bigint) is 'Prix par kilogramme en centimes EUR ou francs XOF. Stock réservé uniquement à la confirmation.';
comment on function sp_private.lock_workspace(uuid,text[]) is 'Toutes les mutations métier verrouillent la même ligne entreprise pour sérialiser les réservations concurrentes.';
