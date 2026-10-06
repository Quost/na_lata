import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/data/demo_follow_repository.dart';

void main() {
  group('DemoFollowRepository', () {
    test('começa sem seguir ninguém', () async {
      final repo = DemoFollowRepository('user-1');
      expect(await repo.following(), isEmpty);
    });

    test('permite seguir e listar', () async {
      final repo = DemoFollowRepository('user-1');
      await repo.follow('user-2');
      await repo.follow('user-3');

      final following = await repo.following();
      expect(following, containsAll(['user-2', 'user-3']));
      expect(following.length, 2);
    });

    test('seguir é idempotente', () async {
      final repo = DemoFollowRepository('user-1');
      await repo.follow('user-2');
      await repo.follow('user-2'); // Duplicado

      final following = await repo.following();
      expect(following, ['user-2']);
    });

    test('não permite seguir a si mesmo', () async {
      final repo = DemoFollowRepository('user-1');

      expect(() => repo.follow('user-1'), throwsA(isA<StateError>()));
    });

    test('permite deixar de seguir', () async {
      final repo = DemoFollowRepository('user-1');
      await repo.follow('user-2');
      await repo.follow('user-3');

      await repo.unfollow('user-2');

      final following = await repo.following();
      expect(following, ['user-3']);
    });

    test('deixar de seguir é idempotente (não quebra se não seguia)', () async {
      final repo = DemoFollowRepository('user-1');
      await repo.follow('user-2');

      await repo.unfollow('user-3'); // Não estava seguindo

      final following = await repo.following();
      expect(following, ['user-2']);
    });
  });
}
