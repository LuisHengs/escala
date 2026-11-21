import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import '../data/escala_repository.dart';
import '../mensagem_de_erro.dart';

/// Copia o texto para a área de transferência do aparelho.
Future<void> _copiarParaAreaDeTransferencia(String texto) =>
    Clipboard.setData(ClipboardData(text: texto));

/// (Administrador) Gera o convite de um coroinha.
///
/// O código só existe nesta tela: o banco guarda apenas o hash. Se a pessoa
/// sair daqui sem copiar, é só gerar outro.
class ConvitesPage extends StatefulWidget {
  final EscalaRepository repositorio;

  /// Como o código vai para a área de transferência (entra por parâmetro para
  /// o teste não depender do sistema).
  final Future<void> Function(String texto) copiar;

  const ConvitesPage({
    super.key,
    required this.repositorio,
    this.copiar = _copiarParaAreaDeTransferencia,
  });

  @override
  State<ConvitesPage> createState() => _ConvitesPageState();
}

class _ConvitesPageState extends State<ConvitesPage> {
  // O padrão protege: um convite novo exige o responsável. O administrador
  // desmarca só para adultos.
  bool _menorDeIdade = true;

  String? _codigo;
  String? _mensagem; // erro, já traduzido
  bool _gerando = false;

  Future<void> _gerar() async {
    setState(() {
      _gerando = true;
      _mensagem = null;
    });
    try {
      final codigo = await widget.repositorio.gerarConvite(
        exigeResponsavel: _menorDeIdade,
      );
      if (!mounted) return;
      setState(() {
        _codigo = codigo;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        // O código antigo some: a mensagem de erro não pode parecer ser dele.
        _codigo = null;
        // Erros de regra têm mensagem própria; o resto vira um texto genérico.
        _mensagem = mensagemDoErro(e);
      });
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  Future<void> _copiar(String codigo) async {
    await widget.copiar(codigo);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Código copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final codigo = _codigo;

    return Scaffold(
      appBar: AppBar(title: const Text('Convites')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _menorDeIdade,
                onChanged: _gerando
                    ? null
                    : (valor) => setState(() => _menorDeIdade = valor ?? true),
                title: const Text(
                  'Menor de idade (exige o nome do responsável)',
                ),
                subtitle: const Text('Desmarque só para adultos.'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _gerando ? null : _gerar,
                child: _gerando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Gerar convite'),
              ),
              if (_mensagem != null) ...[
                const SizedBox(height: 16),
                Text(
                  _mensagem!,
                  style: TextStyle(color: tema.colorScheme.error),
                ),
              ],
              if (codigo != null) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          codigo,
                          style: tema.textTheme.headlineMedium?.copyWith(
                            fontFamily: 'monospace',
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Este código só aparece agora e vale por 7 dias.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => _copiar(codigo),
                          child: const Text('Copiar código'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
