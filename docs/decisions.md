# Registro de Decisões de Arquitetura

## ADR-001 — Clean Architecture feature-first

Aceita. Cada feature possui suas próprias camadas e depende do domínio, não de detalhes de infraestrutura.

## ADR-002 — Domínio financeiro unificado

Aceita. Receitas e despesas serão tipos de transação na feature `finance`.

## ADR-003 — IA somente por Edge Functions

Aceita. O cliente Flutter não recebe nem chama a chave OpenAI.
