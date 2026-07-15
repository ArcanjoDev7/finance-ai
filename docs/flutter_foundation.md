# Base Flutter

## Bootstrap

`main.dart` delega para `runFinanceAiApp()`. O bootstrap inicializa bindings, lê configurações por `--dart-define`, inicializa Supabase somente quando URL e publishable key existem e instala handlers globais de erro. Nenhuma chave de serviço ou OpenAI é aceita pelo app.

## Ambientes

Use `ENVIRONMENT=development|homolog|production`, `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY` como build defines. Cada ambiente deve apontar para um projeto Supabase próprio. A publishable key pode estar no cliente; o controle de acesso efetivo permanece em RLS.

## Injeção e estado

Riverpod é o ponto de composição. `appEnvironmentProvider`, Dio e Secure Storage são providers de infraestrutura. Contratos de serviço foram declarados, mas suas implementações só serão registradas no momento em que as respectivas features existirem. Isso impede dependências fictícias ou singletons globais antes da necessidade.

## UI base

`MaterialApp.router` usa Material Design 3, tema claro/escuro baseado em seed, tokens de espaçamento/raio e GoRouter. A rota vazia é apenas um placeholder técnico, não uma tela de produto. Rotas autenticadas serão introduzidas junto da feature Auth.

## Erros e observabilidade

O `Result<T>` evita exceptions atravessando a camada de apresentação. O logger central substitui `print` e só produz logs de depuração em builds debug. Integração com observabilidade externa será adicionada com secrets por ambiente.

## Validação pendente

O ambiente atual não possui `flutter` nem `dart` no PATH. Portanto `flutter pub get`, `flutter analyze` e testes não puderam ser executados. Instale um Flutter SDK compatível e execute esses comandos na pasta `flutter` antes de iniciar a etapa de Login.
