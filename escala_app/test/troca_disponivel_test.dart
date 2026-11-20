import 'package:escala_app/data/troca_disponivel.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma linha como o Supabase a devolve: a troca com a escalação, quem é o
/// titular e a missa embutidos.
Map<String, dynamic> linha({
  String id = 't1',
  String coroinhaId = 'u-ana',
  String nome = 'Ana',
  String inicio = '2026-11-22T21:00:00+00:00',
}) => {
  'id': id,
  'escalacoes': {
    'funcao': 'turiferário',
    'coroinha_id': coroinhaId,
    'perfis': {'nome': nome},
    'missas': {
      'inicio': inicio,
      'locais': {'nome': 'Matriz'},
    },
  },
};

void main() {
  // "Agora" bem antes das missas dos exemplos.
  final agora = DateTime.utc(2026, 11, 20, 12);

  List<TrocaDisponivel> ler(
    List<Map<String, dynamic>> linhas, {
    String meuId = 'u-eu',
    DateTime? quando,
  }) =>
      TrocaDisponivel.listaDeJson(linhas, meuId: meuId, agora: quando ?? agora);

  test(
    'TD1: lê a troca, o local, a função, o nome de quem pediu e o horário',
    () {
      final troca = ler([linha()]).single;

      expect(troca.trocaId, 't1');
      expect(troca.local, 'Matriz');
      expect(troca.funcao, 'turiferário');
      expect(troca.titularNome, 'Ana');
      expect(
        troca.inicio.isAtSameMomentAs(DateTime.utc(2026, 11, 22, 21)),
        isTrue,
      );
    },
  );

  test('TD2: não inclui os pedidos de troca da própria pessoa', () {
    final lista = ler([
      linha(id: 'minha', coroinhaId: 'u-eu'),
      linha(id: 'dela', coroinhaId: 'u-ana'),
    ], meuId: 'u-eu');

    expect(lista.map((t) => t.trocaId), ['dela']);
  });

  test(
    'TD3: não inclui missas que já começaram (o instante exato já conta)',
    () {
      final inicio = '2026-11-22T21:00:00+00:00';

      // Um segundo antes do início: ainda dá para aceitar.
      expect(
        ler([
          linha(inicio: inicio),
        ], quando: DateTime.utc(2026, 11, 22, 20, 59, 59)),
        hasLength(1),
      );
      // No instante exato do início: a missa começou.
      expect(
        ler([linha(inicio: inicio)], quando: DateTime.utc(2026, 11, 22, 21)),
        isEmpty,
      );
      // Depois: também não.
      expect(
        ler([linha(inicio: inicio)], quando: DateTime.utc(2026, 11, 22, 22)),
        isEmpty,
      );
    },
  );

  test('TD4: a lista vem ordenada pelo horário da missa', () {
    final lista = ler([
      linha(id: 'tarde', inicio: '2026-11-29T21:00:00+00:00'),
      linha(id: 'cedo', inicio: '2026-11-22T21:00:00+00:00'),
      linha(id: 'meio', inicio: '2026-11-25T21:00:00+00:00'),
    ]);

    expect(lista.map((t) => t.trocaId), ['cedo', 'meio', 'tarde']);
  });

  test('TD5: lista vazia dá lista vazia', () {
    expect(ler([]), isEmpty);
  });
}
