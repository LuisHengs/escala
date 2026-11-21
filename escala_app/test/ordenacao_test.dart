import 'package:escala_app/ordenacao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OR1: letras com acento ordenam como a letra sem acento', () {
    final nomes = ['Zeca', 'Érica', 'Davi', 'Ágata', 'Fábio']
      ..sort(compararNomes);

    expect(nomes, ['Ágata', 'Davi', 'Érica', 'Fábio', 'Zeca']);
  });

  test('OR2: não diferencia maiúsculas', () {
    final nomes = ['bia', 'Ana', 'CAIO']..sort(compararNomes);

    expect(nomes, ['Ana', 'bia', 'CAIO']);
  });

  test('OR3: cedilha e til também são ignorados', () {
    final nomes = ['Dora', 'Conceição', 'Cássia', 'João', 'Joana']
      ..sort(compararNomes);

    expect(nomes, ['Cássia', 'Conceição', 'Dora', 'Joana', 'João']);
  });

  test('OR4: o mesmo nome sem acento vem antes do com acento', () {
    final nomes = ['José', 'Jose']..sort(compararNomes);

    expect(nomes, ['Jose', 'José']);
  });

  test('OR5: nomes iguais dão zero', () {
    expect(compararNomes('Ana', 'Ana'), 0);
  });
}
