# WisFlutter

Port em **Flutter nativo** da app **WIS — Worship In Sync** (gestão de ministérios e
escalas para igrejas), atualmente uma PWA em Next.js/Supabase no repositório
[ServiceFlow](https://github.com/lucassalino/ServiceFlow). Objetivo: publicar na
**Apple App Store** e na **Google Play Store**, reutilizando o mesmo backend
Supabase (base de dados, auth e storage) — sem recriar o backend.

## Estratégia de branches

| Branch | Propósito |
|--------|-----------|
| `main` | Base estável, histórico linear |
| `dev`  | Desenvolvimento ativo — todo o trabalho novo entra aqui primeiro |
| `prd`  | Releases prontas para as lojas (App Store / Play Store) |

## Referência

A pasta [`docs/reference`](docs/reference) contém a documentação copiada do
ServiceFlow que descreve a app original em detalhe (telas, modelo de dados,
regras de negócio) e serve de base funcional para este port:

- `wis-app-overview-and-rn-prompt.md` — descrição técnica completa da app e do
  modelo de dados Supabase (escrita originalmente como prompt para React
  Native — a base funcional é igual para o port em Flutter).
- `prd-funcionalidades-2026-07.md` — funcionalidades adicionadas no último ciclo.
- `roadmap-planos-assinatura.md` — roadmap de planos de assinatura (ainda não implementado).

## Stack

- **Flutter** (Dart) + **Riverpod** (estado) + **go_router** (navegação/deep links)
- **Supabase** (`supabase_flutter`) — mesmo backend do ServiceFlow (Postgres + Auth + Storage), sem servidor próprio
- Bundle id / package: `com.wisservices.wis`

## Como correr

```bash
flutter pub get
flutter run
```

As credenciais Supabase têm defaults embutidos em `lib/core/config/env.dart`
(URL + publishable/anon key — seguros para expor no cliente, protegidos por
RLS). Para apontar a outro projeto:

```bash
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```

## Estado

Fundação implementada: scaffold do projeto (iOS + Android), tema (dark navy,
marca WIS), autenticação (login, registo, recuperar/definir password),
onboarding de organização (selecionar, criar, entrar por código) e Dashboard
(próximos eventos, confirmações pendentes, aniversariantes do mês).

### Nota de arquitetura — RLS em vez de servidor privilegiado

A app web (Next.js) usa Server Actions com a **service role key** para
contornar RLS em várias escritas. Como a app Flutter não tem servidor
próprio, isso nunca pode ser replicado no cliente (a service role key não
pode ser embutida numa app nativa). Foi confirmado que o RLS já existente no
schema (`is_org_member`/`is_org_admin`/`is_org_admin_or_leader`, ver
`supabase/migrations` do ServiceFlow) cobre diretamente quase tudo o que a
fundação precisa — a única exceção encontrada até agora é resolver um
código de convite antes de o utilizador ser membro (RLS bloqueia a leitura
de `organizations` a não-membros). A função adicional necessária para isso
está em [`supabase/migrations/20260724_resolve_invite_code.sql`](supabase/migrations/20260724_resolve_invite_code.sql)
— puramente aditiva, ainda **por aplicar** ao projeto Supabase partilhado
(pendente de confirmação, por ser uma alteração a uma base de dados de
produção partilhada com a app web).

Próximos ecrãs a construir (ver `docs/reference/` para a especificação
completa): Eventos, Escala, Repertório, Ministérios, Pessoas, Definições,
Notificações, push nativo e deep links.
