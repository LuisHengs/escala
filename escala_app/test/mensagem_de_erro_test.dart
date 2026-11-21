import 'package:escala_app/mensagem_de_erro.dart';
import 'package:escala_core/escala_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ME1: erro de regra mostra a mensagem do próprio erro', () {
    expect(
      mensagemDoErro(const MissaJaComecou('Esta missa já começou.')),
      'Esta missa já começou.',
    );
  });

  test('ME2: qualquer outro erro vira o texto genérico', () {
    const generico = 'Algo deu errado. Tente de novo.';

    expect(mensagemDoErro(Exception('sem rede')), generico);
    expect(mensagemDoErro(StateError('falha técnica')), generico);
    expect(mensagemDoErro('um texto solto'), generico);
  });

  test('ME3: o texto técnico do erro nunca aparece', () {
    final texto = mensagemDoErro(Exception('connection refused 10.0.0.1'));

    expect(texto, isNot(contains('connection')));
    expect(texto, isNot(contains('10.0.0.1')));
  });
}
