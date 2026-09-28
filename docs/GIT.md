# Uma issue, uma branch, um PR

## Começar

Atribua a issue a você no GitHub. Copie o **número real da issue**, não o identificador pedagógico T01.

```sh
git switch main
git pull --ff-only origin main
git switch -c feat/NUMERO-descricao-curta
flutter pub get
```

Leia sua pasta e os contratos. Entregue o menor comportamento completo da issue. Não atualize versões nem formate arquivos dos colegas sem necessidade.

## Publicar

```sh
dart format lib/features/SUA_PASTA test
flutter analyze
flutter test
git status
git add CAMINHO_DO_ARQUIVO
# Repita git add para os arquivos da entrega.
git commit -m "feat: descreva o comportamento entregue"
git push -u origin HEAD
```

No GitHub, abra PR para main. Preencha template, `Closes #NUMERO`, cenário de teste e screenshot/vídeo. Solicite revisão de um colega. Screenshot sozinho não substitui testar.

## Revisar de verdade

```sh
git status
# Termine/guarde seu trabalho antes de trocar de branch.
git fetch origin
git switch --track origin/BRANCH_DO_COLEGA
flutter pub get
flutter run
```

Se essa branch já existir localmente, use `git switch BRANCH_DO_COLEGA`. Execute os critérios da issue e um caso de erro. Faça comentário específico; peça ajustes se não funcionar. Aprove somente depois de verificar. O professor coordena squash merge. Ninguém aprova o próprio PR.

## Atualizar e resolver conflito

Na sua branch, com trabalho commitado:

```sh
git fetch origin
git merge origin/main
```

Se houver conflito, leia as duas alterações e converse com o colega. Preserve os dois comportamentos; retire marcadores, teste, faça git add dos arquivos resolvidos, `git commit` e `git push`. Não use “accept all” sem ler. `git merge --abort` cancela uma tentativa se necessário. Não usar force push.

Depois do merge:

```sh
git switch main
git pull --ff-only origin main
# -D é necessário se squash merge impede -d; só faça após confirmar merge no GitHub.
git branch -d feat/NUMERO-descricao-curta
```

Se o comando recusar, pode deixar a branch local e seguir a aula; não precisa apagá-la para continuar.
