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

## Estado

Projeto em arranque — scaffold Flutter ainda por criar.
