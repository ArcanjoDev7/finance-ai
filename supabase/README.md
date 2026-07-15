# Supabase — Finance AI

## Operação local

Execute estes comandos a partir desta pasta após instalar Supabase CLI e Docker:

```powershell
supabase start
supabase db reset
supabase migration up
supabase functions serve health
supabase functions deploy health
```

Nunca altere tabelas pelo editor visual. Crie migrations com `supabase migration new <nome>` e aplique-as localmente antes de publicar.

## Ambientes

Development, homolog e production devem usar projetos Supabase separados. Em cada projeto, configure URL pública, SMTP, OAuth, secrets e `DOWNLOAD_PUBLIC_URL` no painel/CLI do ambiente. `OPENAI_API_KEY` só será adicionado quando a entrega de IA iniciar.

## Funções

- `health`: público; não manipula dados e expõe estado operacional.
- `download`: público; redireciona para `DOWNLOAD_PUBLIC_URL` HTTPS, permitindo trocar a página de download sem atualizar o app.
- `auth`, `chat`, `finance`, `reports`, `notifications`, `qr`: diretórios de contratos reservados às suas respectivas fases. Eles não possuem handlers ativos nesta etapa para não publicar APIs parcialmente implementadas.

## Storage

`avatars`, `transaction-attachments`, `receipts`, `attachments`, `documents` e `exports` são buckets privados. O caminho obrigatório é `<auth.uid()>/...`; RLS confere o primeiro segmento do caminho em todas as operações.

## Tipos TypeScript

Não edite tipos de banco manualmente. Use `types/generate_types.ps1` após subir ou vincular um projeto para gerar `types/database.types.ts` diretamente do schema.
