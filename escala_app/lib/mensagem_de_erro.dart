import 'package:escala_core/escala_core.dart';

/// O texto mostrado quando o erro não é uma regra de negócio (rede, falha
/// técnica). Nunca se mostra o texto técnico à pessoa.
const mensagemGenerica = 'Algo deu errado. Tente de novo.';

/// A mensagem para a pessoa: a do próprio erro se for uma regra de negócio;
/// qualquer outra coisa vira o texto genérico.
String mensagemDoErro(Object erro) =>
    erro is RegraDeNegocio ? erro.mensagem : mensagemGenerica;
