import 'package:flutter/material.dart';

import '../formatacao.dart';
import '../data/escala_repository.dart';
import '../data/missa_cadastrada.dart';
import 'nova_missa_page.dart';

import 'package:escala_core/escala_core.dart';

/// (Administrador) As próximas missas cadastradas, com o horário e o local.
class MissasPage extends StatefulWidget {
  final EscalaRepository repositorio;

  /// Como a tela de nova missa pergunta a data e a hora (entra por parâmetro
  /// para o teste não depender do calendário do sistema).
  final EscolherDataHora escolherDataHora;

  const MissasPage({
    super.key,
    required this.repositorio,
    this.escolherDataHora = escolherDataHoraDoSistema,
  });

  @override
  State<MissasPage> createState() => _MissasPageState();
}

class _MissasPageState extends State<MissasPage> {
  late Future<List<MissaCadastrada>> _missas = widget.repositorio.missas();

  void _recarregar() {
    final futuro = widget.repositorio.missas();
    // O erro aparece na própria tela, pelo FutureBuilder. Sem o ignore(), uma
    // falha que chega antes de a tela começar a ouvir seria tratada como erro
    // não capturado.
    futuro.ignore();
    setState(() {
      _missas = futuro;
    });
  }

  Future<void> _adicionar() async {
    final criou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NovaMissaPage(
          repositorio: widget.repositorio,
          escolherDataHora: widget.escolherDataHora,
        ),
      ),
    );
    if (criou == true && mounted) _recarregar();
  }

  bool _ocupado = false; // evita dois toques seguidos durante uma ação

  Future<void> _editar(MissaCadastrada missa) async {
    final salvou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NovaMissaPage(
          repositorio: widget.repositorio,
          escolherDataHora: widget.escolherDataHora,
          missa: missa,
        ),
      ),
    );
    if (salvou == true && mounted) _recarregar();
  }

  Future<void> _remover(MissaCadastrada missa) async {
    if (_ocupado) return;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover missa?'),
        content: Text(
          '${formatarDataMissa(missa.inicio)} · ${missa.localNome}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    _ocupado = true;
    var deuCerto = false;
    try {
      await widget.repositorio.removerMissa(missa.id);
      deuCerto = true;
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is RegraDeNegocio
                ? e.mensagem
                : 'Algo deu errado. Tente de novo.',
          ),
        ),
      );
    } finally {
      _ocupado = false;
    }

    // Fora do try: se só o recarregamento falhar, a lista mostra o próprio
    // erro de carga e não diz que a remoção falhou.
    if (deuCerto && mounted) _recarregar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Missas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _adicionar,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar missa'),
      ),
      body: FutureBuilder<List<MissaCadastrada>>(
        future: _missas,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar as missas.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _recarregar,
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            );
          }
          final missas = snapshot.requireData;
          if (missas.isEmpty) {
            return const Center(
              child: Text('Nenhuma missa futura cadastrada.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              for (final missa in missas)
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(formatarDataMissa(missa.inicio)),
                  subtitle: Text(missa.localNome),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Ações da missa',
                    onSelected: (acao) {
                      if (acao == 'editar') _editar(missa);
                      if (acao == 'remover') _remover(missa);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'editar', child: Text('Editar')),
                      PopupMenuItem(value: 'remover', child: Text('Remover')),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
