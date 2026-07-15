# Deploy Web Preview

O deploy usa GitHub Pages e é disparado por `main` ou manualmente. O workflow fixa Flutter 3.44.0 e somente publica após geração de código, análise, testes e build web aprovados.

## Pré-requisitos remotos

1. Criar repositório GitHub e habilitar Pages com source **GitHub Actions**.
2. Criar environment `production` e definir as variables `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY`.
3. Configurar a URL `https://<usuario>.github.io/<repositorio>/` em Site URL/Redirect URLs no Supabase Auth.
4. Executar migrations e deploy das Edge Functions no projeto Supabase de produção.

As variables no workflow são públicas por natureza (URL e publishable key). Nunca cadastre Service Role, OpenAI ou secrets como variables do build web.

## Rollback

Reverta o commit problemático ou reexecute um workflow de commit anterior. A versão publicada pelo GitHub Pages acompanha o último artefato aprovado.

## Limitações atuais

Não há Flutter SDK, repositório GitHub remoto, URL Supabase de produção ou funções de negócio completas no workspace. Portanto não existe URL pública nem validação web concluída ainda.
