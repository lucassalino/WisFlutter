# WIS — Worship In Sync
## Descrição Técnica Completa + Prompt de Recriação para App Mobile (React Native)

---

# PARTE 1 — DESCRIÇÃO DETALHADA DA APLICAÇÃO

## 1. Visão geral

O **WIS — Worship In Sync** é uma aplicação de **gestão de ministérios e escalas para igrejas**. Permite a uma igreja (organização) gerir os seus membros, ministérios (ex.: Louvor, Sonoplastia, Multimédia), criar eventos/cultos, escalar pessoas para funções nesses eventos, montar o repertório de músicas (setlist) e notificar os escalados — com confirmação de presença.

- **Multi-organização:** um utilizador pode pertencer a várias igrejas e alternar entre elas.
- **Papéis (roles):** `admin` (administrador), `leader` (líder), `member` (membro).
- **Estratégia atual:** PWA (web instalável). Este documento serve de base para recriar a app em **mobile nativo (React Native/Expo)**.
- **Domínio de produção:** `https://wis-services.com` (alojado em Cloudflare Workers).

## 2. Stack tecnológica (versão web atual)

| Camada | Tecnologia |
|---|---|
| Framework | **Next.js 15** (App Router, React 19, Server Components + Server Actions) |
| Linguagem | **TypeScript** (strict, `noUnusedLocals`/`noUnusedParameters`) |
| Estilos | **Tailwind CSS v4** (`@import "tailwindcss"` + `@theme inline`) + CSS-in-JS inline |
| UI primitives | **Radix UI** (dialog, alert-dialog, select, popover, checkbox, switch, tabs, avatar, dropdown, scroll-area, label, separator, tooltip, toast) |
| Ícones | **lucide-react** |
| Estado servidor | **TanStack Query v5** (queries + mutations + cache) |
| Estado cliente | **Zustand v5** (`authStore`, `orgStore`) |
| Formulários | **react-hook-form** + **zod** (validação) |
| Backend / BD / Auth | **Supabase** (Postgres + Auth + Storage) — `@supabase/supabase-js` (browser) e `@supabase/ssr` (server/middleware) |
| Notificações UI | **sonner** (toasts) |
| Datas | **date-fns** |
| Gráficos | **recharts** |
| Recorte de imagem | **react-easy-crop** |
| PWA / Service Worker | **Serwist** (`@serwist/next`) — precache, offline, runtime caching |
| Tema | **next-themes** (tema escuro forçado) |
| Deploy | **Cloudflare Workers** via **@opennextjs/cloudflare** + **wrangler** (integração nativa Git / Workers Builds) |

### Backend (Supabase)
- **Auth:** email/password, confirmação de email, recuperação de password, convites (`inviteUserByEmail`), magic link (`signInWithOtp`).
- **Storage:** buckets `avatars` (fotos de perfil e logos de org) e `events` (imagens de capa).
- **Envio de email:** SMTP próprio (Gmail App Password) configurado no Supabase.
- **Escritas privilegiadas:** Server Actions usam a **service role key** (`getAdmin()`) para operações que precisam de contornar RLS.

## 3. Arquitetura

- **Server Actions** (`src/actions/*`) para toda a lógica de escrita/leitura sensível: `events`, `invites`, `members`, `ministries`, `notifications`, `organizations`, `profile`, `schedule`, `songs`.
- **Hooks** (`src/hooks/*`) que envolvem as actions em TanStack Query: `useEvents`, `useInvites`, `useMembers`, `useMinistries`, `useNotifications`, `useOrganizations`, `useProfile`, `useSchedule`, `useSongs`.
- **Stores Zustand:** `authStore` (utilizador autenticado), `orgStore` (`activeOrg`, `activeMembership`, `setActiveOrg`).
- **Invalidação global:** após **qualquer** mutação bem-sucedida, um `MutationCache` global invalida todas as queries → todas as telas recarregam automaticamente.
- **Middleware** de auth (Supabase SSR) protege as rotas privadas; rotas públicas: `/login`, `/register`, `/forgot-password`, `/auth/*`, ficheiros estáticos.

