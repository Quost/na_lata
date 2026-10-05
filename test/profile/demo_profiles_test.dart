import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/data/clients/app_failure.dart';
import 'package:na_lata/data/demo_profiles.dart';
import 'package:na_lata/features/profile/profile_models.dart';

void main() {
  late DemoProfileStore store;
  late DemoProfileRepository a, b;

  setUp(() {
    store = DemoProfileStore();
    a = DemoProfileRepository(userId: 'a', store: store);
    b = DemoProfileRepository(userId: 'b', store: store);
  });

  test('perfil nasce com apelido padrão e sem bio', () async {
    final mine = await a.mine();
    expect(mine.id, 'a');
    expect(mine.nickname, 'Colega');
    expect(mine.bio, isNull);
  });

  test('perfil inexistente é null, não erro', () async {
    expect(await a.byId('ninguem'), isNull);
  });

  test('A edita o próprio perfil e B lê o resultado', () async {
    final saved = await a.updateMine(
      const ProfileDraft(nickname: ' Ana ', bio: ' Gosto de café '),
    );
    expect(saved.nickname, 'Ana');

    final seenByB = await b.byId('a');
    expect(seenByB!.nickname, 'Ana');
    expect(seenByB.bio, 'Gosto de café');
  });

  test('edição de B não altera o perfil de A', () async {
    await a.updateMine(const ProfileDraft(nickname: 'Ana', bio: 'Bio de A'));
    await b.updateMine(const ProfileDraft(nickname: 'Bia', bio: 'Bio de B'));

    final profileA = await a.mine();
    expect(profileA.nickname, 'Ana');
    expect(profileA.bio, 'Bio de A');
    expect((await b.mine()).id, 'b');
  });

  test('bio vazia apaga a bio e mantém o apelido', () async {
    await a.updateMine(const ProfileDraft(nickname: 'Ana', bio: 'Bio'));
    final cleared = await a.updateMine(
      const ProfileDraft(nickname: 'Ana', bio: '  '),
    );
    expect(cleared.nickname, 'Ana');
    expect(cleared.bio, isNull);
  });

  test('rascunho inválido não altera o perfil salvo', () async {
    await a.updateMine(const ProfileDraft(nickname: 'Ana', bio: 'Bio'));
    await expectLater(
      a.updateMine(const ProfileDraft(nickname: 'a', bio: 'Outra')),
      throwsA(
        isA<AppFailure>().having((e) => e.kind, 'kind', FailureKind.validation),
      ),
    );
    final mine = await a.mine();
    expect(mine.nickname, 'Ana');
    expect(mine.bio, 'Bio');
  });
}
