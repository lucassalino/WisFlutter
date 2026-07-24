# PRD — Novas Funcionalidades (ciclo Julho 2026)

**Produto:** WIS — Worship In Sync
**Autor:** Lucas + Claude Code
**Estado:** Implementado e em produção (código), planos de assinatura ainda não aplicados
**Relacionado:** [roadmap-planos-assinatura.md](roadmap-planos-assinatura.md) (documento vivo, origem destas funcionalidades)

---

## 1. Contexto e motivação

O WIS já cobria o essencial de gestão de escalas (eventos, ministérios, escalar pessoas, repertório). Este ciclo teve como objetivo **construir todas as funcionalidades planeadas para os planos pagos antes de implementar o sistema de planos em si** — decisão explícita do product owner: validar o produto completo primeiro, cobrar depois.

Fica fora deste PRD: estrutura de preços, gateway de pagamento, enforcement de limites por plano — ver secções 1, 2 e 5 do roadmap.

## 2. Resumo das funcionalidades

| # | Funcionalidade | Quem usa | Plano-alvo (futuro) |
|---|---|---|---|
| 1 | Roteiro do evento | Admin/líder cria, todos veem | Comunhão |
| 2 | Calendário geral | Todos | Grátis (Semente) |
| 3 | Ranking de músicas mais tocadas | Todos (Repertório) | Comunhão |
| 4 | Exportar roteiro/escala em PDF | Admin | Comunhão/Expansão |
| 5 | ~~Histórico pessoal do voluntário~~ (revertido — ver secção 7) | — | Crescimento |
| 6 | Disponibilidade (pontual/recorrente) | Todos | Comunhão (pontual já no Crescimento) |
| 7 | Guardar evento no calendário do telemóvel | Todos | Grátis (não depende de servidor) |

---

## 3. Roteiro do evento

### Problema
Quem organiza um culto/evento planeia mentalmente ou em papel os horários ("7h15 chegada, 7h30 ensaio, 9h devocional, 10h início"). Não havia forma de registar isso na app nem de o partilhar com a equipa.

### Requisitos
- Novo passo no wizard de criação/edição de evento, **depois do Setlist**: lista de itens `hora + título`, ordenados automaticamente por hora.
- Visível a todos no detalhe do evento, separador "Roteiro".
- Não substitui o campo já existente "Hora de chegada da equipa" (`events.arrival_time`) — são coisas diferentes (uma hora única vs. vários pontos do evento).

### Design técnico
- Tabela `event_timeline_items` (`event_id`, `time`, `title`, `order_index`) — migração `008_event_timeline_items.sql`.
- RLS: leitura para qualquer membro da org; escrita só admin/líder.
- `fetchEventTimelineAction` / `setupEventTimelineAction` em `src/actions/schedule.ts`; hook `useEventTimeline`.
- UI: passo 5 do wizard (`EventCreatePanel.tsx` / `EventEditPanel.tsx`), separador "Roteiro" em `EventDetailPanel.tsx`.

### Fora de âmbito
Notificações específicas por item do roteiro (ex.: lembrete "daqui a 10 min é o devocional") — não pedido.

---

## 4. Calendário geral

### Problema
A única forma de ver eventos era a lista em "Eventos". Não havia vista de mês nem forma rápida de ver "o que tenho esta semana".

### Requisitos
- Nova página `/[orgId]/calendar`: grelha de mês (semana começa à segunda) + lista de eventos do dia selecionado.
- Acessível a todos, herda a mesma regra de visibilidade de `fetchEventsAction` (admin vê tudo incl. rascunhos; restantes veem publicados + onde estão escalados).
- Navegação entre meses, botão "Hoje".
- Mostra também os avisos de indisponibilidade da própria pessoa nesse dia (ver secção 6).
- Adicionada à navegação (Sidebar desktop, BottomNav mobile).

### Design técnico
- `src/modules/calendar/CalendarClient.tsx`, `src/app/(dashboard)/[orgId]/calendar/page.tsx`.
- Sem tabela nova — reaproveita `useEvents()` e agrupa client-side por data.

---

## 5. Ranking de músicas mais tocadas

### Problema
Bandas de louvor querem saber que músicas tocam mais, para variar o repertório ou reforçar ensaios das mais recorrentes.

### Requisitos
- Nova vista "Ranking" dentro de Repertório (toggle Lista/Ranking).
- Para cada música: número de vezes tocada e data da última vez.
- Ordenado por número de vezes (desc).