## 4. Modelo de dados (tabelas Postgres / Supabase)

- **profiles** — `id` (=auth.users.id), `email`, `full_name`, `avatar_url`, `phone`, `birthday`, timestamps.
- **organizations** — `id`, `name`, `logo_url`, `invite_code` (único), timestamps.
- **organization_members** — `id`, `org_id`, `user_id`, `role` (enum: admin/leader/member), `is_active`, `joined_at`.
- **organization_invites** — `id`, `org_id`, `email`, `name`, `role`, `created_by`, `created_at`, `accepted_at`. Chave única (org_id, email).
- **subscriptions** — `id`, `org_id`, `plan` (free/starter/growth/pro/enterprise), `member_limit`, `is_active`, `revenuecat_id`, `expires_at`.
- **ministries** — `id`, `org_id`, `name`, `icon`, `color`, `functions` (text[]), `is_active`, timestamps.
- **ministry_members** — `id`, `ministry_id`, `user_id`, `functions` (text[]), `is_active`.
- **events** — `id`, `org_id`, `name`, `date`, `time`, `arrival_time` (hora de chegada da equipa), `location`, `color`, `description`, `observations`, `cover_image_url`, `is_published`, `created_by`, timestamps.
- **event_ministries** — `id`, `event_id`, `ministry_id` (que ministérios participam no evento).
- **event_schedules** — `id`, `event_ministry_id`, `user_id`, `functions` (text[]), `confirmed` (bool nullable: null=pendente, true=confirmou, false=recusou).
- **event_setlists** — `id`, `event_id`, `song_id`, `order_index`, `musical_key` (Tom **por evento**).
- **songs** — biblioteca de músicas **por organização**: `id`, `org_id`, `ministry_id`, `name`, `artist`, `musical_key`, `bpm`, `lyrics`, `chords`, `youtube_url`, `spotify_url`, `catalog_song_id`, timestamps.
- **catalog_songs** — **catálogo GLOBAL partilhado** entre todas as igrejas: `id`, `name`, `artist`, `lyrics`, `chords`, `youtube_url`, `spotify_url`, `bpm`, `source_org_id`, `created_by`. Chave única `(lower(name), lower(artist))`.
- **notifications** — `id`, `user_id`, `event_id`, `message`, `is_read`, `sent_at`.

### Regras de dados importantes
- **Catálogo de músicas:** ao criar uma música, pesquisa-se o catálogo global por (nome+artista); se existir, reutiliza-se e preenchem-se os campos; senão cria-se nova entrada. Cada igreja tem a **sua cópia** editável (`songs`), mas contribui de volta ao catálogo **apenas os campos que estão vazios** (nunca sobrescreve nem duplica).
- **Tom por evento:** o Tom (`musical_key`) usado numa música é guardado na `event_setlists` (por evento), pois cada igreja/evento pode usar um tom diferente.
- **Período do dia:** derivado automaticamente da hora do evento — Manhã (05:00–11:59), Tarde (12:00–17:59), Noite (18:00–04:59).

## 5. Autenticação e fluxos de entrada

- **Registo:** nome, email, password + confirmar password (validação de igualdade e força mínima 6), botão "ver password". Envia email de confirmação → o utilizador confirma → entra.
- **Login:** email + password, "ver password", link "Esqueci a password".
- **Recuperar password:** introduz email → recebe email → link abre `/definir-password` onde define nova password.
- **Convites:** o admin convida por **nome + email**. Se a pessoa **não tem conta**, recebe email de convite (define password). Se **já tem conta**, recebe um **magic link** para entrar direto. Ao entrar, é adicionada automaticamente à organização (via `acceptPendingInvitesAction`) e o nome do convite é aplicado ao perfil se estiver vazio.
- **Código de convite:** cada organização tem um `invite_code`; qualquer pessoa com o código pode entrar via ecrã "Entrar numa organização".
- **Última organização:** após login, entra direto na última organização visitada (guardada em cookie `sf_last_org`); se não for membro dela, mostra a seleção.

## 6. Telas e funcionalidades (detalhado)

