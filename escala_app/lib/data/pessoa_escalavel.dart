import '../ordenacao.dart';

/// Um coroinha ativo que pode ser incluído em uma escala.
class PessoaEscalavel {
  final String id;
  final String nome;

  const PessoaEscalavel({required this.id, required this.nome});

  factory PessoaEscalavel.deJson(Map<String, dynamic> json) =>
      PessoaEscalavel(id: json['id'] as String, nome: json['nome'] as String);

  /// Lista em ordem alfabética, sem diferenciar maiúsculas.
  static List<PessoaEscalavel> listaDeJson(List<dynamic> linhas) =>
      linhas
          .map((l) => PessoaEscalavel.deJson(l as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => compararNomes(a.nome, b.nome));
}
