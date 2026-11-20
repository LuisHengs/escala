import 'package:escala_app/data/escalado_na_missa.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> linha({
  String id = 'e1',
  String coroinhaId = 'c1',
  String nome = 'Ana',
  String funcao = 'turiferário',
}) => {
  'id': id,
  'coroinha_id': coroinhaId,
  'funcao': funcao,
  'perfis': {'nome': nome},
};

void main() {
  test('EM1: lê os dados da escalação', () {
    final escalado = EscaladoNaMissa.deJson(linha());

    expect(escalado.id, 'e1');
    expect(escalado.coroinhaId, 'c1');
    expect(escalado.nome, 'Ana');
    expect(escalado.funcao, 'turiferário');
  });

  test('EM2: ordena pelo nome sem diferenciar maiúsculas', () {
    final escalados = EscaladoNaMissa.listaDeJson([
      linha(id: '2', nome: 'bruno'),
      linha(id: '1', nome: 'Ana'),
    ]);

    expect(escalados.map((e) => e.id), ['1', '2']);
  });

  test('EM3: lista vazia retorna lista vazia', () {
    expect(EscaladoNaMissa.listaDeJson([]), isEmpty);
  });
}
