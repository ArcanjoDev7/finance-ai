# Arquitetura — Finance AI

## Objetivo e princípios

O projeto usa Clean Architecture organizada por feature. Cada feature é uma unidade vertical independente, com dependências direcionadas ao domínio. Isso maximiza coesão, permite testes sem Flutter ou Supabase e impede que detalhes de infraestrutura contaminem regras de negócio.

Aplicamos SOLID, DRY, KISS, composição sobre herança, Repository Pattern e Dependency Injection via Riverpod. Abstrações existem apenas em fronteiras reais, evitando camadas sem responsabilidade clara.

## Árvore de diretórios

```text
finance_ai/
├── .github/workflows/                 # pipelines CI/CD futuros
├── assets/{fonts,icons,images,animations}/
├── docs/{architecture,database,api,ui,roadmap,decisions}/
├── supabase/{migrations,seed,functions,storage}/
├── flutter/
│   ├── lib/
│   │   ├── main.dart                  # ponto de entrada (fase Flutter)
│   │   ├── app/{router,theme,localization,constants,environment,startup}/
│   │   ├── core/{exceptions,errors,failure,network,storage,services,extensions,utils,logger,validators,widgets}/
│   │   ├── shared/{components,models,entities,enums,helpers,mixins}/
│   │   └── features/
│   │       ├── auth/ dashboard/ investments/ crypto/ cards/ goals/
│   │       ├── chat_ai/ notifications/ profile/ settings/
│   │       └── finance/{transactions,categories,budgets,reports}/
│   ├── test/{unit,widget}/
│   └── integration_test/
├── README.md  CHANGELOG.md  LICENSE  .gitignore  analysis_options.yaml
└── flutter/pubspec.yaml
```

Cada feature tem esta forma:

```text
feature/
├── presentation/{pages,widgets,controllers,providers}/
├── application/usecases/
├── domain/{entities,repositories}/
└── data/{datasources,models,repositories}/
```

## Camadas e fluxo

```text
UI → Controller → Use case → Repository (contrato) →
Repository (implementação) → Data source → Service → Supabase/API
```

- **Presentation** contém composição visual, interação e estado de tela. Não acessa Supabase nem instancia dependências.
- **Application** orquestra um caso de uso por intenção do usuário.
- **Domain** define entidades puras e contratos de repositório, sem Flutter, Dio ou Supabase.
- **Data** traduz modelos, fontes de dados e implementa contratos do domínio.
- **Core** contém infraestrutura transversal e não conhece detalhes de feature.
- **Shared** recebe apenas código comprovadamente reutilizável; código de uma única feature permanece nela.

Dependências são registradas como providers Riverpod no ponto de composição da aplicação e injetadas por construtor. A UI consome somente controllers/providers da própria feature, evitando service locators e estado global oculto.

## Decisões

### Finance unificado

Receitas e despesas são tipos de transação, logo ficam em `features/finance/transactions`, em vez de módulos duplicados. Relatórios, filtros e importações usam uma linguagem única. Investimentos e cartões permanecem isolados porque têm ciclos próprios. O custo é uma feature financeira mais ampla; subfeatures preservam limites claros.

### Serviços como fronteira de rede

`AuthService`, `DatabaseService`, `StorageService`, `ChatAIService`, `QRCodeService`, `NotificationService` e `AnalyticsService` serão contratos de infraestrutura. Data sources dependem deles; widgets nunca. Isso facilita mocks, troca gradual de fornecedor e tratamento centralizado de erros.

### Result Pattern

Use cases retornam um tipo selado `Result`, com sucesso ou `Failure`. Exceptions são convertidas na fronteira de dados e nunca chegam à UI. A vantagem é fluxo explícito e previsível; o custo é tratamento formal que será reduzido por helpers pequenos e consistentes.

### Navegação e responsividade

GoRouter centralizará rotas públicas, autenticadas, redirecionamento por sessão e deep links. Layouts usarão `LayoutBuilder` e breakpoints sem duplicar regras: navegação lateral em telas largas e navegação compacta em celular. Rotas serão declaradas por feature e compostas pelo router principal.

### Segurança e ambientes

Development, homolog e production terão configuração independente por build. A chave anônima do Supabase pode estar no cliente porque RLS protege os dados; chaves de serviço e OpenAI ficam exclusivamente em Supabase/GitHub Secrets. `flutter_secure_storage` guarda apenas dados locais sensíveis, nunca segredos de servidor.

### Escalabilidade e testes

Uma feature nova é adicionada criando seu módulo vertical, contratos de domínio e registros de dependência. Features não acessam os detalhes internos umas das outras. Use cases recebem testes unitários, widgets recebem testes de interface e jornadas críticas recebem testes de integração.

## Estado desta etapa

Somente a arquitetura e seus placeholders foram criados. Não existem telas, regras de negócio, banco, migrations, chamadas de rede ou configuração de serviços.
