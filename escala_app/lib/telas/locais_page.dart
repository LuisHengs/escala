import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../data/escala_repository.dart';
import '../data/local.dart';
import '../mensagem_de_erro.dart';

enum _AcaoDoLocal { renomear, remover }

/// (Administrador) Lista as igrejas e capelas, cadastra uma nova e permite
/// renomear ou remover as existentes.
class LocaisPage extends StatefulWidget {
  final EscalaRepository repositorio;

  const LocaisPage({super.key, required this.repositorio});

  @override
  State<LocaisPage> createState() => _LocaisPageState();
}

class _LocaisPageState extends State<LocaisPage> {
  late Future<List<Local>> _locais = widget.repositorio.locais();
  final _nome = TextEditingController();

  String? _mensagem; // aviso ou erro, já em português
  bool _salvando = false;

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  void _recarregar() {
    final futuro = widget.repositorio.locais();
    // O erro aparece na própria tela, pelo FutureBuilder. Sem o ignore(), uma
    // falha que chega ANTES de a tela começar a ouvir seria tratada como erro
    // não capturado. O FutureBuilder continua recebendo o erro normalmente.
    futuro.ignore();
    setState(() {
      _locais = futuro;
    });
  }

  Future<void> _adicionar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) {
      setState(() => _mensagem = 'Informe o nome do local.');
      return;
    }

    setState(() {
      _salvando = true;
      _mensagem = null;
    });
    var deuCerto = false;
    try {
      await widget.repositorio.criarLocal(nome);
      deuCerto = true;
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        // Erros de regra têm mensagem própria; o resto vira um texto genérico.
        _mensagem = mensagemDoErro(e);
      });
    } finally {
      if (mounted) setState(() => _salvando = false);
    }

    // A recarga fica FORA do try: se só ela falhar, a criação deu certo e
    // quem mostra o problema é a própria lista.
    if (deuCerto && mounted) {
      _nome.clear();
      _recarregar();
    }
  }

  void _avisar(String texto) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  /// Roda uma ação do menu (renomear/remover). Erro vira aviso na parte de
  /// baixo; a lista só recarrega se deu certo, e FORA do try.
  Future<void> _executarAcao(Future<void> Function() acao) async {
    if (_salvando) return;
    setState(() => _salvando = true);
    var deuCerto = false;
    try {
      await acao();
      deuCerto = true;
    } on Object catch (e) {
      if (!mounted) return;
      _avisar(mensagemDoErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }

    if (deuCerto && mounted) _recarregar();
  }

  Future<void> _renomear(Local local) async {
    // Não é descartado aqui de propósito: o diálogo ainda o usa durante a
    // animação de fechar, e descartar antes causa erro.
    final campo = TextEditingController(text: local.nome);
    final novo = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear local'),
        content: TextField(
          controller: campo,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome do local'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, campo.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (novo == null || !mounted) return; // cancelou

    final nome = novo.trim();
    if (nome.isEmpty) {
      _avisar('Informe o nome do local.');
      return;
    }
    await _executarAcao(() => widget.repositorio.renomearLocal(local.id, nome));
  }

  Future<void> _remover(Local local) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover local?'),
        content: Text(
          'Remover "${local.nome}"? Locais com missas cadastradas não '
          'podem ser removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    await _executarAcao(() => widget.repositorio.removerLocal(local.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Locais')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nome,
                  enabled: !_salvando,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nome do local',
                    errorText: _mensagem,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _salvando ? null : _adicionar,
                  child: _salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Adicionar local'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Local>>(
              future: _locais,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Não foi possível carregar os locais.'),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _recarregar,
                          child: const Text('Tentar de novo'),
                        ),
                      ],
                    ),
                  );
                }
                final locais = snapshot.requireData;
                if (locais.isEmpty) {
                  return const Center(child: Text('Nenhum local cadastrado.'));
                }
                return ListView(
                  children: [
                    for (final local in locais)
                      ListTile(
                        leading: const Icon(Icons.church_outlined),
                        title: Text(local.nome),
                        trailing: PopupMenuButton<_AcaoDoLocal>(
                          tooltip: 'Opções de ${local.nome}',
                          onSelected: (acao) {
                            switch (acao) {
                              case _AcaoDoLocal.renomear:
                                unawaited(_renomear(local));
                              case _AcaoDoLocal.remover:
                                unawaited(_remover(local));
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _AcaoDoLocal.renomear,
                              child: Text('Renomear'),
                            ),
                            PopupMenuItem(
                              value: _AcaoDoLocal.remover,
                              child: Text('Remover'),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
