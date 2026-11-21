import 'package:escala_app/data/local.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LC1: lê o id e o nome de uma linha do Supabase', () {
    final local = Local.deJson({'id': 'l1', 'nome': 'Matriz'});

    expect(local.id, 'l1');
    expect(local.nome, 'Matriz');
  });

  test('LC2: a lista vem em ordem alfabética, sem diferenciar maiúsculas', () {
    final locais = Local.listaDeJson([
      {'id': 'a', 'nome': 'matriz'},
      {'id': 'b', 'nome': 'Capela'},
      {'id': 'c', 'nome': 'Anexo'},
    ]);

    expect(locais.map((l) => l.nome), ['Anexo', 'Capela', 'matriz']);
  });

  test('LC3: lista vazia dá lista vazia', () {
    expect(Local.listaDeJson([]), isEmpty);
  });

  test('LC4: a ordem ignora os acentos', () {
    final locais = Local.listaDeJson([
      {'id': 'a', 'nome': 'Zeta'},
      {'id': 'b', 'nome': 'Ágape'},
      {'id': 'c', 'nome': 'Capela'},
    ]);

    expect(locais.map((l) => l.nome), ['Ágape', 'Capela', 'Zeta']);
  });
}