### Design técnico
- `fetchSongsRankingAction` (`src/actions/songs.ts`): agrega `event_setlists` (join a `events.date`) por `song_id`, conta ocorrências e guarda a data mais recente.
- UI: toggle em `src/modules/songs/SongsClient.tsx`.
- Sem tabela nova.

### Casos de borda
- Música nunca tocada (0 ocorrências em `event_setlists`) aparece no fim, sem "última vez".

---

## 6. Exportar roteiro/escala em PDF

### Problema
No dia do evento, a equipa (produção, som, direção) quer uma folha impressa com tudo: roteiro, quem está escalado em cada ministério, e o repertório. Não fazia sentido tirar prints de 3 ecrãs diferentes.

### Requisitos
- Botão "Exportar" no detalhe do evento (admin), abre `/[orgId]/events/[eventId]/print`.
- Uma folha em estilo claro/imprimível juntando: roteiro + escala por ministério + setlist.
- Usa a função nativa "Imprimir/Guardar como PDF" do browser — sem gerar PDF no servidor.

### Design técnico
- `src/modules/events/EventPrintClient.tsx`, rota `/[orgId]/events/[eventId]/print`.
- `window.print()` + CSS `@media print` isolando `#print-area` (`globals.css`) — o resto da app fica `visibility: hidden` durante a impressão.
- Sem dependência nova (nada de `puppeteer`/`react-pdf`).

---

## 7. Histórico pessoal do voluntário (REVERTIDO em 2026-07-18)

### Problema
Um voluntário não tinha forma de ver em quantos eventos já serviu, nem os líderes tinham essa informação num relance ao ver o perfil de alguém.

### Requisitos (como implementado originalmente)
- Secção "O meu histórico" em Definições → Perfil, e secção "Histórico" no perfil de qualquer membro (`MemberDetailPanel`).
- Mostra: total desde sempre, repartição por mês (gráfico de linha), seletor de mês (default = mês atual).
- Membro só vê o seu próprio; quem tem permissão de ver o perfil de outro membro vê o histórico dessa pessoa.

### Design técnico (como implementado originalmente)
- `fetchMyServiceHistoryAction(userId, orgId)` em `src/actions/schedule.ts` → `{ totalAllTime, byMonth: ServiceHistoryMonth[], entries: ServiceHistoryEntry[] }` (agrega `event_schedules` por mês).
- Hooks: `useServiceHistory(userId)` (genérico) e `useMyServiceHistory()` (wrapper para o próprio utilizador) em `src/hooks/useSchedule.ts`.
- Componente partilhado `src/components/ServiceHistorySection.tsx` (recharts `LineChart`, `<Select>` de mês) — usado em `SettingsClient.tsx` e `MemberDetailPanel.tsx`.

### Bug corrigido durante o desenvolvimento
Crash `Cannot read properties of undefined (reading 'length')` por cache antiga do TanStack Query com a forma de dados anterior — corrigido com optional chaining e troca da chave de cache (`my-service-history` → `service-history`).

### Motivo da reversão
No mesmo dia, um utilizador real recebeu **Error 1102 ("Worker exceeded CPU time limit")** em produção. Os logs do Cloudflare (Observability) confirmaram o erro exato e mostraram a app a correr no **plano gratuito do Workers** (10ms de CPU por pedido — muito apertado para SSR de Next.js). O `recharts` (usado só nesta funcionalidade) foi identificado como a única dependência genuinamente pesada adicionada nesta sessão, por isso foi removida junto com toda a funcionalidade, para reduzir o peso do bundle enquanto o plano continuar gratuito.

**Removido:** `ServiceHistorySection.tsx`, `useServiceHistory`/`useMyServiceHistory`, `fetchMyServiceHistoryAction` + tipos `ServiceHistoryEntry`/`ServiceHistoryMonth`/`MyServiceHistory`, dependência `recharts`.
**Preservado:** código completo na branch `full-features-2026-07` — reativar é só reverter este commit quando o Cloudflare Workers passar a plano pago (30s de CPU).

---

## 8. Disponibilidade (pontual e recorrente)

### Problema
Voluntários têm períodos em que sabem antecipadamente que não podem servir (viagem, exames, gravidez, etc.) — pontuais (datas fixas) ou recorrentes (ex.: "todas as terças à noite tenho curso"). Sem registo disso, quem escala só descobre o conflito depois, ou o voluntário tem de avisar manualmente todas as vezes.

