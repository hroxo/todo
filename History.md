# Histórico de bugs

O que correu mal, como se descobriu e o que ficou para não voltar a acontecer. A entrada mais
recente fica em cima. Cada afirmação diz o nível de certeza: **visto no iPhone**, **visto no
simulador**, **passou no CI** ou **suspeita**.

## Novembro de 2026: a app ficava em branco ao abrir com o calendário autorizado

### Para quem usa a app

Com o calendário autorizado, a app podia ficar com o ecrã em branco ao abrir, sem crash e sem
recuperar. Os dados não eram afetados.

**Estado:** corrigido e visto no simulador (CI verde em `5891b55`). Falta confirmar no iPhone.

### Causa

Havia dois relógios (`TimelineView`) de minuto a minuto, um dentro do outro: um na raiz da app
(`App/ToDoApp.swift`, para o céu) e outro na secção do calendário. Juntos, prendiam o SwiftUI num
ciclo de layout dentro do primeiro desenho, e o ecrã nunca chegava a aparecer. Nas pilhas não
corria nenhum código da app.

O relógio da secção existia desde o `66295dc` (M5). O da raiz entrou no `f81ca61` (Melhoria 24), por
isso o bloqueio deve datar daí (**suspeita**: não foi testado nesse commit).

### Prova: experiência com a app real no simulador

| Variante | Resultado |
| --- | --- |
| Como estava (dois relógios aninhados) | Bloqueia |
| Com o limite de depuração de ciclos de layout do UIKit | A app morre, com o depurador do UIKit na pilha |
| `.everyMinute` nas duas vistas ou só na secção | Bloqueia (4 em 4) |
| Texto da lista vazia trocado por um retângulo | Bloqueia |
| Secção montada só depois do primeiro desenho | Bloqueia |
| Sem o relógio da secção | Abre (3 em 3) e desenha os eventos |
| Sem o relógio da raiz | Abre |
| Com uma animação ativa na secção | Abre |
| Modo de demonstração com a lista vazia | Abre |

Duas pistas erradas ficaram pelo caminho:

- **"É o `from: .now`":** foi a primeira suspeita, e a troca por `.everyMinute` não resolveu a
  abertura normal. Só abriu numa abertura, já com eventos, e sem o sinal de desenho completo:
  não conta como correção.
- **"É a leitura do calendário a bloquear":** nas aberturas bloqueadas a app nem chegava a ficar
  ativa, por isso a leitura não começava. Tornar a leitura assíncrona, como no `2374d57`, não
  podia resolver este bloqueio.

### Correção

- **Um só relógio:** a raiz publica a hora em `EnvironmentValues.agora` e a secção lê-a, sem
  relógio próprio.
- **Recuperação:** `Calendario.marcarAbertura()` deixa uma marca antes de o primeiro desenho
  acabar. Se a app bloquear e for fechada, a abertura seguinte mostra o cartão "Não foi possível
  ler o calendário", com "Tentar outra vez", em vez dos eventos. Antes, esta proteção só cobria a
  leitura, por isso um bloqueio ao desenhar não a acionava.

Visto no simulador: eventos reais desenhados com a app ativa, passagem para "já passaram" ao longo
de uma mudança de minuto, e o cartão depois de uma abertura interrompida.

### Por que razão o CI não apanhou isto

1. **O modo de demonstração passava.** Usa outros dados e salta partes do arranque. A causa
   continua por explicar: a variante com lista vazia também abre.
2. **O teste só media o tamanho da captura.** O aviso de notificações do sistema enchia a captura
   mesmo com a app em branco. Agora o CI procura na pilha a app presa no primeiro desenho.
3. **Falso alarme "a app morreu".** Com `pipefail`, o `grep -q` fechava a leitura e a verificação
   falhava com a app viva. Mostrava um erro errado e escondia o verdadeiro.

### Erros cometidos durante a correção

- **Dois commits não compilaram**, por edições feitas com comandos sem verificar o resultado: um
  espaço em falta, na experiência, e duas linhas não aplicadas no `6259353`, que obrigaram ao
  `9fdc737`. O CI apanhou ambos.
- **O primeiro teste do cartão não interrompia nada.** Passava sem provar a recuperação; só a
  leitura da captura o mostrou. Um CI verde não prova o que o teste não exercita.
- **O erro de arquitetura:** o céu do dia acrescentou um relógio global sem verificar a árvore de
  vistas, e uma secção opcional conseguia impedir o primeiro ecrã de aparecer. A app não tinha
  defesa contra isso, e devia ter tido.

### O que fica para o futuro

- Uma secção opcional nunca pode impedir o primeiro ecrã de aparecer.
- Uma só `TimelineView` periódica na árvore: quem precisa da hora lê `\.agora`.
- Comunicações e verificações (calendário, iCloud, contas) correm fora da linha principal e têm um
  estado de falha que a pessoa vê e pode repetir.
- Mudanças no arranque só contam com o "Arranque real" verde e as capturas vistas. O modo de
  demonstração não o prova.
- Uma abertura que bloqueia tem de deixar marca, para a seguinte poder recuperar.

### Em aberto

- **Confirmar no iPhone:** o simulador não tem iCloud nem os dados reais.
- **Confetes (risco não testado):** `Confetes` tem uma `TimelineView(.animation)` dentro da raiz e
  pode aparecer ao abrir num dia completo. A variante com animação abriu, mas isso é só um indício.
- **Limite da recuperação:** a marca só cobre o calendário. Um bloqueio noutra parte do primeiro
  ecrã não recupera sozinho.
- **Mecanismo interno:** o SwiftUI é fechado. Está provado o que bloqueia e o que resolve, não o
  porquê dentro da framework.

## Novembro de 2026: `ErroBaseDadosView` "cannot find in scope" no Mac

O ficheiro existe e o CI compila-o, por isso o código estava correto. O `.xcodeproj` é gerado e não
está no git. **Suspeita**, não confirmada: o projeto local era anterior ao ficheiro novo.

Sempre que aparecerem ficheiros novos, correr `git pull && xcodegen generate` antes de compilar no
Mac.

## Novembro de 2026: TestFlight "Choose a certificate to revoke"

Cada corrida usa um Mac novo, que cria um certificado de desenvolvimento para arquivar. A chave
privada morre com a máquina e o certificado fica na conta, até ao limite. O erro "No profiles" é
consequência disso (causa vista nos registos).

**Correção:** antes de arquivar, o workflow revoga os certificados de desenvolvimento chamados
"Created via API". **Ainda não testada**, porque o workflow só corre à mão. Depende desse nome, que
a Apple não garante; se mudar, nada é revogado e o erro volta.
