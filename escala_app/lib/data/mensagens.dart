/// Uma mensagem curta para a tela vazia: o [texto] e de onde ela vem.
class Mensagem {
  final String texto;
  final String fonte;

  const Mensagem(this.texto, this.fonte);
}

/// Conferida pelo coordenador e pelo desenvolvedor em 28/11/2026 (bíblicas na
/// Ave-Maria ou na de Jerusalém). Pode trocar, tirar ou acrescentar: só
/// mantenha o texto e a fonte de cada uma, sem texto repetido. Mudar o
/// tamanho da lista muda qual mensagem sai em cada dia, e não tem problema.
const mensagens = <Mensagem>[
  Mensagem('O Senhor é o meu pastor: nada me faltará.', 'Salmo 23,1'),
  Mensagem(
    'O Senhor é a minha luz e a minha salvação: de quem terei medo?',
    'Salmo 27,1',
  ),
  Mensagem(
    'A tua palavra é lâmpada para os meus passos e luz para o meu caminho.',
    'Salmo 119,105',
  ),
  Mensagem('O Senhor te abençoe e te guarde.', 'Números 6,24'),
  Mensagem('Não temas, porque eu estou contigo.', 'Isaías 41,10'),
  Mensagem(
    'Deixai vir a mim as criancinhas e não as impeçais, '
        'porque delas é o Reino de Deus.',
    'Marcos 10,14',
  ),
  Mensagem(
    'Vinde a mim, todos os que estais cansados e sobrecarregados, '
        'e eu vos aliviarei.',
    'Mateus 11,28',
  ),
  Mensagem(
    'Bem-aventurados os puros de coração, porque verão a Deus.',
    'Mateus 5,8',
  ),
  Mensagem(
    'Tudo o que fizestes a um destes meus irmãos mais pequeninos, '
        'a mim o fizestes.',
    'Mateus 25,40',
  ),
  Mensagem('Quem é fiel no pouco, é fiel também no muito.', 'Lucas 16,10'),
  Mensagem('Fazei tudo o que ele vos disser.', 'João 2,5'),
  Mensagem(
    'Eu sou o pão da vida. Quem vem a mim nunca mais terá fome.',
    'João 6,35',
  ),
  Mensagem(
    'Ninguém tem maior amor do que aquele que dá a vida pelos seus amigos.',
    'João 15,13',
  ),
  Mensagem(
    'Alegrai-vos sempre no Senhor. Repito: alegrai-vos!',
    'Filipenses 4,4',
  ),
  Mensagem('Tudo posso naquele que me fortalece.', 'Filipenses 4,13'),
  Mensagem('Servi-vos uns aos outros por amor.', 'Gálatas 5,13'),
  Mensagem(
    'Santo Tarcísio, padroeiro dos coroinhas, rogai por nós.',
    'Santo Tarcísio, mártir da Eucaristia',
  ),
  Mensagem(
    'Não tenhais medo! Abri, ou melhor, escancarai as portas a Cristo!',
    'São João Paulo II',
  ),
  Mensagem(
    'Fizeste-nos para ti, Senhor, e o nosso coração está inquieto '
        'enquanto não repousar em ti.',
    'Santo Agostinho, Confissões',
  ),
  Mensagem(
    'Senhor, fazei de mim um instrumento da vossa paz.',
    'Oração atribuída a São Francisco de Assis',
  ),
  Mensagem(
    'Nem todos podemos fazer grandes coisas, '
        'mas podemos fazer pequenas coisas com grande amor.',
    'Santa Teresa de Calcutá (atribuída)',
  ),
  Mensagem(
    'A Eucaristia é a minha autoestrada para o Céu.',
    'São Carlo Acutis (atribuída)',
  ),
  Mensagem(
    'Basta que sejais jovens para que eu vos ame muito.',
    'São João Bosco (atribuída)',
  ),
  Mensagem(
    'Deus em Si mesmo é a recompensa última e a finalidade do universo.',
    'Beato John Duns Scotus',
  ),
  Mensagem(
    'Não tema que sua vida chegue ao fim, mas sim que ela nunca tenha um começo.',
    'São John Henry Newman',
  ),
  Mensagem(
    'A humildade é o primeiro degrau para a sabedoria.',
    'São Tomás de Aquino',
  ),
];

/// A mensagem do dia: muda à meia-noite e é a mesma durante o dia inteiro.
/// Conta dias corridos (não o dia do ano), por isso a virada do ano não
/// repete nem pula mensagem.
Mensagem mensagemDoDia(DateTime dia) {
  final dias = DateTime.utc(
    dia.year,
    dia.month,
    dia.day,
  ).difference(DateTime.utc(2026, 1, 1)).inDays;
  return mensagens[dias % mensagens.length];
}
