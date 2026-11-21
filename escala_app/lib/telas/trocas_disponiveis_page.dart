import 'package:escala_core/escala_core.dart';
import 'package:flutter/material.dart';

import '../data/escala_repository.dart';
import '../data/troca_disponivel.dart';
import '../formatacao.dart';
import '../mensagem_de_erro.dart';

/// Os pedidos de troca de outras pessoas, com o botão de aceitar.
class TrocasDisponiveisPage extends StatefulWidget {
  final EscalaRepository repositorio;

  const TrocasDisponiveisPage({super.key, required this.repositorio});

  @override
  State<TrocasDisponiveisPage> createState() => _TrocasDisponiveisPageState();
}

class _TrocasDisponiveisPageState extends State<TrocasDisponiveisPage> {
  late Future<List<TrocaDisponivel>> _trocas = widget.repositorio
      .trocasDisponiveis();

  // Trocas com um aceite em andamento (o botão fica bloqueado).
  final _ocupadas = <String>{};

  void _recarregar() {
    final futuro = widget.repositorio.trocasDisponiveis();
    // O erro aparece na própria tela, pelo FutureBuilder. Sem o ignore(), uma
    // falha que chega ANTES de a tela começar a ouvir seria tratada como erro
    // não capturado. O FutureBuilder continua recebendo o erro normalmente.
    futuro.ignore();
    // Bloco, e não "=>": a seta devolveria o Future atribuído, e o
    // setState exige um callback que não devolva Future.
    setState(() {
      _trocas = futuro;
    });
  }

  Future<void> _puxarParaAtualizar() async {
    _recarregar();
    try {
      await _trocas;
    } on Object catch (_) {
      // O erro aparece na própria tela, pelo FutureBuilder.
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// As mensagens do domínio são escritas em geral ("Esse coroinha já está
  /// escalado..."). Aqui quem fala é a pessoa que aceita, então a tela troca
  /// por "você".
  String _mensagemDoErro(Object erro) => switch (erro) {
    ConflitoDeHorario() =>
      'Você já está escalado em uma missa com horário próximo.',
    JaEscaladoNaMissa() => 'Você já está escalado nesta missa.',
    TrocaJaResolvida() =>
      'Esta troca já foi aceita por outra pessoa ou foi cancelada.',
    MissaJaComecou() => 'Esta missa já começou.',
    RegraDeNegocio(:final mensagem) => mensagem,
    _ => mensagemGenerica,
  };

  Future<void> _aceitar(TrocaDisponivel troca) async {
    // Aceitar é um compromisso (e já confirma a presença): antes, um aviso.
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Aceitar esta vaga?'),
        content: Text(
          'Você assumirá a vaga de ${troca.titularNome} em '
          '${formatarDataMissa(troca.inicio)} (${troca.local}). '
          'A sua presença já ficará confirmada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Sim, aceitar'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _ocupadas.add(troca.trocaId));
    var recarregar = false;
    try {
      await widget.repositorio.aceitarTroca(troca.trocaId);
      recarregar = true;
      if (mounted) _avisar('Troca aceita! A missa entrou na sua escala.');
    } on Object catch (e) {
      // Se a troca mudou enquanto a pessoa olhava, a lista está velha.
      recarregar =
          e is TrocaJaResolvida ||
          e is MissaJaComecou ||
          e is TrocaNaoEncontrada;
      if (mounted) _avisar(_mensagemDoErro(e));
    } finally {
      if (mounted) setState(() => _ocupadas.remove(troca.trocaId));
    }
    // Recarregar fica FORA do try: uma falha dele não é "falha do aceite".
    if (recarregar && mounted) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trocas abertas')),
      body: FutureBuilder<List<TrocaDisponivel>>(
        future: _trocas,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar as trocas.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _recarregar,
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            );
          }

          final trocas = snapshot.requireData;
          if (trocas.isEmpty) {
            return const Center(
              child: Text('Nenhuma troca aberta no momento.'),
            );
          }
          return RefreshIndicator(
            onRefresh: _puxarParaAtualizar,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: trocas.length,
              itemBuilder: (context, i) => _cartao(context, trocas[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _cartao(BuildContext context, TrocaDisponivel troca) {
    final estilos = Theme.of(context).textTheme;
    final ocupada = _ocupadas.contains(troca.trocaId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatarDataMissa(troca.inicio), style: estilos.titleMedium),
            const SizedBox(height: 4),
            Text('${troca.local} · ${troca.funcao}'),
            const SizedBox(height: 4),
            Text('Pedido de ${troca.titularNome}', style: estilos.bodySmall),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: ocupada ? null : () => _aceitar(troca),
              child: const Text('Aceitar'),
            ),
          ],
        ),
      ),
    );
  }
}