### Ecrãs de autenticação (fundo escuro navy, logótipo WIS)
1. **Login** — formulário email/password, ver password, "Esqueci a password", link para registar.
2. **Registar** — nome, email, password, confirmar password (validação), ver password. Estado "Confirma o teu email" após submeter.
3. **Recuperar password** — email → envia link.
4. **Definir password** — usado após convite/recuperação; define nova password e entra.

### Onboarding / Organização
5. **Seleção de organização** — lista das organizações do utilizador (logo, nome, cargo), botões "Criar organização" e "Entrar numa organização", seta de voltar ao login (logout).
6. **Criar organização** (`/new-org`) — nome da organização; cria e entra.
7. **Entrar numa organização** (`/join-org`) — introduz o código de convite.

### App (dentro de uma organização) — layout com sidebar (desktop) / bottom nav + header (mobile)
8. **Dashboard** — saudação "Olá, {nome}!", data atual, nº de eventos próximos; lista de **Próximos eventos** (com badges Publicado/Rascunho e período 🌅/☀️/🌙); secção de **aniversários**; botão "Criar evento" **só para admin**.

9. **Eventos** — lista com filtros (Todos / Publicados / Rascunhos), cada cartão mostra nome, badges (estado + período), data, hora, local. Ações:
   - **Criar/Editar evento**: painel com **abas** (Informação, Ministérios, Integrantes, Setlist) e um único botão **Gravar/Criar** que grava tudo:
     - *Informação:* nome, data, hora, **hora de chegada da equipa** (opcional), local, descrição, observações, imagem de capa (upload + recorte), toggle Publicado.
     - *Ministérios:* seleciona que ministérios participam.
     - *Integrantes:* por ministério, adiciona pessoas (só membros desse ministério) e escolhe as funções (só as funções que essa pessoa tem).
     - *Setlist:* pesquisa e adiciona músicas; para cada música escolhe o **Tom desse evento**.
   - **Detalhe do evento**: hero com badges e meta (data, hora, chegada, local); abas **Equipa** (ministérios + escalados com estado de confirmação) e **Setlist** (músicas com Tom/BPM, botão "Abrir playlist no YouTube"). Botão de **confirmar presença** (só a própria pessoa escalada).

10. **Escala** — lista de eventos à esquerda; ao selecionar um evento, mostra os ministérios e "slots":
    - Adicionar ministério ao evento; expandir/colapsar; adicionar pessoas (só membros do ministério + funções dessa pessoa); remover.
    - **Confirmar presença** por pessoa (botão ✅/❌; só a própria pessoa pode confirmar a sua).
    - **Publicar & Notificar**: publica a escala e abre painel de contactos com **multi-seleção** (checkboxes) + botão único "Enviar (N)"; gera **mensagem de WhatsApp** pronta (via `wa.me`) com nome, organização, ministério, data/hora e **hora de chegada**, e pedido de confirmação.
    - Abre automaticamente um evento vindo de uma **notificação** (`?event=<id>`).

11. **Repertório (Músicas)** — lista com pesquisa e filtro por ministério. Ações:
    - **Criar/Editar música**: campo Nome com **autocomplete que pesquisa o catálogo global** (por nome ou artista); ao escolher, preenche tudo (artista, letra, cifra, YouTube, Spotify, BPM). Campos: nome, artista, tom, BPM, ministério, links (YouTube/Spotify), cifra, letra.
    - **Detalhe da música**: mostra dados, links e ações.

12. **Ministérios** — lista de ministérios (ícone, cor, nº de membros). Ações:
    - **Criar/Editar ministério**: nome, ícone, cor, e **funções** (cada função com o seu ícone/emoji — codificadas como `custom␟<emoji>␟<label>`).
    - **Detalhe do ministério** e **gerir membros** (adicionar/remover pessoas e definir as funções de cada uma dentro do ministério).

13. **Pessoas (Membros)** — lista de membros (avatar, nome, cargo; **email só visível para admins**). Ações:
    - Mudar **cargo** (admin/líder/membro) via seletor; **remover** membro (eliminação real).
    - **Convidar** (nome + email → envia email/magic link); secção de **Convites pendentes** (cancelar).
    - **Detalhe do membro**: ministérios a que pertence e funções; email só admin.

