# Configuração Supabase

## Estrutura versionada

- `supabase/config.toml`: configuração local e declaração de função pública mínima.
- `supabase/migrations`: schema, RLS, funções SQL e Storage em ordem determinística.
- `supabase/seed`: referências de desenvolvimento.
- `supabase/functions/_shared`: CORS e respostas HTTP reutilizáveis.
- `supabase/functions/health`: endpoint público sem dados sensíveis para monitoramento.

## Auth

Email/senha e confirmação de email estão habilitados na configuração local. Google e Apple estão deliberadamente desabilitados até que existam credenciais OAuth por ambiente. Para homologação e produção, configure no dashboard do Supabase os Client IDs/Secrets, URLs de callback exatas e domínios permitidos; esses segredos nunca entram em Git ou no Flutter.

Cada ambiente deve usar um projeto Supabase independente, URL de site própria e URLs de redirecionamento explícitas. O prazo do JWT é de uma hora com rotação de refresh token habilitada. Essa combinação limita exposição de sessão sem degradar a persistência de login.

## Storage

Os buckets `transaction-attachments`, `avatars`, `receipts`, `attachments`, `documents` e `exports` são privados. Todo objeto deve seguir o prefixo `<user_id>/...`; as políticas verificam esse primeiro segmento antes de permitir leitura ou escrita. O uso de URLs assinadas será centralizado no futuro `StorageService`.

Manter avatares privados oferece mais privacidade, mas exige URL assinada até mesmo para exibir uma foto. A alternativa de bucket público reduz latência, porém expõe identificadores e imagens a qualquer pessoa que tenha a URL.

## Edge Functions

`health` e `download` existem nesta fase e não leem nem gravam dados financeiros. As pastas de funções futuras estão separadas por domínio. Funções financeiras terão JWT obrigatório e usarão um cliente escopado por RLS. Funções públicas só serão permitidas quando não processarem dados confidenciais e tiverem verificação alternativa adequada.

## Deploy posterior

1. Instalar Supabase CLI e Docker.
2. Criar um projeto por ambiente e vinculá-lo com `supabase link`.
3. Definir secrets no projeto (`OPENAI_API_KEY` somente quando a etapa de IA iniciar).
4. Aplicar migrations e seed no ambiente de desenvolvimento.
5. Configurar SMTP, OAuth Google/Apple e URLs finais antes de produção.
