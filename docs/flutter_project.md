# Estrutura inicial Flutter

## Organização

`app` reúne composição da aplicação: bootstrap, router, tema, configuração, inicialização e localização. `core` contém infraestrutura transversal; `shared`, componentes visuais e tipos reutilizáveis. Regras de domínio sempre ficam em `features`, organizadas verticalmente em presentation, application, domain e data.

O núcleo financeiro continua em `features/finance`, com subdomínios para dashboard, transações, investimentos, cripto, cartões, metas e relatórios. Não criamos módulos separados de receita e despesa porque são tipos da mesma transação. `core/ai` é reservado a contratos, parsers, intents, memória e prompts reutilizáveis; `features/chat_ai` continuará sendo a interface do assistente. Essa separação evita que a futura IA se torne uma dependência circular das features financeiras.

## Dependências

- **Fundação**: `flutter_riverpod`, `riverpod_annotation`, `go_router`, `dio`, `intl`, `uuid`, `logger` e `connectivity_plus` suportam estado, navegação, HTTP, formatação, identidade técnica, logs e conectividade.
- **Modelagem e persistência**: `freezed`, `json_annotation`, `json_serializable`, `shared_preferences`, `flutter_secure_storage` e `flutter_dotenv` mantêm contratos imutáveis e configuração local segura.
- **Supabase**: `supabase_flutter` conecta Auth, Database, Storage e Functions por serviços, nunca diretamente pela UI.
- **Experiência**: `google_fonts`, `flutter_svg`, `cached_network_image`, `fl_chart`, `animations`, `qr_flutter` e `mobile_scanner` são preparados para interface, relatórios e QR code.
- **Plataforma**: `file_picker`, `image_picker`, `permission_handler`, `url_launcher`, `local_auth`, `package_info_plus` e `device_info_plus` encapsulam capacidades específicas por trás de serviços.
- **Qualidade**: `build_runner`, `freezed`, `json_serializable`, `mocktail`, `flutter_lints`, `flutter_test` e `integration_test` suportam geração e testes.

As versões foram consultadas no pub.dev em 15/07/2026. Antes do primeiro build, `flutter pub get` deve gerar o lockfile com o SDK Flutter estável compatível com Dart 3.9 ou superior.

## Plataforma

Android, iOS, Web, Windows, macOS e Linux serão materializados pelo comando `flutter create . --platforms=android,ios,web,windows,macos,linux`. Não foi possível executar esse comando porque o SDK Flutter não existe no ambiente atual. Não criei manualmente arquivos nativos: templates manuais são frágeis e diferem do gerador oficial.

## Inclusão de uma feature

1. Crie a feature com as quatro camadas.
2. Defina entidades e repositórios em `domain`.
3. Implemente casos de uso em `application`.
4. Implemente data source e repositório em `data` usando serviços injetados.
5. Registre providers e rotas na camada de apresentação.
6. Inclua testes unitários, widget e, quando houver jornada crítica, integração.