### Requisitos
- Secção própria "Disponibilidade" na barra lateral (não dentro de Definições).
- Duas formas de registar: **pontual** (data de/até + motivo) e **recorrente** (dia da semana + período do dia [manhã/tarde/noite/dia todo] + motivo).
- Aviso visual (ícone + tooltip) sempre que se tenta escalar alguém indisponível — no diálogo de escalar (`PersonDialog`) e no passo 3 do wizard de evento (criar/editar). **Não bloqueia** — é só aviso; a decisão final é de quem escala.
- Calendário geral marca os dias com indisponibilidade da própria pessoa.
- **Visibilidade (decisão de produto):** todos os membros da organização veem *que* alguém está indisponível e quando (para saberem com quem não vale a pena tentar trocar turno) — mas só Admin/Líder (ou a própria pessoa) veem o **motivo**.

### Design técnico
- Tabela `member_unavailability` (`kind: date_range|weekly`, `start_date`/`end_date` ou `weekday`/`period`, `reason`) — migração `009_member_unavailability.sql`.
- **Redação do motivo é feita na camada de servidor, não em RLS** — RLS do Postgres restringe *linhas*, não *colunas*; `fetchUnavailabilityAction`/`fetchOrgUnavailabilityAction` (`src/actions/availability.ts`) calculam `canSeeReason` por pedinte (`getRequester()`) e anulam `reason` antes de responder a quem não tem permissão. RLS (migração `011_unavailability_visible_to_all.sql`) só controla quem vê a *linha* (todos os membros da org).
- `src/lib/availability.ts`: `findConflictingUnavailability`, `unavailabilityForDate`, `describeUnavailability`.
- UI: `src/modules/availability/` (`AvailabilityClient.tsx`, `UnavailabilitySection.tsx`), rota `/[orgId]/availability`.

### Histórico de decisão (para não repetir a volta)
1ª versão: só o próprio + admin/líder viam a linha toda (RLS restritivo). Revertido a pedido explícito do product owner: "deixem aparecer para todos, só o motivo é que fica reservado — assim já sei com quem não dá para trocar, sem saber porquê."

---

## 9. Guardar evento no calendário do telemóvel

### Problema
Depois de confirmar presença num evento, o voluntário quer esse compromisso na agenda do telemóvel (Google Calendar / Apple Calendar), para não haver conflito com outros compromissos pessoais.

### Iteração 1 (abandonada): link de subscrição `.ics`
Primeira tentativa: um link pessoal permanente (`/api/calendar/[token].ics`) que o utilizador subscrevia uma vez no Google/Apple Calendar, atualizando-se sozinho com todos os eventos onde a pessoa está escalada. Implementado, testado, e **revertido a pedido do product owner** — preferência por um fluxo mais direto, ligado ao momento de confirmar presença, em vez de um passo de configuração à parte. Tabela `calendar_feed_tokens` removida (migração `013_drop_calendar_feed_tokens.sql`).

### Iteração 2 (atual): popup no momento da confirmação
- Ao clicar **"Confirmar presença"** num evento, e a confirmação ter sucesso, aparece um popup: *"Guardar evento no calendário? Presença confirmada em '[nome]'. Queres adicionar ao calendário do teu telemóvel?"* — botões **Agora não** / **Guardar**.
- Ao clicar **Guardar**, gera-se um ficheiro `.ics` (RFC 5545) inteiramente no browser (sem pedido ao servidor) e entrega-se ao sistema operativo.
- Fica também um botão **"Adicionar ao calendário"** permanente ao lado da confirmação, para repetir a ação mais tarde.

### Comportamento por plataforma (limitação de sistema, não da app)
| Plataforma | Comportamento |
|---|---|
| iOS/Safari | Navegação direta para o `.ics` (em vez de forçar download) abre logo o ecrã "Adicionar evento" do Calendário da Apple — sem passo extra. |
| Android/Chrome | Descarrega o ficheiro; o Android mostra "Download concluído — toque para abrir", e só depois abre o Google Calendar. Esse toque extra não é contornável via JavaScript — é o próprio SO que intercepta o ficheiro. |
| Desktop | Descarrega o `.ics`; abre com o que estiver associado a esse tipo de ficheiro (Outlook, Google Calendar web, etc.). |

### Design técnico
- `src/lib/ics.ts`: `buildEventICS(event)` gera o conteúdo RFC 5545 (VEVENT único, duração default 2h, escapa `;`/`,`/`\n`, quebra linhas a 75 octetos); `downloadEventICS(event)` deteta iOS (`isIOS()`) e ramifica entre navegação direta (iOS) e download via `<a download>` (restantes).
- Popup: `AlertDialog` (Radix) em `EventDetailPanel.tsx`, disparado em `handleConfirm()` só quando a confirmação passa de não-confirmado para confirmado (`next === true`).
- Sem tabela nem rota nova — tudo client-side a partir dos dados do evento já carregados.

