import 'package:escala_core/escala_core.dart';
import 'package:material_ui/material_ui.dart';

import '../data/escala_repository.dart';
import '../data/item_escala.dart';
import '../formatacao.dart';
import 'admin_page.dart';
import 'trocas_disponiveis_page.dart';
import 'missas_abertas_page.dart';
import '../mensagem_de_erro.dart';

/// As próximas missas de quem está logado, com a situação da presença, o
/// botão de confirmar e o pedido de troca.
class MinhaEscalaPage extends StatefulWidget {
  final EscalaRepository repositorio;

  /// A hora atual entra por parâmetro para os testes controlarem o prazo.
  final DateTime Function() agora;

  /// Quem é administrador vê o botão da área de administração. O app só
  /// esconde o botão: quem protege as funções de verdade é o banco.
  final bool administrador;

  const MinhaEscalaPage({
    super.key,
    required this.repositorio,
    this.agora = DateTime.now,
    this.administrador = false,
  });

  @override
  State<MinhaEscalaPage> createState() => _MinhaEscalaPageState();
}

class _MinhaEscalaPageState extends State<MinhaEscalaPage> {
  late Future<List<ItemEscala>> _escala = widget.repositorio.minhaEscala();

  // Escalações com uma ação em andamento (os botões ficam bloqueados).
  final _ocupadas = <String>{};

  void _recarregar() {
    final futuro = widget.repositorio.minhaEscala();
    // O erro aparece na própria tela, pelo FutureBuilder. Sem o ignore(), uma
    // falha que chega ANTES de a tela começar a ouvir seria tratada como erro
    // não capturado. O FutureBuilder continua recebendo o erro normalmente.
    futuro.ignore();
    // Bloco, e não "=>": a seta devolveria o Future atribuído, e o
    // setState exige um callback que não devolva Future.
    setState(() {
      _escala = futuro;
    });
  }

  Future<void> _puxarParaAtualizar() async {
    _recarregar();
    try {
      await _escala;
    } on Object catch (_) {
      // O erro aparece na própria tela, pelo FutureBuilder.
    }
  }

  /// Roda uma ação do repositório para uma escalação: bloqueia os botões
  /// enquanto espera, mostra a mensagem se der erro de regra e, só se a ação
  /// deu certo, recarrega a lista. O recarregamento fica FORA do try: uma
  /// falha dele não pode ser mostrada como "falha da ação".
  Future<void> _executar(
    String escalacaoId,
    Future<void> Function() acao,
  ) async {
    setState(() => _ocupadas.add(escalacaoId));
    var deuCerto = false;
    try {
      await acao();
      deuCerto = true;
    } on Object catch (e) {
      if (mounted) {
        // Erros de regra têm mensagem própria; o resto vira um texto genérico.
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(mensagemDoErro(e))));
      }
    } finally {
      if (mounted) setState(() => _ocupadas.remove(escalacaoId));
    }
    if (deuCerto && mounted) _recarregar();
  }

  Future<void> _confirmar(ItemEscala item) => _executar(
    item.escalacaoId,
    () => widget.repositorio.confirmarPresenca(item.escalacaoId),
  );

  Future<void> _pedirTroca(ItemEscala item) async {
    // O pedido aparece para todos os coroinhas: antes, uma confirmação.
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Pedir troca?'),
        content: const Text(
          'Todos os coroinhas poderão ver o pedido e aceitar a sua vaga.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Sim, pedir troca'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    await _executar(
      item.escalacaoId,
      () => widget.repositorio.abrirTroca(item.escalacaoId),
    );
  }

  Future<void> _sairDaEscala(ItemEscala item) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (contexto) => AlertDialog(
        title: const Text('Sair da escala?'),
        content: const Text(
          'A vaga fica livre para outro coroinha se escalar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(contexto, false),
            child: const Text('Agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(contexto, true),
            child: const Text('Sim, sair'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    await _executar(
      item.escalacaoId,
      () => widget.repositorio.sairDaEscala(item.missaId),
    );
  }

  void _abrirAdministracao() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminPage(repositorio: widget.repositorio),
      ),
    );
  }

  Future<void> _abrirTrocas() async {
    // Aceitar uma troca muda a escala: ao voltar, ela é recarregada.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrocasDisponiveisPage(repositorio: widget.repositorio),
      ),
    );
    if (mounted) _recarregar();
  }

  Future<void> _abrirMissasAbertas() async {
    // Entrar numa escala muda a minha escala: ao voltar, ela é recarregada.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MissasAbertasPage(repositorio: widget.repositorio),
      ),
    );
    if (mounted) _recarregar();
  }

  // Cancelar o pedido não pede confirmação: se desfaz sozinho (dá para pedir
  // de novo).
  Future<void> _cancelarPedido(ItemEscala item) => _executar(
    item.escalacaoId,
    () => widget.repositorio.cancelarTroca(item.trocaAbertaId!),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha escala'),
        actions: [
          if (widget.administrador)
            TextButton(
              onPressed: _abrirAdministracao,
              child: const Text('Administração'),
            ),
          TextButton(
            onPressed: _abrirTrocas,
            child: const Text('Trocas abertas'),
          ),
          TextButton(
            onPressed: widget.repositorio.sair,
            child: const Text('Sair'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirMissasAbertas,
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('Missas abertas'),
      ),
      body: FutureBuilder<List<ItemEscala>>(
        future: _escala,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar a sua escala.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _recarregar,
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            );
          }

          final itens = snapshot.requireData;
          if (itens.isEmpty) {
            return const Center(child: Text('Você não tem missas escaladas.'));
          }
          return RefreshIndicator(
            onRefresh: _puxarParaAtualizar,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: itens.length,
              itemBuilder: (context, i) => _cartao(context, itens[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _cartao(BuildContext context, ItemEscala item) {
    final estilos = Theme.of(context).textTheme;
    final ocupada = _ocupadas.contains(item.escalacaoId);
    // Mesma regra do banco: a partir de 2h antes (inclusive o instante exato)
    // a confirmação já conta como atrasada.
    final passouDoPrazo = !widget.agora().isBefore(item.limiteParaConfirmar);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatarDataMissa(item.inicio), style: estilos.titleMedium),
            const SizedBox(height: 4),
            Text('${item.local} · ${item.funcao}'),
            if (item.trocaAberta)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Chip(label: Text('Troca aberta')),
              ),
            const SizedBox(height: 12),
            if (item.status == StatusPresenca.confirmado)
              Text(
                item.confirmadoComAtraso
                    ? 'Confirmado (com atraso)'
                    : 'Confirmado',
              )
            else ...[
              FilledButton(
                onPressed: ocupada ? null : () => _confirmar(item),
                child: const Text('Confirmar presença'),
              ),
              const SizedBox(height: 4),
              Text(
                passouDoPrazo
                    ? 'O prazo passou, mas você ainda pode confirmar.'
                    : 'Confirme até ${formatarDataMissa(item.limiteParaConfirmar)}',
                style: estilos.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            if (item.autoEscalada) ...[
              Text('Você se escalou', style: estilos.bodySmall),
              TextButton(
                onPressed: ocupada ? null : () => _sairDaEscala(item),
                child: const Text('Sair da escala'),
              ),
            ] else if (item.trocaAberta)
              OutlinedButton(
                onPressed: ocupada ? null : () => _cancelarPedido(item),
                child: const Text('Cancelar pedido de troca'),
              )
            else
              TextButton(
                onPressed: ocupada ? null : () => _pedirTroca(item),
                child: const Text('Pedir troca'),
              ),
          ],
        ),
      ),
    );
  }
}
