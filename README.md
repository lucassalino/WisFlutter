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

Todos os ecrãs da especificação (`docs/reference/`) estão implementados:
Auth, onboarding de organização, Dashboard, Eventos, Escala, Repertório,
Ministérios, Pessoas, Definições e Notificações — incluindo upload de
imagens (avatar, logótipo da organização, capa de evento) e deep links
para os fluxos de confirmação de email / recuperação de password.

### Nota de arquitetura — RLS em vez de servidor privilegiado

A app web (Next.js) usa Server Actions com a **service role key** para
contornar RLS em várias escritas. Como a app Flutter não tem servidor
próprio, isso nunca pode ser replicado no cliente (a service role key não
pode ser embutida numa app nativa). Confirmámos que o RLS já existente no
schema (`is_org_member`/`is_org_admin`/`is_org_admin_or_leader`) cobre
diretamente quase tudo — incluindo operações que pareciam precisar de
admin (remover membro, eliminar organização, etc.), graças a `on delete
cascade` nas tabelas dependentes de `organizations` e a policies de DELETE
já aplicadas em produção (para além do que os ficheiros de migração do
ServiceFlow mostram — a base de dados live já tinha sido preparada numa
tentativa anterior de app móvel, incluindo a Edge Function `manage-invite`
e funções como `delete_own_account`/`transfer_org_admin`, que esta app
reaproveita tal como estão).

Duas exceções exigiram uma função SQL nova (aditiva, sem tocar em nada
existente):
- `resolve_invite_code` — resolve um código de convite para o id da
  organização antes de o utilizador ser membro (RLS bloqueia a leitura
  direta de `organizations` a não-membros). **Aplicada.**
- `fetch_org_members` (masking de email por cargo) — **não aplicada**,
  pendente de decisão; por agora o email de todos os membros é visível a
  qualquer membro da organização na resposta da API (só escondido — não
  bloqueado — na UI para não-admins).

### Push notifications e Universal Links — bloqueado, não por escolha

Falta:
- **Firebase Cloud Messaging** (Android + iOS): precisa de um projeto
  Firebase (criar em firebase.google.com, fora do alcance de ferramentas
  automatizadas) com `google-services.json`/`GoogleService-Info.plist`.
- **APNs** (push no iOS) e **Universal Links no iOS** (`apple-app-site-
  association` em wis-services.com): exigem conta Apple Developer (99
  USD/ano) — pré-requisito para o iOS de qualquer forma, incluindo para
  publicar na App Store.
- **App Links no Android** (`assetlinks.json`): não depende de conta paga,
  pode avançar-se assim que houver um keystore de assinatura definido.

O que já está pronto e não depende de nada disto: o esquema de deep link
`wis://auth-callback` está registado em ambas as plataformas e ligado ao
`emailRedirectTo`/`redirectTo` das chamadas de signup e recuperação de
password — o `supabase_flutter` já trata destes links automaticamente
(estabelece a sessão sozinho a partir do token na URL). **Falta um passo
manual no Supabase Dashboard:** adicionar `wis://auth-callback` a
Authentication → URL Configuration → Additional Redirect URLs, senão o
Supabase ignora o redirect e usa o Site URL (o da app web) em vez deste.

O convite por email (`manage-invite`) continua a apontar para
`wis-services.com` — não foi alterado, por ser uma Edge Function partilhada
com a app web; passar isso a abrir a app nativa exige Universal Links, logo
espera pela conta Apple Developer.
