# Finalizacao de producao - Legado Barbearia

Este arquivo lista a ordem exata para finalizar a versao online.

## 1. Supabase SQL

No painel do Supabase, abra:

SQL Editor -> New query

Cole e execute o conteudo completo de:

```text
supabase-schema.sql
```

Depois rode esta verificacao:

```sql
select
  to_regclass('public.bookings') as bookings_table,
  to_regclass('public.clients') as clients_table,
  to_regclass('public.barbers') as barbers_table,
  to_regprocedure('public.reserve_booking(uuid,text,text,text,integer,numeric,date,time,text,text,text,text,text,text,text)') as reserve_booking_rpc,
  to_regprocedure('public.booked_intervals_for_professional(date,text)') as booked_intervals_for_professional_rpc,
  to_regprocedure('public.lookup_booking(text,text)') as lookup_booking_rpc,
  to_regprocedure('public.cancel_booking(text,text,text)') as cancel_booking_rpc;
```

Tudo deve retornar preenchido, sem `null`.

## 2. Edge Function dos barbeiros

Instale e autentique a Supabase CLI, se ainda nao tiver:

```bash
supabase login
supabase link --project-ref pvapfmoejntpadjtyezj
```

Configure os secrets:

```bash
supabase secrets set SUPABASE_URL="https://pvapfmoejntpadjtyezj.supabase.co"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="SUA_SERVICE_ROLE_KEY"
supabase secrets set SUPABASE_ANON_KEY="SUA_CHAVE_PUBLICA"
```

Publique a funcao:

```bash
supabase functions deploy manage-barber-access --project-ref pvapfmoejntpadjtyezj
```

## 3. GitHub Pages

Envie os arquivos atualizados para o repositorio:

```bash
git add .
git commit -m "Finaliza integracao Supabase e painel Legado"
git push
```

## 4. Teste obrigatorio

1. Abra o site publico em uma aba anonima.
2. Cadastre um cliente no primeiro acesso.
3. Escolha servico, barbeiro, data e horario.
4. Confirme o agendamento.
5. Abra outro navegador/celular e confirme que o mesmo horario nao aparece mais.
6. Abra `admin.html` e confirme que o horario aparece como reservado.
7. Desmarque pelo admin e confira que o horario volta a aparecer.
8. Envie um feedback pelo site e aprove pelo admin.
9. Edite um barbeiro no admin e confirme que ele aparece corretamente no site.

## 5. Resultado esperado

- Agendamento salva no Supabase como `confirmed`.
- Horario reservado some para outros clientes.
- Admin enxerga horario reservado.
- Admin consegue desmarcar para liberar o horario.
- Perfil do cliente fica salvo pelo WhatsApp normalizado.
- Feedback entra como pendente e so aparece no site depois de aprovado.
- Barbeiro pode ter acesso criado pela Edge Function.
