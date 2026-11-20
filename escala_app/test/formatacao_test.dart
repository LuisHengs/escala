import 'package:escala_app/formatacao.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F1: dia da semana, dia/mês e hora', () {
    expect(
      formatarDataMissa(DateTime(2026, 11, 22, 18, 0)),
      'dom 22/11 às 18:00',
    );
  });

  test('F2: completa com zero à esquerda (dia, mês, hora e minuto)', () {
    expect(
      formatarDataMissa(DateTime(2026, 12, 5, 7, 5)),
      'sáb 05/12 às 07:05',
    );
  });

  test('F3: os sete dias da semana', () {
    // 23/11/2026 é segunda-feira.
    final dias = List.generate(
      7,
      (i) =>
          formatarDataMissa(DateTime(2026, 11, 23 + i, 9, 0)).substring(0, 3),
    );
    expect(dias, ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom']);
  });
}
