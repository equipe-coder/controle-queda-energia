-- Cadência: 3 dias antes e véspera, todos os dias da semana (8h às 18h de Manaus = 12h às 21h50 UTC).
alter table public.avisos_log drop constraint if exists avisos_log_etapa_check;
alter table public.avisos_log add constraint avisos_log_etapa_check check (etapa in ('h3', 'h1', 'designacao', 'd10', 'h10', 'h5', 'teste'));
select cron.unschedule(jobid) from cron.job where jobname = 'regua-avisos';
select cron.schedule('regua-avisos', '*/10 12-21 * * *', $job$
  select net.http_post(
    url := 'https://etmknidodbmtpvbzgvhp.supabase.co/functions/v1/lembrete-whatsapp',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-regua-token', (select valor from public.segredos where nome = 'regua_token')),
    body := '{"acao":"regua"}'::jsonb,
    timeout_milliseconds := 120000
  );
$job$);
select jobname, schedule, active from cron.job where jobname = 'regua-avisos';
