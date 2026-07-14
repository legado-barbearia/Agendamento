# Preparacao do Supabase - Legado Barbearia

O projeto funciona com GitHub Pages usando a chave publica do Supabase. Nunca coloque a chave `service_role` no site.

## Arquivos principais

- `supabase-schema.sql`: tabelas, indices, RLS, Storage e funcoes RPC.
- `supabase-config.example.js`: modelo para URL e chave publica.
- `supabase-config.js`: arquivo local/publicado com as credenciais publicas do projeto.

## Ordem recomendada

1. Execute o `supabase-schema.sql` completo no SQL Editor.
2. Crie o usuario administrador em Authentication > Users.
3. Copie o UUID desse usuario.
4. Rode o SQL abaixo trocando o UUID e o nome:

```sql
insert into public.profiles (id, name, role)
values ('COLE_AQUI_O_UUID_DO_USUARIO', 'Administrador Legado', 'owner')
on conflict (id) do update
set name = excluded.name,
    role = excluded.role;
```

5. Renomeie `supabase-config.example.js` para `supabase-config.js`.
6. Preencha `url` e `anonKey` ou `publishable key`.
7. Abra `admin.html` e entre com o e-mail e senha criados no Supabase Auth.

## Edge Function para criar acesso de barbeiro

O painel possui o botao "Criar acesso" na area Barbeiros. Ele chama uma Edge Function segura, porque a chave `service_role` nunca pode ficar no navegador.

1. Instale e autentique a Supabase CLI.
2. Configure os secrets da funcao:

```bash
supabase secrets set SUPABASE_URL="https://SEU-PROJETO.supabase.co"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="SUA_SERVICE_ROLE_KEY"
supabase secrets set SUPABASE_ANON_KEY="SUA_CHAVE_PUBLICA"
```

3. Publique a funcao:

```bash
supabase functions deploy manage-barber-access
```

4. No painel, cadastre o barbeiro com e-mail e clique em "Criar acesso".
5. Para trocar a senha temporaria depois, use "Redefinir senha" na mesma linha do barbeiro.

Essa funcao:

- valida se o usuario logado e `owner` ou `admin`;
- cria o usuario no Supabase Auth;
- cria/atualiza o registro em `profiles` com `role = 'barber'`;
- cria/atualiza o registro em `barbers`;
- redefine a senha temporaria quando solicitado pelo administrador;
- nao salva senha em nenhuma tabela do projeto.

Se o e-mail ja existir no Auth, use "Redefinir senha" para o perfil de barbeiro existente ou remova/ajuste o usuario pelo painel do Supabase.

## Regras de seguranca

- Usuarios com `profiles.role` igual a `owner` ou `admin` entram no painel completo.
- Usuarios com `profiles.role` igual a `barber` entram apenas na propria area individual.
- Qualquer usuario autenticado sem perfil autorizado e recusado.
- Cliente publico pode consultar disponibilidade, criar agendamento por RPC, cancelar por telefone + codigo e enviar feedback pendente.
- Cliente publico nao pode listar agendamentos, clientes, financeiro ou configuracoes privadas.
- Agendamentos publicos devem passar pela RPC `reserve_booking`, que valida conflito no banco.
- Cancelamento publico deve passar pela RPC `cancel_booking`.

## Testes obrigatorios

1. Login com usuario `owner`.
2. Login com usuario sem perfil em `profiles` deve ser recusado.
3. Cliente agenda no site e horario some para outro cliente.
4. Cliente consulta com WhatsApp + codigo em outro navegador.
5. Cliente cancela e o horario volta a ficar disponivel.
6. Admin edita portfolio e as imagens aparecem no site publico.

## Observacoes

- O localStorage fica apenas como cache, backup ou funcionamento local.
- Se o painel mostrar erro de permissao, confirme se o usuario logado existe em `profiles`.
- Se a consulta ou cancelamento nao funcionar, rode novamente o `supabase-schema.sql` completo.
