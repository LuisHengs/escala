
import 'package:flutter/material.dart';

import '../data/escala_repository.dart';
import '../data/pendencia_em_atraso.dart';
import '../formatacao.dart';

/// Lista as escalações pendentes cujo prazo de confirmação já foi atingido.
class PendenciasEmAtrasoPage extends StatefulWidget {
  final EscalaRepository repositorio;

  const PendenciasEmAtrasoPage({
    super.key,
    required this.repositorio,
  });

  @override
  State<PendenciasEmAtrasoPage> createState() =>
      _PendenciasEmAtrasoPageState();
}

class _PendenciasEmAtrasoPageState
    extends State<PendenciasEmAtrasoPage> {
  late Future<List<PendenciaEmAtraso>> _pendencias =
      widget.repositorio.pendenciasEmAtraso();

  void _recarregar() {
    setState(() {
      _pendencias = widget.repositorio.pendenciasEmAtraso();
    });
  }

  Future<void> _puxarParaAtualizar() async {
    _recarregar();

    try {
      await _pendencias;
    } on Object catch (_) {
      // O FutureBuilder apresenta o erro na tela.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pendências em atraso'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _recarregar,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<PendenciaEmAtraso>>(
        future: _pendencias,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Não foi possível carregar as pendências.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _recarregar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final pendencias = snapshot.requireData;

          if (pendencias.isEmpty) {
            return RefreshIndicator(
              onRefresh: _puxarParaAtualizar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Icon(
                    Icons.check_circle_outline,
                    size: 48,
                  ),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Nenhuma pendência em atraso.',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _puxarParaAtualizar,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: pendencias.length,
              itemBuilder: (context, index) {
                return _cartao(pendencias[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _cartao(PendenciaEmAtraso pendencia) {
    final estilos = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.deepOrange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pendencia.coroinhaNome,
                    style: estilos.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Função: ${pendencia.funcao}'),
            const Divider(height: 24),
            Text(
              'Missa: ${formatarDataMissa(pendencia.inicio)}',
              style: estilos.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Confirmação pendente',
              style: estilos.bodySmall?.copyWith(
                color: Colors.deepOrange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
