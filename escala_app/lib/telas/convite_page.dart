import 'package:flutter/material.dart';

import '../data/escala_repository.dart';
import '../mensagem_de_erro.dart';

/// Tela de quem entrou com o Google mas ainda não tem perfil: digita o código
/// do convite, o próprio nome e, se for menor de idade, o nome do responsável.
///
/// Quem decide se o responsável é obrigatório é o CONVITE (o banco responde
/// ResponsavelObrigatorio), então o campo fica sempre visível e opcional.
class ConvitePage extends StatefulWidget {
  final EscalaRepository repositorio;

  const ConvitePage({super.key, required this.repositorio});

  @override
  State<ConvitePage> createState() => _ConvitePageState();
}

class _ConvitePageState extends State<ConvitePage> {
  final _codigo = TextEditingController();
  final _nome = TextEditingController();
  final _responsavel = TextEditingController();

  String? _erroCodigo;
  String? _erroNome;
  String? _mensagem; // erro vindo do banco, já traduzido
  bool _enviando = false;

  @override
  void dispose() {
    _codigo.dispose();
    _nome.dispose();
    _responsavel.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final codigo = _codigo.text.trim();
    final nome = _nome.text.trim();
    final responsavel = _responsavel.text.trim();

    // Conferência rápida na tela, só para poupar uma ida ao banco. As regras de
    // verdade continuam no banco.
    setState(() {
      _erroCodigo = codigo.isEmpty ? 'Informe o código do convite.' : null;
      _erroNome = nome.isEmpty ? 'Informe o seu nome.' : null;
      _mensagem = null;
    });
    if (codigo.isEmpty || nome.isEmpty) return;

    setState(() => _enviando = true);
    try {
      await widget.repositorio.resgatarConvite(
        codigo: codigo,
        nome: nome,
        // Em branco vira nulo: "nenhum responsável informado".
        responsavel: responsavel.isEmpty ? null : responsavel,
      );
      // Sucesso: o repositório avisa a raiz, que troca de tela sozinha.
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        // Erros de regra têm mensagem própria. O resto (rede, falha técnica)
        // vira um texto genérico: nunca se mostra texto técnico à pessoa.
        _mensagem = mensagemDoErro(e);
      });
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bem-vindo'),
        actions: [
          // Para quem entrou com a conta errada.
          TextButton(
            onPressed: widget.repositorio.sair,
            child: const Text('Usar outra conta'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Digite o código do convite que você recebeu.'),
              const SizedBox(height: 16),
              TextField(
                controller: _codigo,
                enabled: !_enviando,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Código do convite',
                  errorText: _erroCodigo,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nome,
                enabled: !_enviando,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Seu nome',
                  errorText: _erroNome,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _responsavel,
                enabled: !_enviando,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nome do responsável',
                  helperText: 'Obrigatório para menores de idade.',
                ),
              ),
              if (_mensagem != null) ...[
                const SizedBox(height: 16),
                Text(_mensagem!, style: TextStyle(color: cores.error)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _enviando ? null : _enviar,
                child: _enviando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
