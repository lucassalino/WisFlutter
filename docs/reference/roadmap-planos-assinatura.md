# Roadmap — Planos de Assinatura e Novas Funcionalidades

> Documento de alinhamento. Nada aqui está implementado ainda — é para fechar as decisões antes de começar a codificar. Atualizar este ficheiro conforme as conversas avançam.

---

## 1. Estrutura dos 5 planos

Lógica: aumentar o limite de pessoas **e** as funcionalidades em conjunto, para que equipas pequenas com necessidades avançadas também sejam forçadas a subir de plano.

- [ ] **Semente** (Grátis) — até 10 pessoas, 1 ministério, 1 admin, escala simples, acesso do voluntário ao app.
- [ ] **Crescimento** — até 20 pessoas, até 3 ministérios, aviso de indisponibilidade, notificações push, calendário geral, histórico pessoal do voluntário.
- [ ] **Comunhão** (ponto de virada) — até 50 pessoas, ministérios ilimitados, troca de turnos com aprovação, anexo de arquivos, **roteiro do evento**, **ranking de músicas mais tocadas**, exportar roteiro/escala em PDF, disponibilidade recorrente, sincronização com calendário externo (Google/Apple).
- [ ] **Expansão** — até 100 pessoas, múltiplos administradores/líderes por ministério, lembretes automáticos por email, relatórios básicos de engajamento.
- [ ] **Ilimitado** (Premium — *fica para mais tarde*) — sem limite de pessoas, WhatsApp automático via WhatsApp Business API (número central da app), multi-campus, suporte prioritário.

## 2. Preços sugeridos (a validar com igrejas reais)

| Plano | Brasil | Portugal |
|---|---|---|
| Semente | Grátis | Grátis |
| Crescimento | R$ 29,90–39,90 | € 5,99–7,99 |
| Comunhão | R$ 59,90–79,90 | € 11,99–14,99 |
| Expansão | R$ 99,90–129,90 | € 19,99–24,99 |
| Ilimitado | R$ 199,90+ | € 39,99+ |

- [ ] Confirmar se os valores acima incluem IVA (Portugal, 23%) ou não.
- [ ] Validar preços com 2-3 líderes de igreja reais em cada país.
- [ ] Decidir gateway de pagamento: Stripe (suporta Pix e Multibanco/MB WAY) vs alternativa local no Brasil (Pagar.me/Iugu).

## 3. Novas funcionalidades a desenhar

- [x] **Calendário geral** — nova página `/[orgId]/calendar` (vista de mês + lista de eventos do dia selecionado), acessível a todos (herda a mesma regra de visibilidade de `fetchEventsAction`). Adicionada à navegação (Sidebar desktop e BottomNav mobile). Implementado em 2026-07-18. Grátis em todos os planos.
- [x] **Sincronização com calendário externo** (Google/Apple via ficheiro .ics) — botão "Adicionar ao calendário" junto à confirmação de presença no `EventDetailPanel` (aparece assim que a pessoa confirma que vai); descarrega um `.ics` do evento gerado no próprio cliente (`src/lib/ics.ts`, `buildEventICS`/`downloadEventICS`), sem passar pelo servidor. Funciona com Google Calendar, Apple Calendar e Outlook, e offline. (Tentativa anterior com link de subscrição por token foi abandonada e revertida — migração `013_drop_calendar_feed_tokens.sql`.) Implementado em 2026-07-18. Grátis em todos os planos (não depende de servidor).
- [x] **Ranking de músicas mais tocadas** — nova vista "Ranking" dentro de Repertório (toggle Lista/Ranking), agregação sobre `event_setlists`/`songs` (`fetchSongsRankingAction`), mostra nº de vezes tocada e data da última vez. Implementado em 2026-07-18. Plano Comunhão (a aplicar quando os planos forem implementados).
- [x] **Roteiro do evento** — Passo 5 no wizard de criação/edição de evento (após "Setlist"), lista de itens `hora + título` (ordenada automaticamente por hora). Mantém o campo "Hora de chegada da equipa" do Passo 1 como está. Visível também no `EventDetailPanel` (separador "Roteiro"). Implementado em 2026-07-18 — tabela `event_timeline_items`. Plano Comunhão (a aplicar quando os planos forem implementados).
- [x] **Exportar roteiro/escala em PDF** — nova rota `/[orgId]/events/[eventId]/print` (botão "Exportar" no detalhe do evento, admin), junta roteiro + escala por ministério + setlist numa folha em estilo claro/imprimível; usa `window.print()` (Guardar como PDF do navegador) em vez de biblioteca nova. Implementado em 2026-07-18. Plano Comunhão/Expansão (a aplicar quando os planos forem implementados).
- [ ] ~~**Histórico pessoal do voluntário**~~ — implementado em 2026-07-18, **revertido em 2026-07-18**: o gráfico (recharts) e a agregação por mês contribuíam para o Worker exceder o limite de CPU no plano gratuito do Cloudflare (Error 1102, confirmado nos logs de produção). Código completo preservado na branch `full-features-2026-07` para reativar quando o plano Cloudflare for pago (30s de CPU em vez de 10ms).
- [x] **Disponibilidade** (pontual e recorrente) — nova secção "A minha disponibilidade" em Definições (`member_unavailability`): pontual (data de/até + motivo) ou recorrente (dia da semana + manhã/tarde/noite/dia todo + motivo). Aviso visual (ícone vermelho + tooltip) sempre que se tenta escalar alguém indisponível — no `PersonDialog` (Escalas) e no Passo 3 do wizard de evento (criar/editar). Não bloqueia, só avisa — a decisão final fica com quem escala. Implementado em 2026-07-18. Plano Comunhão (a aplicar quando os planos forem implementados; inclui já a versão "pontual" do Crescimento).

## 4. O que já existe no schema atual (referência)

- `event_setlists` já tem `order_index` — padrão de referência para o Roteiro do evento.
- `events.arrival_time` já existe (campo único, não é lista) — ver [EventCreatePanel.tsx](../src/modules/events/EventCreatePanel.tsx).
- O doc [wis-app-overview-and-rn-prompt.md](wis-app-overview-and-rn-prompt.md) já descreve uma tabela `subscriptions` conceptual (`plan`, `member_limit`, `revenuecat_id`, `expires_at`) pensada para a versão mobile/RevenueCat — reconciliar com este roadmap quando avançarmos para o schema real.
- Hoje **não existe** nenhuma tabela de planos/subscrições ativa em produção — tudo isto ainda é conceptual.

## 5. Decisões técnicas para quando o código começar

- [ ] Tabela `event_timeline_items` (ou nome equivalente): `event_id`, `time`, `title`, `order_index`.
- [ ] Tabela(s) de planos/subscrições: `plans` (catálogo) + `org_subscriptions` (ou reaproveitar/ajustar o conceito `subscriptions` já esboçado no doc RN) com limites por org (nº pessoas, nº ministérios, admins).
- [ ] Lógica de enforcement dos limites (bloquear convite/criação acima do limite do plano).
- [ ] WhatsApp automático (Ilimitado): decidir provedor (Meta Cloud API direto vs Twilio) e aprovação de negócio (WABA) — processo demora dias/semanas, não deixar para a véspera do lançamento.

## 6. Perguntas em aberto

- [ ] Mercado prioritário de lançamento: Brasil, Portugal, ou ambos ao mesmo tempo? (afeta faturação/impostos/idioma de suporte)
- [ ] O plano Ilimitado/WhatsApp automático fica mesmo para depois — confirmado pelo utilizador (2026-07-17).
