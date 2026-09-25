# Controle Queda de Energia

Sistema do escritório Rodrigues Litaiff Advogados para o produto Queda de Energia (Âmbar Energia, Alvarães/AM): cadastro de clientes, pauta de audiências, avisos, convites, pós-audiência e retorno.

- Tela: `index.html` (HTML e JavaScript, sem etapa de build)
- Banco e login: Supabase (`supabase/01_estrutura.sql`)
- Hospedagem: Vercel, publicando a partir deste repositório

## Configuração

1. No Supabase, rode `supabase/01_estrutura.sql` no SQL Editor.
2. Rode a importação de dados (arquivo guardado fora deste repositório).
3. Preencha `config.js` com a Project URL e a chave pública (anon/publishable).
4. Em Authentication > URL Configuration, coloque o endereço do site em **Site URL** e em **Redirect URLs**.

## Acesso

Só entra quem está cadastrado e ativo na aba **Equipe**. O funcionário usa **Primeiro acesso** com o e-mail cadastrado para criar a senha.

- **Administrador:** faz tudo, inclusive excluir registros e gerenciar a equipe.
- **Assistente:** cadastra e atualiza clientes, avisos e resultados, e gera convites. Não exclui registros.

Dados de clientes nunca devem ser enviados para este repositório.
