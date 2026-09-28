-- Consulta diária ao tribunal (DataJud / CNJ) para os processos do TJAM.
alter table public.segredos drop constraint if exists segredos_nome_check;
alter table public.segredos add constraint segredos_nome_check check (nome in ('liderhub', 'regua_token', 'regua_anon', 'datajud'));

-- o resumo do tribunal é atualizado pela consulta; não precisa entrar no histórico de alterações
create or replace function public.registrar_historico()
returns trigger language plpgsql security definer set search_path = public as $$
declare quem text := coalesce(lower(auth.jwt() ->> 'email'), 'sistema'); dif jsonb := '{}'::jsonb; k text;
begin
  if tg_op = 'INSERT' then
    insert into public.clientes_historico (cliente_id, acao, por, mudancas) values (new.id, 'criado', quem, jsonb_build_object('nome', new.data -> 'nome'));
    return new;
  elsif tg_op = 'DELETE' then
    insert into public.clientes_historico (cliente_id, acao, por, mudancas) values (old.id, 'excluido', quem, jsonb_build_object('nome', old.data -> 'nome'));
    return old;
  end if;
  for k in select key from jsonb_each(coalesce(new.data, '{}'::jsonb)) union select key from jsonb_each(coalesce(old.data, '{}'::jsonb)) loop
    if k not in ('atualizadoEm', 'reguaUltimo', 'tribunal') and (old.data -> k) is distinct from (new.data -> k) then
      dif := dif || jsonb_build_object(k, jsonb_build_array(old.data -> k, new.data -> k));
    end if;
  end loop;
  if dif <> '{}'::jsonb then
    insert into public.clientes_historico (cliente_id, acao, por, mudancas) values (new.id, 'alterado', quem, dif);
  end if;
  return new;
end $$;

-- todo dia às 7h de Manaus (11h UTC), de segunda a sábado
select cron.unschedule(jobid) from cron.job where jobname = 'tribunal-datajud';
select cron.schedule('tribunal-datajud', '0 11 * * 1-6', $job$
  select net.http_post(
    url := 'https://etmknidodbmtpvbzgvhp.supabase.co/functions/v1/lembrete-whatsapp',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select valor from public.segredos where nome = 'regua_anon'),
      'x-regua-token', (select valor from public.segredos where nome = 'regua_token')
    ),
    body := '{"acao":"tribunal-cron"}'::jsonb,
    timeout_milliseconds := 120000
  );
$job$);

select 'ok' as tribunal, (select count(*) from cron.job where jobname = 'tribunal-datajud') as agendador;
