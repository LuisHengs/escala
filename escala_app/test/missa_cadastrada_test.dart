import 'package:escala_app/data/missa_cadastrada.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma linha como o Supabase a devolve (a missa com o nome do local embutido).
Map<String, dynamic> linha({
  String id = 'm1',
  String inicio = '2026-11-22T21:00:00+00:00',
  String localId = 'l1',
  String local = 'Matriz',
}) => {
  'id': id,
  'inicio': inicio,
  'local_id': localId,
  'locais': {'nome': local},
};

void main() {
  test('MC1: lê o id, o horário, o id do local e o nome do local', () {
    final missa = MissaCadastrada.deJson(linha());

    expect(missa.id, 'm1');
    expect(missa.localId, 'l1');
    expect(missa.localNome, 'Matriz');
    // O instante é o mesmo, qualquer que seja o fuso do aparelho.
    expect(
      missa.inicio.isAtSameMomentAs(DateTime.utc(2026, 11, 22, 21)),
      isTrue,
    );
  });

  test('MC2: a lista vem ordenada pelo horário', () {
    final missas = MissaCadastrada.listaDeJson([
      linha(id: 'tarde', inicio: '2026-11-29T21:00:00+00:00'),
      linha(id: 'cedo', inicio: '2026-11-22T21:00:00+00:00'),
      linha(id: 'meio', inicio: '2026-11-25T21:00:00+00:00'),
    ]);

    expect(missas.map((m) => m.id), ['cedo', 'meio', 'tarde']);
  });

  test('MC3: lista vazia dá lista vazia', () {
    expect(MissaCadastrada.listaDeJson([]), isEmpty);
  });
}
