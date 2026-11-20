import 'package:escala_app/data/item_escala.dart';
import 'package:escala_core/escala_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma linha como o Supabase a devolve (escalação com a missa, o local e as
/// trocas embutidos).
Map<String, dynamic> linha({
  String id = 'e1',
  String status = 'pendente',
  bool atraso = false,
  String inicio = '2026-11-22T21:00:00+00:00',
  List<Map<String, dynamic>> trocas = const [],
}) => {
  'id': id,
  'funcao': 'turiferário',
  'status': status,
  'confirmado_com_atraso': atraso,
  'missas': {
    'inicio': inicio,
    'locais': {'nome': 'Matriz'},
  },
  'trocas': trocas,
};

void main() {
  test('M1: lê os campos da escalação, da missa e do local', () {
    final item = ItemEscala.deJson(linha());

    expect(item.escalacaoId, 'e1');
    expect(item.funcao, 'turiferário');
    expect(item.local, 'Matriz');
    expect(item.status, StatusPresenca.pendente);
    expect(item.confirmadoComAtraso, isFalse);
    // O instante é o mesmo, qualquer que seja o fuso do aparelho.
    expect(
      item.inicio.isAtSameMomentAs(DateTime.utc(2026, 11, 22, 21)),
      isTrue,
    );
  });

  test('M2: status confirmado, com a marca de atraso', () {
    final item = ItemEscala.deJson(linha(status: 'confirmado', atraso: true));

    expect(item.status, StatusPresenca.confirmado);
    expect(item.confirmadoComAtraso, isTrue);
  });

  test('M3: só uma troca ABERTA conta como troca aberta', () {
    expect(ItemEscala.deJson(linha()).trocaAberta, isFalse);

    expect(
      ItemEscala.deJson(
        linha(
          trocas: [
            {'id': 't1', 'status': 'aberta'},
          ],
        ),
      ).trocaAberta,
      isTrue,
    );

    expect(
      ItemEscala.deJson(
        linha(
          trocas: [
            {'id': 't1', 'status': 'cancelada'},
            {'id': 't2', 'status': 'aceita'},
          ],
        ),
      ).trocaAberta,
      isFalse,
    );
  });

  test('M8: guarda o id da troca aberta (e é nulo quando não há)', () {
    expect(ItemEscala.deJson(linha()).trocaAbertaId, isNull);

    final item = ItemEscala.deJson(
      linha(
        trocas: [
          {'id': 't1', 'status': 'cancelada'},
          {'id': 't2', 'status': 'aberta'},
        ],
      ),
    );
    expect(item.trocaAbertaId, 't2');
  });

  test('M4: status desconhecido é um erro (nunca mostra um valor errado)', () {
    expect(
      () => ItemEscala.deJson(linha(status: 'sumido')),
      throwsFormatException,
    );
  });

  test('M5: a lista vem ordenada pelo horário da missa', () {
    final itens = ItemEscala.listaDeJson([
      linha(id: 'tarde', inicio: '2026-11-29T21:00:00+00:00'),
      linha(id: 'cedo', inicio: '2026-11-22T21:00:00+00:00'),
      linha(id: 'meio', inicio: '2026-11-25T21:00:00+00:00'),
    ]);

    expect(itens.map((i) => i.escalacaoId), ['cedo', 'meio', 'tarde']);
  });

  test('M6: lista vazia dá lista vazia', () {
    expect(ItemEscala.listaDeJson([]), isEmpty);
  });

  test('M7: o prazo para confirmar é 2h antes da missa', () {
    final item = ItemEscala(
      escalacaoId: 'e1',
      inicio: DateTime(2026, 11, 22, 18, 0),
      local: 'Matriz',
      funcao: 'turiferário',
      status: StatusPresenca.pendente,
    );

    expect(item.limiteParaConfirmar, DateTime(2026, 11, 22, 16, 0));
  });
}
