-- Agendadores chamam a função só com a chave interna (x-regua-token); a própria função confere.
-- Requer "Verify JWT with legacy secret" DESLIGADO na função lembrete-whatsapp (Edge Functions > Settings).
select cron.unschedule(jobid) from cron.job where jobname in ('regua-avisos', 'tribunal-datajud');
select cron.schedule('regua-avisos', '*/10 12-21 * * 1-5', $job$
  select net.http_post(
    url := 'https://etmknidodbmtpvbzgvhp.supabase.co/functions/v1/lembrete-whatsapp',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-regua-token', (select valor from public.segredos where nome = 'regua_token')),
    body := '{"acao":"regua"}'::jsonb,
    timeout_milliseconds := 120000
  );
$job$);
select cron.schedule('tribunal-datajud', '0 11 * * 1-6', $job$
  select net.http_post(
    url := 'https://etmknidodbmtpvbzgvhp.supabase.co/functions/v1/lembrete-whatsapp',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-regua-token', (select valor from public.segredos where nome = 'regua_token')),
    body := '{"acao":"tribunal-cron"}'::jsonb,
    timeout_milliseconds := 120000
  );
$job$);
select jobname, schedule from cron.job where jobname in ('regua-avisos', 'tribunal-datajud') order by 1;
