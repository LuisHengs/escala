import 'dominio.dart';

// Exceções dos códigos do banco que ainda não tinham classe no dominio.dart.
// Os códigos vêm das funções SQL (raise exception 'CODIGO').

// ---------- Escalar ----------

class CoroinhaInexistente extends RegraDeNegocio {
  const CoroinhaInexistente(super.mensagem);
}

class CoroinhaInativo extends RegraDeNegocio {
  const CoroinhaInativo(super.mensagem);
}

class MissaInexistente extends RegraDeNegocio {
  const MissaInexistente(super.mensagem);
}

// ---------- Convites ----------

class ConviteInvalido extends RegraDeNegocio {
  const ConviteInvalido(super.mensagem);
}

class ConviteUsado extends RegraDeNegocio {
  const ConviteUsado(super.mensagem);
}

class ConviteExpirado extends RegraDeNegocio {
  const ConviteExpirado(super.mensagem);
}

class JaTemPerfil extends RegraDeNegocio {
  const JaTemPerfil(super.mensagem);
}

class NomeInvalido extends RegraDeNegocio {
  const NomeInvalido(super.mensagem);
}

class ResponsavelObrigatorio extends RegraDeNegocio {
  const ResponsavelObrigatorio(super.mensagem);
}

// ---------- Cadastro de locais e missas ----------

class LocalDuplicado extends RegraDeNegocio {
  const LocalDuplicado(super.mensagem);
}

class HorarioInvalido extends RegraDeNegocio {
  const HorarioInvalido(super.mensagem);
}

class LocalInexistente extends RegraDeNegocio {
  const LocalInexistente(super.mensagem);
}

// ---------- Gestão de membros e da escala ----------

class ValorInvalido extends RegraDeNegocio {
  const ValorInvalido(super.mensagem);
}

class PerfilInexistente extends RegraDeNegocio {
  const PerfilInexistente(super.mensagem);
}

class PapelInvalido extends RegraDeNegocio {
  const PapelInvalido(super.mensagem);
}

class TemEscalacoesFuturas extends RegraDeNegocio {
  const TemEscalacoesFuturas(super.mensagem);
}

class MissaComEscalados extends RegraDeNegocio {
  const MissaComEscalados(super.mensagem);
}

class UltimoAdmin extends RegraDeNegocio {
  const UltimoAdmin(super.mensagem);
}

// ---------- O que o app não sabe traduzir ----------

/// Erro que o app não sabe traduzir (código novo no banco, falha técnica do
/// Postgres, rede...). Guarda o código original só para registro: o texto
/// cru NÃO deve ser mostrado ao usuário.
class ErroDesconhecido extends RegraDeNegocio {
  final String codigo;

  ErroDesconhecido(this.codigo) : super('Erro inesperado.');
}

// ---------- A tradução ----------

/// Traduz o código devolvido pelo banco (o texto da exceção) numa exceção do
/// domínio. Qualquer coisa fora da lista vira [ErroDesconhecido], e nunca
/// lança exceção: o app sempre recebe um objeto para tratar.
///
/// As mensagens são o padrão do domínio; a tela pode trocá-las por textos
/// próprios. O teste de contrato (traducao_erros_test.dart) lê as migrations
/// e falha se o banco ganhar um código que não esteja nesta lista.
RegraDeNegocio traduzirErroDoBanco(String codigo) {
  final c = codigo.trim();
  return switch (c) {
    // Escala e trocas
    'NAO_AUTORIZADO' =>
      const PermissaoNegada('Você não tem permissão para fazer isso.'),
    'CONFLITO_DE_HORARIO' => const ConflitoDeHorario(
        'Esse coroinha já está escalado em uma missa com horário próximo.'),
    'JA_ESCALADO_NA_MISSA' =>
      const JaEscaladoNaMissa('Esse coroinha já está escalado nesta missa.'),
    'MISSA_JA_COMECOU' => const MissaJaComecou('Esta missa já começou.'),
    'TROCA_JA_RESOLVIDA' =>
      const TrocaJaResolvida('Esta troca não está mais aberta.'),
    'SUBSTITUTO_INVALIDO' =>
      const SubstitutoInvalido('Você não pode aceitar a própria troca.'),
    'TROCA_JA_ABERTA' =>
      const TrocaJaAberta('Já existe uma troca aberta para esta escalação.'),
    'ESCALACAO_NAO_ENCONTRADA' =>
      const EscalacaoNaoEncontrada('Escalação não encontrada.'),
    'TROCA_NAO_ENCONTRADA' => const TrocaNaoEncontrada('Troca não encontrada.'),
    // Validações ao escalar
    'COROINHA_INEXISTENTE' =>
      const CoroinhaInexistente('Esse coroinha não existe.'),
    'COROINHA_INATIVO' => const CoroinhaInativo(
        'Esse coroinha está inativo e não pode ser escalado.'),
    'MISSA_INEXISTENTE' => const MissaInexistente('Missa não encontrada.'),
    // Convites
    'CONVITE_INVALIDO' => const ConviteInvalido('Código de convite inválido.'),
    'CONVITE_USADO' => const ConviteUsado('Este convite já foi usado.'),
    'CONVITE_EXPIRADO' => const ConviteExpirado('Este convite venceu.'),
    'JA_TEM_PERFIL' => const JaTemPerfil('Você já tem cadastro.'),
    'NOME_INVALIDO' => const NomeInvalido('Informe um nome.'),
    'RESPONSAVEL_OBRIGATORIO' =>
      const ResponsavelObrigatorio('Informe o nome do responsável.'),
    // Cadastro de locais e missas
    'LOCAL_DUPLICADO' =>
      const LocalDuplicado('Já existe um local com esse nome.'),
    'HORARIO_INVALIDO' => const HorarioInvalido('Informe um horário válido.'),
    'LOCAL_INEXISTENTE' => const LocalInexistente('Local não encontrado.'),
    // Gestão de membros e da escala
    'VALOR_INVALIDO' => const ValorInvalido('Valor inválido.'),
    'PERFIL_INEXISTENTE' => const PerfilInexistente('Cadastro não encontrado.'),
    'PAPEL_INVALIDO' => const PapelInvalido('Papel inválido.'),
    'TEM_ESCALACOES_FUTURAS' => const TemEscalacoesFuturas(
        'Essa pessoa tem missas futuras. Retire-a da escala antes.'),
    'MISSA_COM_ESCALADOS' => const MissaComEscalados(
        'Esta missa tem coroinhas escalados. Retire-os antes de removê-la.'),
    'ULTIMO_ADMIN' => const UltimoAdmin(
        'O sistema precisa de pelo menos um administrador ativo.'),
    // Qualquer outra coisa
    _ => ErroDesconhecido(c),
  };
}
