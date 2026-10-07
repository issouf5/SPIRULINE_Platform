
do $migration$
declare f record; args text; body text;
begin
  for f in
    select p.oid,p.proname,p.pronargs,p.provolatile,
      pg_get_function_identity_arguments(p.oid) as identity_args,
      pg_get_function_arguments(p.oid) as full_args,
      pg_get_function_result(p.oid) as result_type
    from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname like 'sp\_%' escape '\' and p.prosecdef
  loop
    select string_agg('$'||i::text,',' order by i) into args from generate_series(1,f.pronargs) i;
    execute format('alter function public.%I(%s) set schema sp_private',f.proname,f.identity_args);
    body:=format('select * from sp_private.%I(%s)',f.proname,coalesce(args,''));
    execute format('create function public.%I(%s) returns %s language sql %s security invoker set search_path = %L as %L',
      f.proname,f.full_args,f.result_type,case when f.provolatile='s' then 'stable' else 'volatile' end,'',body);
    execute format('revoke all on function public.%I(%s) from public,anon,authenticated',f.proname,f.identity_args);
    execute format('grant execute on function public.%I(%s) to authenticated',f.proname,f.identity_args);
    execute format('comment on function public.%I(%s) is %L',f.proname,f.identity_args,
      'Point d''entrée sans élévation de privilèges. Implémentation privée avec contrôle de l''identité, du rôle et de l''entreprise.');
  end loop;
end $migration$;
create policy sp_invitation_deny_direct_access on sp_private.invitations
  for all to authenticated using(false) with check(false);
comment on table sp_private.invitations is 'Accès direct interdit. Les fonctions privées contrôlent le propriétaire ou le code et l''adresse e-mail vérifiée du destinataire.';
