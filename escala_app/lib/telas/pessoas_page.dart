import 'package:material_ui/material_ui.dart';

import '../data/escala_repository.dart';
import '../data/pessoa.dart';
import '../mensagem_de_erro.dart';

/// (Administrador) As pessoas cadastradas, com papel e situação. Cada uma tem
/// um menu para ativar/desativar e para mudar o papel.
class PessoasPage extends StatefulWidget {
  final EscalaRepository repositorio;

  const PessoasPage({super.key, required this.repositorio});

  @override
  State<PessoasPage> createState() => _PessoasPageState();
}

class _PessoasPageState extends State<PessoasPage> {
  late Future<List<Pessoa>> _pessoas = widget.repositorio.pessoas();
  bool _ocupado = false; // evita dois toques seguidos durante uma ação

  void _recarregar() {
    final futuro = widget.repositorio.pessoas();
    // O erro aparece na própria tela, pelo FutureBuilder. Sem o ignore(), uma
    // falha que chega antes de a tela começar a ouvir seria tratada como erro
    // não capturado.
    futuro.ignore();
    setState(() {
      _pessoas = futuro;
    });
  }

  /// O único caminho das ações: bloqueia toques repetidos, mostra a mensagem
  /// de erro e recarrega só se deu certo (fora do try).
  Future<void> _executar(Future<void> Function() acao) async {
    if (_ocupado) return;
    _ocupado = true;
    var deuCerto = false;
    try {
      await acao();
      deuCerto = true;
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagemDoErro(e))));
    } finally {
      _ocupado = false;
    }

    // Fora do try: se só o recarregamento falhar, a lista mostra o próprio
    // erro de carga e não diz que a ação falhou.
    if (deuCerto && mounted) _recarregar();
  }

  Future<bool> _confirmar({
    required String titulo,
    required String texto,
    required String botao,
  }) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(botao),
          ),
        ],
      ),
    );
    return confirmou == true && mounted;
  }

  Future<void> _aoEscolher(Pessoa pessoa, String acao) async {
    switch (acao) {
      case 'ativar':
        // Se desfaz sozinho (dá para desativar de novo): sem confirmação.
        await _executar(
          () =>
              widget.repositorio.definirAtivo(pessoaId: pessoa.id, ativo: true),
        );
      case 'desativar':
        final ok = await _confirmar(
          titulo: 'Desativar pessoa?',
          texto:
              '${pessoa.nome} não poderá mais entrar no app. '
              'Dá para ativar de novo depois.',
          botao: 'Desativar',
        );
        if (!ok) return;
        await _executar(
          () => widget.repositorio.definirAtivo(
            pessoaId: pessoa.id,
            ativo: false,
          ),
        );
      case 'admin' || 'coroinha':
        final ok = await _confirmar(
          titulo: 'Alterar papel?',
          texto: acao == 'admin'
              ? '${pessoa.nome} passará a ser administrador.'
              : '${pessoa.nome} passará a ser coroinha.',
          botao: 'Alterar',
        );
        if (!ok) return;
        await _executar(
          () =>
              widget.repositorio.definirPapel(pessoaId: pessoa.id, papel: acao),
        );
      case 'apagar':
        final ok = await _confirmar(
          titulo: 'Apagar pessoa?',
          texto:
              'Apagar ${pessoa.nome} de vez? Somem o acesso, a escala e as '
              'trocas dessa pessoa. Não dá para desfazer.',
          botao: 'Apagar',
        );
        if (!ok) return;
        await _executar(() => widget.repositorio.apagarPessoa(pessoa.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pessoas')),
      body: FutureBuilder<List<Pessoa>>(
        future: _pessoas,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar as pessoas.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _recarregar,
                    child: const Text('Tentar de novo'),
                  ),
                ],
              ),
            );
          }
          final pessoas = snapshot.requireData;
          if (pessoas.isEmpty) {
            return const Center(child: Text('Nenhuma pessoa cadastrada.'));
          }
          return ListView(
            children: [
              for (final pessoa in pessoas)
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(pessoa.nome),
                  subtitle: Text(
                    '${pessoa.administrador ? 'Administrador' : 'Coroinha'}'
                    '${pessoa.ativo ? '' : ' · Inativo'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Ações da pessoa',
                    onSelected: (acao) => _aoEscolher(pessoa, acao),
                    itemBuilder: (_) => [
                      pessoa.ativo
                          ? const PopupMenuItem(
                              value: 'desativar',
                              child: Text('Desativar'),
                            )
                          : const PopupMenuItem(
                              value: 'ativar',
                              child: Text('Ativar'),
                            ),
                      pessoa.administrador
                          ? const PopupMenuItem(
                              value: 'coroinha',
                              child: Text('Tornar coroinha'),
                            )
                          : const PopupMenuItem(
                              value: 'admin',
                              child: Text('Tornar administrador'),
                            ),
                      if (!pessoa.ativo)
                        const PopupMenuItem(
                          value: 'apagar',
                          child: Text('Apagar'),
                        ),
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
