# FlashMED Casos

Aplicação Next.js para casos clínicos gamificados, com salas controladas pelo professor, ranking em tempo real e persistência no Supabase.

## Configuração

1. Execute [`supabase/schema.sql`](./supabase/schema.sql) no SQL Editor do mesmo projeto Supabase usado pelo FlashMED Lombalgia.
   - Se o projeto já tinha dados nas tabelas antigas `fmd_disuria_*`, execute também [`supabase/migrate-disuria-data-to-generic.sql`](./supabase/migrate-disuria-data-to-generic.sql) para copiá-los para as tabelas genéricas `fmd_*`.
2. Crie `.env.local` a partir de `.env.example`:

```env
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
```

3. Instale e execute:

```powershell
npm install
npm run dev
```

## Rotas

- `/`: entrada do aluno por código da sala.
- `/professor`: criação de uma sala.
- `/professor/[roomId]/[adminKey]`: painel administrativo secreto.
- `/status/[roomCode]`: placar público.

O conteúdo clínico permanece em `data/cases.json` e os termos em `data/medicalTerms.json`. O Supabase armazena somente salas, grupos, tentativas e resultados.
