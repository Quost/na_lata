import 'package:flutter_test/flutter_test.dart';
import 'package:na_lata/features/nickname/nickname_feature.dart';

void main() {
  test('vazio e só espaços → empty', () {
    expect(validateNickname('')?.error, NicknameError.empty);
    expect(validateNickname('   ').error, NicknameError.empty);
    expect(validateNickname(null).error, NicknameError.empty);
  });

  test('1 caractere (após trim) → tooShort', () {
    expect(validateNickname(' a ').error, NicknameError.tooShort);
  });

  test('limites 2 e 40 são válidos e vêm com trim', () {
    expect(validateNickname(' ab ').value, 'ab');
    expect(validateNickname('a' * 40).isValid, isTrue);
  });

  test('41 caracteres → tooLong', () {
    expect(validateNickname('a' * 41).error, NicknameError.tooLong);
  });

  test('emoji conta como 1 caractere', () {
    expect(validateNickname('😀😀').isValid, isTrue);
    expect(validateNickname('😀').error, NicknameError.tooShort);
  });
}