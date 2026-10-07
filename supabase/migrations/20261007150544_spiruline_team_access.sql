
alter table public.sp_workspaces add column version bigint not null default 1 check(version>0);

create table sp_private.invitations (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.sp_workspaces(id),
  email text not null check(length(email)<=200 and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  role text not null check(role in ('manager','viewer')),
  token_hash text not null unique,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_at timestamptz,
  revoked_at timestamptz
);
create index sp_invitations_workspace_idx on sp_private.invitations(workspace_id);
create index sp_invitations_created_by_idx on sp_private.invitations(created_by);
alter table sp_private.invitations enable row level security;
revoke all on sp_private.invitations from public,anon,authenticated;

create function public.sp_update_workspace(p_workspace uuid,p_name text,p_currency text,p_expected_version bigint) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_old jsonb; v_new jsonb;
begin
  perform sp_private.lock_workspace(p_workspace,array['owner']);
  select to_jsonb(w) into v_old from public.sp_workspaces w where id=p_workspace;
  perform sp_private.check_version(v_old,p_expected_version);
  if p_currency is distinct from (v_old->>'currency') and exists(select 1 from public.sp_orders where workspace_id=p_workspace) then
    raise exception 'La devise est verrouillée dès la première commande. Aucune conversion automatique des prix.';
  end if;
  update public.sp_workspaces w set name=btrim(p_name),currency=p_currency,version=version+1 where id=p_workspace returning to_jsonb(w) into v_new;
  perform sp_private.record_event(p_workspace,'workspace',p_workspace,'updated',v_old,v_new);
  return v_new;
end $$;

create function public.sp_create_invitation(p_workspace uuid,p_email text,p_role text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v_token text; v_hash text; v_id uuid; v_expiry timestamptz;
begin
  perform sp_private.lock_workspace(p_workspace,array['owner']);
  if p_role is null or p_role not in ('manager','viewer') then raise exception 'Rôle invalide.'; end if;
  if (select count(*) from sp_private.invitations where workspace_id=p_workspace and expires_at>now() and accepted_at is null and revoked_at is null)>=100 then
    raise exception 'Révoquez des invitations anciennes avant d''en créer de nouvelles.';
  end if;
  v_token:=replace(gen_random_uuid()::text||gen_random_uuid()::text,'-','');
  v_hash:=encode(sha256(convert_to(v_token,'UTF8')),'hex');
  v_expiry:=now()+interval '7 days';
  insert into sp_private.invitations(workspace_id,email,role,token_hash,created_by,expires_at)
    values(p_workspace,lower(btrim(p_email)),p_role,v_hash,auth.uid(),v_expiry) returning id into v_id;
  perform sp_private.record_event(p_workspace,'invitation',v_id,'created',null,jsonb_build_object('email',lower(btrim(p_email)),'role',p_role,'expires_at',v_expiry));
  return jsonb_build_object('id',v_id,'token',v_token,'expires_at',v_expiry);
end $$;

create function public.sp_accept_invitation(p_token text) returns uuid
language plpgsql security definer set search_path='' as $$
declare v_hash text; v_workspace uuid; v_invite sp_private.invitations; v_email text;
begin
  if auth.uid() is null then raise exception 'Connexion requise.' using errcode='42501'; end if;
  if p_token is null or p_token !~ '^[0-9a-f]{64}$' then raise exception 'Invitation invalide.'; end if;
  select lower(email) into v_email from auth.users where id=auth.uid() and email_confirmed_at is not null;
  if v_email is null then raise exception 'Adresse e-mail vérifiée requise.' using errcode='42501'; end if;
  v_hash:=encode(sha256(convert_to(p_token,'UTF8')),'hex');
  select workspace_id into v_workspace from sp_private.invitations where token_hash=v_hash and email=v_email;
  if v_workspace is null then raise exception 'Invitation invalide pour ce compte.' using errcode='42501'; end if;
  perform 1 from public.sp_workspaces where id=v_workspace for update;
  select * into v_invite from sp_private.invitations where token_hash=v_hash for update;
  if v_invite.id is null or v_invite.expires_at<=now() or v_invite.accepted_at is not null or v_invite.revoked_at is not null then
    raise exception 'Invitation expirée, révoquée ou déjà utilisée.';
  end if;
  insert into public.sp_members(workspace_id,user_id,role) values(v_workspace,auth.uid(),v_invite.role)
    on conflict(workspace_id,user_id) do nothing;
  update sp_private.invitations set accepted_at=now() where id=v_invite.id;
  perform sp_private.record_event(v_workspace,'invitation',v_invite.id,'accepted',null,jsonb_build_object('user_id',auth.uid(),'role',sp_private.member_role(v_workspace)));
  return v_workspace;
end $$;

create function public.sp_list_invitations(p_workspace uuid)
returns table(id uuid,email text,role text,created_at timestamptz,expires_at timestamptz,accepted_at timestamptz,revoked_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
  if sp_private.member_role(p_workspace) is distinct from 'owner' then raise exception 'Accès refusé.' using errcode='42501'; end if;
  return query select i.id,i.email,i.role,i.created_at,i.expires_at,i.accepted_at,i.revoked_at
    from sp_private.invitations i where i.workspace_id=p_workspace order by i.created_at desc;
end $$;

create function public.sp_revoke_invitation(p_workspace uuid,p_invitation uuid) returns void
language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
  perform sp_private.lock_workspace(p_workspace,array['owner']);
  update sp_private.invitations set revoked_at=now()
    where id=p_invitation and workspace_id=p_workspace and accepted_at is null and revoked_at is null returning id into v_id;
  if v_id is null then raise exception 'Invitation introuvable ou déjà traitée.'; end if;
  perform sp_private.record_event(p_workspace,'invitation',v_id,'revoked',null,null);
end $$;

create function public.sp_list_members(p_workspace uuid)
returns table(user_id uuid,email text,role text,joined_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
  if sp_private.member_role(p_workspace) is null then raise exception 'Accès refusé.' using errcode='42501'; end if;
  return query select m.user_id,u.email::text,m.role,m.joined_at
    from public.sp_members m join auth.users u on u.id=m.user_id where m.workspace_id=p_workspace order by m.joined_at;
end $$;

create function public.sp_set_member_role(p_workspace uuid,p_user uuid,p_role text,p_expected_role text) returns void
language plpgsql security definer set search_path='' as $$
declare v_old text;
begin
  perform sp_private.lock_workspace(p_workspace,array['owner']);
  if p_role is null or p_role not in ('manager','viewer') then raise exception 'Rôle invalide.'; end if;
  select role into v_old from public.sp_members where workspace_id=p_workspace and user_id=p_user;
  if v_old is null then raise exception 'Membre introuvable.'; end if;
  if v_old='owner' then raise exception 'Le propriétaire ne peut pas être rétrogradé.'; end if;
  if v_old is distinct from p_expected_role then raise exception 'Le rôle a changé. Actualisez les données.' using errcode='40001'; end if;
  update public.sp_members set role=p_role where workspace_id=p_workspace and user_id=p_user;
  perform sp_private.record_event(p_workspace,'member',p_user,'role_changed',jsonb_build_object('role',v_old),jsonb_build_object('role',p_role));
end $$;

create function public.sp_remove_member(p_workspace uuid,p_user uuid,p_expected_role text) returns void
language plpgsql security definer set search_path='' as $$
declare v_old text;
begin
  perform sp_private.lock_workspace(p_workspace,array['owner']);
  select role into v_old from public.sp_members where workspace_id=p_workspace and user_id=p_user;
  if v_old is null then raise exception 'Membre introuvable.'; end if;
  if v_old='owner' then raise exception 'Le propriétaire ne peut pas être supprimé.'; end if;
  if v_old is distinct from p_expected_role then raise exception 'Le rôle a changé. Actualisez les données.' using errcode='40001'; end if;
  delete from public.sp_members where workspace_id=p_workspace and user_id=p_user;
  perform sp_private.record_event(p_workspace,'member',p_user,'removed',jsonb_build_object('role',v_old),null);
end $$;

revoke all on function public.sp_update_workspace(uuid,text,text,bigint),public.sp_create_invitation(uuid,text,text),public.sp_accept_invitation(text),
public.sp_list_invitations(uuid),public.sp_revoke_invitation(uuid,uuid),public.sp_list_members(uuid),public.sp_set_member_role(uuid,uuid,text,text),public.sp_remove_member(uuid,uuid,text) from public,anon,authenticated;
grant execute on function public.sp_update_workspace(uuid,text,text,bigint),public.sp_create_invitation(uuid,text,text),public.sp_accept_invitation(text),
public.sp_list_invitations(uuid),public.sp_revoke_invitation(uuid,uuid),public.sp_list_members(uuid),public.sp_set_member_role(uuid,uuid,text,text),public.sp_remove_member(uuid,uuid,text) to authenticated;
revoke all on function public.rls_auto_enable() from public,anon,authenticated;
comment on function public.sp_create_invitation(uuid,text,text) is 'Retourne un code à transmettre manuellement. Aucun email envoyé. Code stocké uniquement sous forme hachée, valable 7 jours et lié à une adresse vérifiée.';
