// Envio de lembrete de audiência pelo LiderHub (workspace Pós-venda).
// A chave do LiderHub fica só aqui no servidor (segredo LIDERHUB_KEY); o site nunca a vê.
// Só administradores ativos do sistema (tabela equipe) conseguem chamar.
import { createClient } from 'npm:@supabase/supabase-js@2';

const LH = 'https://api.liderhub.com.br';
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { ...CORS, 'Content-Type': 'application/json' } });
const espera = (ms: number) => new Promise((r) => setTimeout(r, ms));

// LiderHub aceita 3 requisições por segundo por workspace
let ultima = 0;
async function lh(key: string, method: string, path: string, body?: unknown) {
  const falta = 380 - (Date.now() - ultima);
  if (falta > 0) await espera(falta);
  for (let tentativa = 0; tentativa < 4; tentativa++) {
    ultima = Date.now();
    const r = await fetch(LH + path, {
      method,
      headers: { 'x-company-key': key, 'Content-Type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (r.status === 429) { await espera(1000 * (tentativa + 1)); continue; }
    const txt = await r.text();
    let dados: any = null; try { dados = JSON.parse(txt); } catch { dados = { message: txt }; }
    return { ok: r.ok, status: r.status, dados };
  }
  return { ok: false, status: 429, dados: { message: 'Limite de requisições do LiderHub' } };
}

// Números do cadastro vêm como "(97) 8105-3097"; o WhatsApp pode ter a conta com ou sem o 9
function variantes(numero: string): string[] {
  let d = String(numero || '').replace(/\D/g, '');
  if (d.startsWith('55') && d.length >= 12) d = d.slice(2);
  if (d.startsWith('0')) d = d.slice(1);
  if (d.length === 10) return ['55' + d, '55' + d.slice(0, 2) + '9' + d.slice(2)];
  if (d.length === 11 && d[2] === '9') return ['55' + d, '55' + d.slice(0, 2) + d.slice(3)];
  return [];
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  try {

    // chave pública do projeto (a mesma do config.js do site)
    const publica = Deno.env.get('SUPABASE_ANON_KEY') || 'sb_publishable_0tH0slL5lOQ06uZadSb28A__DYpJs0r';
    const sb = createClient(Deno.env.get('SUPABASE_URL')!, publica, {
      global: { headers: { Authorization: req.headers.get('Authorization') || '' } },
    });
    const { data: funcao } = await sb.rpc('minha_funcao');
    if (funcao !== 'admin') return json({ erro: 'Só administradores podem enviar lembretes.' }, 403);

    // chave salva pela aba Equipe (tabela segredos, lida só aqui com a chave de serviço); o segredo LIDERHUB_KEY continua valendo se existir
    let key = Deno.env.get('LIDERHUB_KEY') || '';
    if (!key) {
      const servico = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
      if (servico) {
        const adm = createClient(Deno.env.get('SUPABASE_URL')!, servico, { auth: { persistSession: false } });
        const { data } = await adm.from('segredos').select('valor').eq('nome', 'liderhub').maybeSingle();
        key = data?.valor || '';
      }
    }
    if (!key) return json({ erro: 'A chave do LiderHub ainda não foi cadastrada. Cadastre na aba Equipe, em Integrações.' }, 400);

    const body = await req.json().catch(() => ({}));

    if (body.acao === 'conexoes') {
      const r = await lh(key, 'GET', '/v1/connections');
      if (!r.ok) return json({ erro: 'LiderHub recusou (' + r.status + '): ' + (r.dados?.message || '') }, 502);
      const conexoes = (r.dados?.connections || []).map((c: any) => ({
        id: c.id, numero: c.number, status: c.connectionStatus, tipo: c.integration,
      }));
      return json({ conexoes });
    }

    if (body.acao === 'enviar') {
      const conexao = String(body.conexao || '');
      const itens = Array.isArray(body.itens) ? body.itens.slice(0, 10) : [];
      if (!conexao || !itens.length) return json({ erro: 'Faltou a conexão ou a lista de envio.' }, 400);
      const resultados = [];
      for (const it of itens) {
        const opcoes = variantes(it.numero);
        if (!opcoes.length) { resultados.push({ chave: it.chave, ok: false, erro: 'Número inválido' }); continue; }
        let contato = '', usado = '', erro = 'Número não tem WhatsApp';
        for (const n of opcoes) {
          const c = await lh(key, 'POST', '/v1/contacts', { connection: conexao, number: n, name: String(it.nome || '').slice(0, 80) });
          if (!c.ok) { erro = 'Cadastro no LiderHub falhou (' + c.status + '): ' + (c.dados?.message || ''); continue; }
          if (c.dados?.exist && c.dados?.id) { contato = c.dados.id; usado = n; break; }
        }
        if (!contato) { resultados.push({ chave: it.chave, ok: false, erro }); continue; }
        const m = await lh(key, 'POST', '/v1/send/message', {
          contact: contato, content: String(it.texto || ''), messageType: 'conversation',
          ...(it.agendarEm ? { scheduledAt: it.agendarEm } : {}),
        });
        resultados.push(m.ok
          ? { chave: it.chave, ok: true, numero: usado, contato }
          : { chave: it.chave, ok: false, numero: usado, erro: 'Envio recusado (' + m.status + '): ' + (m.dados?.message || '') });
      }
      return json({ resultados });
    }

    return json({ erro: 'Ação desconhecida.' }, 400);
  } catch (e) {
    return json({ erro: 'Erro no servidor: ' + ((e as Error)?.message || e) }, 500);
  }
});
