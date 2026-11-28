import 'package:escala_app/data/mensagens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MD1: no mesmo dia, a mensagem é a mesma, a qualquer hora', () {
    final cedo = mensagemDoDia(DateTime(2026, 11, 28, 6, 0));
    final tarde = mensagemDoDia(DateTime(2026, 11, 28, 23, 59));

    expect(tarde.texto, cedo.texto);
  });

  test('MD2: dias seguidos têm mensagens diferentes', () {
    for (var i = 0; i < mensagens.length; i++) {
      final hoje = mensagemDoDia(DateTime(2026, 11, 1 + i));
      final amanha = mensagemDoDia(DateTime(2026, 11, 2 + i));

      expect(amanha.texto, isNot(hoje.texto), reason: 'dia ${1 + i}');
    }
  });

  test(
    'MD3: depois de uma volta completa, repete, inclusive na virada do ano',
    () {
      final n = mensagens.length;
      final inicio = DateTime(2026, 12, 20);
      final depoisDeUmaVolta = DateTime(2026, 12, 20 + n);

      expect(
        mensagemDoDia(depoisDeUmaVolta).texto,
        mensagemDoDia(inicio).texto,
      );
    },
  );

  test(
    'MD4: [guarda] toda mensagem tem texto e fonte, sem textos repetidos',
    () {
      expect(mensagens.length, greaterThanOrEqualTo(2));
      for (final m in mensagens) {
        expect(m.texto.trim(), isNotEmpty);
        expect(m.fonte.trim(), isNotEmpty);
      }
      final textos = mensagens.map((m) => m.texto).toSet();
      expect(textos.length, mensagens.length);
    },
  );
}
