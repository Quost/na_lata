# Começar no Na Lata

## 1. Baixar e preparar

Requer Flutter 3.38.5, Android SDK e um Android conectado ou emulador iniciado.

```sh
git clone https://github.com/ADSSTech/na_lata.git
cd na_lata
flutter pub get
```

O pacote `supabase_flutter` já está instalado e fixado no projeto. Não rode `flutter pub add` novamente e não substitua `main.dart` pelo exemplo Todos do painel: nossa integração já usa a inicialização oficial com `publishableKey` e os clientes compartilhados.

## 2. Receber a configuração do professor

Coloque o arquivo **classroom.json** recebido em **config/classroom.json**. Confira que não virou `classroom.json.txt` no Windows. O arquivo tem APP_MODE, SUPABASE_URL e SUPABASE_PUBLISHABLE_KEY; não precisa editar código.

Se precisar preparar o arquivo manualmente, copie `config/classroom.example.json` para `config/classroom.json` e preencha os valores recebidos. No PowerShell, `Copy-Item config/classroom.example.json config/classroom.json`; no macOS/Linux, `cp config/classroom.example.json config/classroom.json`.

O arquivo real fica fora do Git. Distribuímos somente URL e chave pública `sb_publishable_...`. O banco usa sessão de usuário e RLS para controlar acesso; esse arquivo não contém senha de banco nem chave administrativa.

## 3. Executar

No terminal, dentro da pasta do projeto:

```sh
dart run tool/run.dart
```

O comando verifica a configuração e executa `flutter run --dart-define-from-file=config/classroom.json`. Se houver mais de um dispositivo, escolha o Android. Também pode usar `dart run tool/run.dart -d ID_DO_DISPOSITIVO`.

No **VS Code**, abra a pasta `na_lata`, selecione o dispositivo Android e, em Executar e Depurar, escolha **Na Lata · Supabase da turma** e pressione F5. A configuração já está no repositório.

No **Android Studio**, acrescente `--dart-define-from-file=config/classroom.json` em Additional run args da configuração Flutter.

**Sem banco/rede:** execute `dart run tool/run.dart --demo` ou escolha **Na Lata · Demonstração** no VS Code. Esse modo usa dados fictícios. Falha no Supabase nunca muda automaticamente para demo.

Depois de modificar o JSON, pare o app e execute novamente; hot reload não atualiza parâmetros de compilação.

## 4. Conferir conexão

```sh
dart run tool/check_supabase.dart
```

Esse comando consulta as configurações de autenticação e não cria usuários. Se apontar login anônimo desabilitado, avise o professor. O professor também precisa ter aplicado a migração do banco. O primeiro catálogo real pode estar vazio: as tasks importam produtos conforme forem entregues.

| Sintoma | O que fazer |
|---|---|
| Falta classroom.json | Colocar o arquivo recebido na pasta config |
| Chave/configuração inválida | Copiar os valores do professor; não usar sb_secret_ ou service_role |
| Login anônimo desabilitado | Professor habilita Anonymous Sign-Ins no painel |
| Erro de tabela ou permissão | Professor confere migração e RLS; não desabilitar a segurança |
| Aparece DEMONSTRAÇÃO | Usar o comando/perfil Supabase; flutter run sem parâmetros abre demo |
| Nenhum dispositivo | Iniciar emulador ou conectar Android com depuração USB |
| Entrega pendente | Consultar a issue correspondente; esse módulo ainda está em desenvolvimento |

## 5. Trabalhar e testar

Assuma sua issue, crie branch e siga [o roteiro Git](GIT.md). Widgets usam repositórios, e repositórios usam [os clientes compartilhados](CLIENTES.md). Use [o design system](DESIGN_SYSTEM.md).

```sh
dart format lib test tool
flutter analyze
flutter test
```

Inclua testes relevantes de regras e interações, teste sucesso/erro/vazio e registre no PR qual aparelho e modo usou. Testes unitários usam mocks/fakes, sem acessar o Supabase da turma. Você pode criar novas tasks com critérios de aceite e plano de testes. Merge na main é feito pelo professor.

## IA e skill opcional

O app não depende de ferramentas de IA. Quem usa um agente pode instalar as orientações oficiais com `npx skills add supabase/agent-skills`, escolhendo o agente e o escopo desejados. Leia AGENTS.md e CLAUDE.md: a skill não substitui nossos contratos nem os testes. O professor já instalou as skills oficiais no Codex desta máquina.
