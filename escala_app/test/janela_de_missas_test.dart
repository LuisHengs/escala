import 'package:escala_app/data/janela_de_missas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('JM1: uma missa dura 1h30 para efeito das listas', () {
    expect(duracaoDaMissa, const Duration(hours: 1, minutes: 30));
  });

  test('JM2: a janela das listas começa 1h30 antes de agora', () {
    final agora = DateTime(2026, 11, 22, 19, 45);

    expect(inicioDaJanela(agora), DateTime(2026, 11, 22, 18, 15));
  });

  test('JM3: o calendário começa no dia de hoje, à meia-noite', () {
    final agora = DateTime(2026, 11, 22, 15, 40);

    expect(primeiroDiaParaEscolher(agora), DateTime(2026, 11, 22));
  });
}