### Fora de âmbito (não implementado)
- Sincronização automática e contínua (a app não empurra atualizações para o calendário externo se o evento mudar de hora depois de guardado — o `.ics` é uma cópia estática no momento em que foi guardado).
- Cancelar/remover do calendário externo automaticamente se a pessoa desconfirmar presença.

---

## 10. Notas técnicas transversais

### Limite de complexidade genérica do `@supabase/ssr`
Durante o desenvolvimento da funcionalidade 9 (iteração 1), descobriu-se que o cliente `@supabase/ssr` (`createServerClient<Database>`, usado no wrapper `src/lib/supabase/server.ts`) deixa de tipar corretamente tabelas novas a partir da 17ª tabela no schema — resolve o tipo da linha como `never` silenciosamente, sem erro explícito de "profundidade excedida". Confirmado isolando o problema: qualquer 17ª tabela nova falha da mesma forma, independentemente do nome/conteúdo. O cliente puro `@supabase/supabase-js` (usado como `getAdmin()` nas actions, com service role) não tem este limite. **Padrão a seguir:** para tabelas novas, usar sempre `createClient()` só para `auth.getUser()`, e `getAdmin()` para a query em si — já era o padrão dominante no projeto, esta descoberta reforça que deve ser seguido sempre, não só por convenção.

### Tabela `subscriptions` já existe na base de dados
Descoberta lateral: já existe uma tabela `public.subscriptions` em produção (0 linhas), com o formato descrito em [wis-app-overview-and-rn-prompt.md](wis-app-overview-and-rn-prompt.md) (`plan`, `member_limit`, `revenuecat_id`, `expires_at`). Não está a ser usada pela app. Relevante para quando se avançar para o sistema de planos (secção 5 do roadmap) — convém decidir se se reaproveita esta tabela ou se se recria.

### Incidente: Error 1102 (Worker exceeded CPU time limit) em produção — 2026-07-18
Um utilizador real recebeu Error 1102 no browser. Os logs do Cloudflare (Workers & Pages → serviceflow → Observability) confirmaram: `Worker exceeded CPU time limit`, no pedido `GET /events?event=...&_rsc=...` (navegação suave a partir da Dashboard). A app corre no **plano gratuito do Cloudflare Workers**, que dá apenas **10ms de CPU por pedido** — muito apertado para SSR de Next.js, e a margem fica cada vez menor à medida que a app cresce.

- **Causa mais provável:** o limite de 10ms do plano gratuito, não um bug específico de loop/N+1 (revisto o código dos layouts e actions envolvidos, nada de anómalo).
- **Ação tomada:** removida a funcionalidade "Histórico pessoal do voluntário" (secção 7) e a dependência `recharts` — era a única biblioteca genuinamente pesada adicionada nesta sessão. Código preservado em `full-features-2026-07`.
- **Limpeza adicional:** removidas 5 dependências mortas (zero imports em `src/`, confirmado por grep): `date-fns`, `minimatch`, `cmdk`, `@radix-ui/react-toast`, `@tanstack/react-query-devtools`. Como não eram importadas em lado nenhum, o Next.js já não as incluía no bundle do Worker — esta limpeza não reduz CPU, só reduz o `node_modules` e a superfície de dependências.
- **Ação recomendada, não aplicada:** upgrade do Cloudflare Workers para o plano pago (5 USD/mês, sobe o limite para 30s de CPU) — é a correção estrutural; aligeirar o bundle só reduz a frequência do erro, não elimina a causa raiz.

---

## 11. Estado e próximos passos

6 das 7 funcionalidades continuam implementadas, com `npm run type-check` limpo. A funcionalidade 7 (Histórico pessoal) foi revertida no mesmo dia por causa do incidente acima — código completo preservado na branch `full-features-2026-07` para reativar quando o plano Cloudflare subir de tier.

Nenhuma funcionalidade foi testada em produção real (browser) neste ciclo — recomenda-se um teste manual do fluxo completo antes de anunciar aos utilizadores, sobretudo a funcionalidade 9 num iPhone e num Android reais (o comportamento do `.ics` depende do SO e é difícil de simular em desenvolvimento).

Próximos passos em aberto (não iniciados):
- Estrutura de planos de assinatura e faturação — ver roadmap, secções 1, 2, 5 e 6.
- Decidir sobre o upgrade do plano Cloudflare Workers (ver incidente acima) — condiciona se/quando o Histórico pessoal pode voltar.
