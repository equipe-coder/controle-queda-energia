-- Régua automática de avisos por WhatsApp (LiderHub).
-- Registro de cada aviso enviado (ou pulado/com erro) por número, etapa e data da audiência.
create table if not exists public.avisos_log (
  id          bigserial primary key,
  numero      text not null,
  clientes    text[] not null default '{}',
  etapa       text not null check (etapa in ('designacao', 'd10', 'h10', 'h5', 'h1', 'teste')),
  aud_data    date,
  status      text not null check (status in ('enviado', 'erro', 'sem_whatsapp')),
  erro        text,
  criado_em   timestamptz not null default now()
);
create unique index if not exists avisos_log_unico on public.avisos_log (numero, etapa, aud_data) where status in ('enviado', 'sem_whatsapp');
create index if not exists avisos_log_data on public.avisos_log (criado_em);
alter table public.avisos_log enable row level security;
drop policy if exists membro_le on public.avisos_log;
create policy membro_le on public.avisos_log for select to authenticated using (public.minha_funcao() is not null);
grant select on public.avisos_log to authenticated;
grant all on public.avisos_log to service_role;
grant usage, select on sequence public.avisos_log_id_seq to service_role;

-- Chave interna para o agendador chamar a função (gerada aqui, nunca exibida)
alter table public.segredos drop constraint if exists segredos_nome_check;
alter table public.segredos add constraint segredos_nome_check check (nome in ('liderhub', 'regua_token', 'regua_anon'));
insert into public.segredos (nome, valor, atualizado_por)
values ('regua_token', replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''), 'sistema')
on conflict (nome) do nothing;

-- Configuração padrão (desligada até o administrador ativar)
insert into public.config (id, data) values ('regua', jsonb_build_object('ativo', false, 'porDia', 70))
on conflict (id) do nothing;

-- Agendador: a cada 10 minutos, de segunda a sexta, 8h às 17h50 de Manaus (12h–21h50 UTC)
create extension if not exists pg_cron;
create extension if not exists pg_net;
select cron.unschedule(jobid) from cron.job where jobname = 'regua-avisos';
select cron.schedule('regua-avisos', '*/10 12-21 * * 1-5', $job$
  select net.http_post(
    url := 'https://etmknidodbmtpvbzgvhp.supabase.co/functions/v1/lembrete-whatsapp',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || (select valor from public.segredos where nome = 'regua_anon'),
      'x-regua-token', (select valor from public.segredos where nome = 'regua_token')
    ),
    body := '{"acao":"regua"}'::jsonb,
    timeout_milliseconds := 120000
  );
$job$);

-- Audiências online marcadas na planilha (nome em azul)
update public.clientes set data = data || '{"online": true}'::jsonb where id in ('c135','c172','c178','c180','c216','c217','c250','c286','c304','c367','c415');

select 'ok' as regua, (select count(*) from public.clientes where (data->>'online')::boolean) as online, (select count(*) from cron.job where jobname = 'regua-avisos') as agendador;
