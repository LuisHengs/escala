import '../ordenacao.dart';

/// Uma pessoa cadastrada, como o administrador a vê na gestão de pessoas.
class Pessoa {
  final String id;
  final String nome;

  /// 'admin' ou 'coroinha' (o banco só aceita esses dois).
  final String papel;
  final bool ativo;

  const Pessoa({
    required this.id,
    required this.nome,
    required this.papel,
    required this.ativo,
  });

  bool get administrador => papel == 'admin';

  /// Lê uma linha da tabela `perfis`.
  factory Pessoa.deJson(Map<String, dynamic> json) => Pessoa(
    id: json['id'] as String,
    nome: json['nome'] as String,
    papel: json['papel'] as String,
    ativo: json['ativo'] as bool,
  );

  /// A lista inteira, em ordem alfabética (sem diferenciar maiúsculas).
  static List<Pessoa> listaDeJson(List<dynamic> linhas) =>
      linhas.map((l) => Pessoa.deJson(l as Map<String, dynamic>)).toList()
        ..sort((a, b) => compararNomes(a.nome, b.nome));
}
