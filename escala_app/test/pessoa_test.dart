import 'package:escala_app/data/pessoa.dart';
import 'package:flutter_test/flutter_test.dart';

/// Uma linha da tabela `perfis`, como o Supabase a devolve.
Map<String, dynamic> linha({
  String id = 'p1',
  String nome = 'Ana',
  String papel = 'coroinha',
  bool ativo = true,
}) => {'id': id, 'nome': nome, 'papel': papel, 'ativo': ativo};

void main() {
  test('PS1: lê o id, o nome, o papel e se está ativo', () {
    final p = Pessoa.deJson(linha(papel: 'admin', ativo: false));

    expect(p.id, 'p1');
    expect(p.nome, 'Ana');
    expect(p.papel, 'admin');
    expect(p.ativo, isFalse);
  });

  test('PS2: só o papel "admin" conta como administrador', () {
    expect(Pessoa.deJson(linha(papel: 'admin')).administrador, isTrue);
    expect(Pessoa.deJson(linha(papel: 'coroinha')).administrador, isFalse);
  });

  test('PS3: a lista vem em ordem alfabética, sem diferenciar maiúsculas', () {
    final lista = Pessoa.listaDeJson([
      linha(id: 'c', nome: 'caio'),
      linha(id: 'a', nome: 'Ana'),
      linha(id: 'b', nome: 'Bia'),
    ]);

    expect(lista.map((p) => p.id), ['a', 'b', 'c']);
  });

  test('PS4: lista vazia dá lista vazia', () {
    expect(Pessoa.listaDeJson([]), isEmpty);
  });

  test('PS5: a ordem ignora os acentos', () {
    final lista = Pessoa.listaDeJson([
      linha(id: 'z', nome: 'Zeca'),
      linha(id: 'e', nome: 'Érica'),
      linha(id: 'd', nome: 'Davi'),
    ]);

    expect(lista.map((p) => p.id), ['d', 'e', 'z']);
  });
}