14. **Definições** — secções:
    - **Perfil**: foto (upload + recorte), nome, telefone, aniversário.
    - **Organização** (admin): nome, **logótipo** (upload de imagem, não URL).
    - **Código de convite**: copiar (Clipboard API) / partilhar (Web Share API nativa).
    - **Sessão**: terminar sessão (logout).
    - **Esta organização**: sair da organização — se for a **última pessoa**, oferece **eliminar** a organização (e todos os dados); se for o único admin com mais pessoas, bloqueia com mensagem para passar o cargo primeiro.
    - **Zona de perigo**: eliminar conta permanentemente.

15. **Notificações** — sino no header com contador de não lidas; popover com lista; "marcar todas como lidas"; clicar numa notificação de escala abre o evento na tela de Escala para confirmar presença.

### Elementos globais
- **Tema escuro** forçado; fundo preto/navy; realces em `#a5b4fc` (índigo) e `#6ee7b7` (verde).
- **Barra de progresso** no topo em mudanças de página.
- **Barra de atividade global** no topo sempre que há gravação/edição em curso ou recarregamento de dados.
- **PWA offline** (Serwist): página `/offline`, precache de ícones e assets.

## 7. Regras de negócio / permissões

- **Admin:** vê tudo (incluindo rascunhos), gere membros/cargos, convida, cria/edita/elimina eventos, edita organização, vê emails, publica & notifica.
- **Non-admin (líder/membro):** vê apenas **eventos publicados** + eventos onde está **escalado**; **não** vê o botão "Criar evento"; **não** vê emails de outros; só pode confirmar a **sua própria** presença.
- **Único admin:** não pode sair da organização sem passar o cargo (ou eliminar a organização se for a última pessoa).

## 8. Integrações e detalhes técnicos

- **WhatsApp:** links `wa.me` com mensagem pré-preenchida (sem API); um chat por link.
- **YouTube:** playlist "watch_videos" a partir dos links das músicas do setlist (playlist anónima, sem nome).
- **Pesquisa de músicas:** feita **no banco de dados global** (`catalog_songs`); (versão anterior usava iTunes Search API, removida).
- **Partilha/Cópia:** Clipboard API (copiar) e Web Share API (partilhar nativo).
- **Envio de email:** Supabase + SMTP (Gmail App Password).

## 9. Identidade visual (Brand Kit WIS)

- **Símbolo:** "o adorador" — um W cujas curvas formam uma pessoa de braços erguidos, com o ponto como cabeça. SVG em `/brand/wis-symbol.svg` (degradê) e `/brand/wis-symbol-white.svg` (branco).
- **Cores:** Azul Marinho `#0D3B66` → Azul Petróleo `#0F5C6E` (degradê 135°); realce do ícone `#1B7A8C`.
- **Tipografia:** Poppins Bold (WIS) · Poppins Light uppercase espaçado (WORSHIP IN SYNC).
- **Ícones/PWA:** favicon, `icon-192/512` (`any`), `maskable-192/512` (`maskable`), `apple-touch-icon`, `icon.svg`, `og-image` (1200×630), `splash`.
- **CSS do degradê:** `linear-gradient(135deg, #0D3B66 0%, #0F5C6E 100%)`.

---

# PARTE 2 — PROMPT PARA RECRIAR A APP EM REACT NATIVE

> Copia o bloco abaixo e usa-o como instrução para um assistente de código (ou como brief de desenvolvimento). Foi escrito para **Expo (React Native)** com publicação na **App Store** e **Google Play**.

---

**PROMPT:**

Constrói uma aplicação **mobile nativa** chamada **"WIS — Worship In Sync"** usando **React Native com Expo (SDK 56)** e **TypeScript**, para publicação na **Apple App Store** e na **Google Play Store**. A app é uma ferramenta de **gestão de ministérios e escalas para igrejas**. Deve reutilizar **exatamente o mesmo backend Supabase** já existente (mesma base de dados, auth e storage) — não recries o backend, apenas consome-o.

