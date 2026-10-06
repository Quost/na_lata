# Supabase local com contas A/B (QUA01)

Banco descartável na sua máquina para testar permissões sem mexer nos dados da turma. Tudo aqui só toca o Docker local; o projeto remoto e `config/classroom.json` não são alterados.

## Pré-requisitos

- Docker Desktop aberto.
- Node.js (o script usa `npx supabase@2.119.0`, versão fixa para todos).
- Primeira subida baixa as imagens (alguns minutos).

## Comandos

```sh
dart run tool/local_supabase.dart start   # sobe, aplica migrações + seeds e gera config/local*.json
dart run tool/local_supabase.dart check   # confere URL local, login A/B, fixtures e uma regra de RLS
dart run tool/local_supabase.dart seed    # reaplica só os seeds (idempotente)
dart run tool/local_supabase.dart reset   # recria o banco local do zero
dart run tool/local_supabase.dart stop
```

Proteções: o script recusa `--linked`, `--db-url` e `--project-ref`; antes de `reset`/`seed` confere no `supabase status` que API e banco são locais; `check` falha se a URL não for `127.0.0.1`, `localhost` ou `10.0.2.2`. Nenhum comando lê ou imprime as chaves secretas do CLI; o app usa só a chave `sb_publishable_`.

Studio local: <http://127.0.0.1:54323>.

## Contas de teste

| Conta | Email | Senha | ID |
|---|---|---|---|
| A | aluno.a@nalata.local | nalata-local-123 | aaaaaaaa-0000-4000-8000-00000000000a |
| B | aluno.b@nalata.local | nalata-local-123 | bbbbbbbb-0000-4000-8000-00000000000b |

Senha pública de propósito: só existe no banco local. O app continua entrando como anônimo; as contas A/B são usadas pelo smoke e pelo Studio. Fixtures: [supabase/seeds/README.md](../supabase/seeds/README.md).

## Rodar o app no banco local

| Onde | Configuração | Por quê |
|---|---|---|
| Emulador Android | `config/local.android.json` | `10.0.2.2` é a máquina hospedeira vista pelo emulador |
| Web/desktop/aparelho com `adb reverse tcp:54321 tcp:54321` | `config/local.json` | `127.0.0.1` |

```sh
flutter run --dart-define-from-file=config/local.android.json
```

O build **debug** do Android libera HTTP só para esses três hosts (`android/app/src/debug/res/xml/network_security_config.xml`); release continua exigindo HTTPS. Para voltar à turma, use `dart run tool/run.dart` (lê `classroom.json`).

## Smoke A/B com repositórios reais

`integration_test/local_ab_smoke_test.dart` entra como A e B e usa `SupabaseProducts`, `SupabaseReviews`, `SupabaseCommunity` e `SupabaseListRepository` de verdade: A grava avaliação, B lê mas não altera nem exclui; favoritos, denúncias e lista privada ficam com o dono. A única escrita é apagada no fim. Recusa URL que não seja local.

```sh
flutter test integration_test --dart-define-from-file=config/local.android.json   # com emulador aberto
```

Precisa de um dispositivo (emulador Android). `flutter test` sem caminho não roda esta pasta: a suíte unitária continua sem banco real.

## Roteiro manual (PR)

1. `start` do zero → `check` passa.
2. `seed` duas vezes → `check` passa e as contagens não mudam.
3. Smoke A/B no emulador → todos passam; rodar de novo também passa.
4. `check --config=config/classroom.json` → **falha** com "Recusado" (URL não local).
5. `reset --linked` → **falha** com "Recusado".
6. App no emulador com `local.android.json` → catálogo mostra os 5 produtos "Teste".

## Problemas comuns

- `Supabase local não está rodando`: abra o Docker e rode `start`.
- Porta 54321 ocupada: outro projeto Supabase local está ativo; `npx supabase stop --project-id OUTRO`.
- Emulador sem conexão: use `local.android.json`, não `local.json`.