## Requisitos técnicos obrigatórios
- **Expo SDK 56** (consulta sempre a documentação versionada em https://docs.expo.dev/versions/v56.0.0/ antes de escrever código — a API do Expo mudou).
- **expo-router** para navegação (file-based), com stacks e tabs nativas.
- **TypeScript** estrito.
- **Supabase** via `@supabase/supabase-js` + `@react-native-async-storage/async-storage` para persistir a sessão (usa o `storage` do Supabase auth apontando para AsyncStorage; ativa `autoRefreshToken` e `persistSession`). Trata o app state (foreground/background) para `startAutoRefresh/stopAutoRefresh`.
- **TanStack Query v5** para estado de servidor (com um `MutationCache` global que invalida todas as queries após qualquer mutação bem-sucedida — replica o comportamento de "recarregar tudo ao gravar").
- **Zustand** para estado cliente (`authStore`, `orgStore` com `activeOrg`, `activeMembership`).
- **react-hook-form + zod** para formulários e validação.
- Estilização: usa **NativeWind** (Tailwind para RN) ou StyleSheet nativo — mantém o **tema escuro** com fundo preto/navy e os realces da marca.
- Ícones: **lucide-react-native** ou `@expo/vector-icons`.
- **EAS Build** e **EAS Submit** configurados para gerar binários e submeter a ambas as lojas. Inclui `app.json`/`app.config.ts` com bundle identifier iOS e package Android, ícone, splash, e permissões.

## Substituições "web → nativo" (muito importante)
- **Notificações:** substitui as notificações web por **push nativo** com `expo-notifications` (regista o Expo Push Token no perfil do utilizador; envia via Expo Push ou Edge Function do Supabase). Ao tocar numa notificação de escala, faz **deep link** para o ecrã do evento correspondente para confirmar presença.
- **Partilha:** usa a **Share API nativa** (`react-native` `Share`) em vez da Web Share API.
- **WhatsApp:** abre `whatsapp://send?phone=...&text=...` (com fallback para `https://wa.me/...`) via `Linking`.
- **Imagens (avatar, logo, capa de evento):** usa `expo-image-picker` (galeria/câmara) + recorte (`expo-image-manipulator`) e faz upload para o **Supabase Storage** (buckets `avatars` e `events`).
- **Deep links / auth callback:** configura esquema de deep link (`wis://`) e universal/app links para os fluxos de **confirmação de email**, **convite** e **recuperação de password** (usa `expo-linking` + `WebBrowser` para o fluxo OAuth/OTP do Supabase).
- **Clipboard:** `expo-clipboard`.
- **Datas:** `date-fns`.
- **Playlist YouTube:** abre o link `watch_videos` no browser via `Linking`.

## Identidade visual (Brand Kit WIS)
- Nome: **WIS — Worship In Sync**; nome curto: **WIS**.
- Símbolo: "o adorador" (um W que forma uma pessoa de braços erguidos, com o ponto como cabeça). Usa o SVG branco sobre fundos navy.
- Cores da marca: degradê **`#0D3B66` → `#0F5C6E`** (135°); realce índigo `#a5b4fc` e verde `#6ee7b7`.
- Tema escuro por defeito (fundo preto/navy).
- Splash screen e ícone da app com o símbolo WIS.

## Modelo de dados (já existe no Supabase — consome tal como está)
Tabelas: `profiles`, `organizations`, `organization_members` (role: admin/leader/member), `organization_invites`, `ministries` (com `functions text[]`), `ministry_members` (com `functions text[]`), `events` (com `arrival_time`), `event_ministries`, `event_schedules` (`confirmed` bool nullable), `event_setlists` (com `musical_key` por evento), `songs` (biblioteca por org, com `catalog_song_id`), `catalog_songs` (catálogo GLOBAL partilhado, único por nome+artista), `notifications`. [Ver descrição detalhada na Parte 1.]

## Papéis e permissões
- **admin:** acesso total (rascunhos, gerir membros/cargos, convidar, criar/editar/eliminar eventos, editar organização, ver emails, publicar & notificar).
- **leader/member:** vê apenas eventos **publicados** + onde está escalado; não vê "criar evento"; não vê emails de outros; só confirma a sua própria presença.
- Único admin não pode sair sem passar o cargo; se for a última pessoa, pode **eliminar** a organização.

## Ecrãs a implementar (todos)

**Auth (stack pública):**
1. Login (email/password, ver password, "esqueci password", ir para registo).
2. Registo (nome, email, password + confirmar com validação de igualdade e mínimo 6 caracteres, ver password, ecrã "confirma o teu email").
3. Recuperar password (email → envia link).
4. Definir nova password (após convite/recuperação).

**Onboarding:**
5. Seleção de organização (lista das orgs do user com logo/nome/cargo; criar organização; entrar por código; logout). Entra direto na última organização usada (persistida localmente).
6. Criar organização (nome).
7. Entrar por código de convite.

**App (tabs nativas por organização): Dashboard · Eventos · Escala · Repertório · Mais**
8. **Dashboard:** saudação, próximos eventos (badges Publicado/Rascunho + período Manhã/Tarde/Noite 🌅☀️🌙 derivado da hora), aniversários, botão "Criar evento" só admin.
9. **Eventos:** lista com filtros (Todos/Publicados/Rascunhos); criar/editar evento com **abas** (Informação: nome, data, hora, **hora de chegada**, local, descrição, observações, imagem de capa, publicado; Ministérios; Integrantes: só membros do ministério + funções da pessoa; Setlist: músicas + **Tom por evento**) e um único botão Gravar/Criar; **detalhe do evento** (abas Equipa e Setlist, playlist YouTube, confirmar presença).
10. **Escala:** selecionar evento → ministérios/slots → adicionar ministério, adicionar pessoas (só membros + funções), confirmar presença (só a própria), **Publicar & Notificar** (multi-seleção + WhatsApp com mensagem pronta incl. hora de chegada). Abrir evento via deep link de notificação.
11. **Repertório:** lista (pesquisa + filtro por ministério); criar/editar música com **autocomplete que pesquisa o catálogo global** (nome/artista) e preenche tudo (artista, letra, cifra, YouTube, Spotify, BPM); ao gravar contribui campos vazios de volta ao catálogo global sem duplicar; detalhe da música.
12. **Ministérios:** lista; criar/editar (nome, ícone, cor, funções com emoji/ícone); gerir membros e funções.
13. **Pessoas:** lista (email só admin); mudar cargo; remover; convidar (nome+email → email/magic link); convites pendentes; detalhe do membro.
14. **Definições:** perfil (foto+recorte, nome, telefone, aniversário); organização (nome, logo upload); código de convite (copiar/partilhar nativo); logout; sair/eliminar organização; eliminar conta.
15. **Notificações:** lista + não lidas + marcar lidas; push nativo; tocar abre o evento na Escala.

## Regras de negócio a replicar
- Período do dia automático pela hora do evento (Manhã 05–12h, Tarde 12–18h, Noite 18–05h).
- Tom da música guardado **por evento** (`event_setlists.musical_key`).
- Catálogo de músicas global partilhado com contribuição só de campos vazios.
- Convite: se a pessoa já tem conta → magic link; senão → email de definir password; ao entrar é adicionada à organização automaticamente.
- Após qualquer gravação, recarregar os dados (invalidação global do TanStack Query).
- Feedback de loading claro ao gravar/editar (indicador nativo).

## Entregáveis
- Projeto Expo funcional (iOS + Android) com todos os ecrãs acima.
- Autenticação Supabase persistente com refresh automático.
- Push notifications nativas + deep links.
- `app.config.ts` com identidade WIS (ícone, splash, cores, bundle id iOS + package Android, permissões de câmara/galeria/notificações).
- Configuração **EAS Build** (perfis development/preview/production) e **EAS Submit** para App Store e Play Store.
- README com instruções de build/submit e variáveis de ambiente (URL e anon key do Supabase).

Mantém a **paridade funcional** com a app web descrita, adaptando cada padrão web ao equivalente **nativo** (navegação por tabs/stack, gestos, push, partilha, câmara, deep links).
