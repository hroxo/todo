import SwiftUI
import ToDoCore

/// O Glassy, a mascote da app (DESIGN.md 7.14). Muda de pose com a hora e com o estado do dia
/// (`EstadoGlassy`). A areia é a pressão do tempo: em cima quando não há nada a fechar, a descer
/// quando os pontos se acumulam, toda em baixo no ko.
enum PoseMascote: String, CaseIterable {
    /// De manhã, a acenar.
    case acenar
    /// À tarde, a ver a areia cair.
    case areia
    /// Tudo em dia: braços no ar.
    case celebrar
    /// À noite, de olhos fechados.
    case dormir
    /// Muitos pontos por fechar.
    case preocupado
    /// Perdeu tudo: vidro rachado e olho negro.
    case ko

    /// O ko vence tudo e o sono vence a preocupação: à noite ninguém é incomodado. De dia acena
    /// (manhã) ou vê a areia (tarde) e, com tudo feito, celebra de 20 em 20 minutos, para estar
    /// sempre a fazer outra coisa quando se olha para ele.
    static func para(_ data: Date, tudoEmDia: Bool, estado: EstadoGlassy? = nil, calendario: Calendar = .current) -> PoseMascote {
        if estado?.humor == .ko { return .ko }
        let hora = calendario.component(.hour, from: data)
        if hora >= 23 || hora < 7 { return .dormir }
        if estado?.humor == .preocupado { return .preocupado }
        let bloco = (hora * 60 + calendario.component(.minute, from: data)) / 20
        let doDia: PoseMascote = hora < 12 ? .acenar : .areia
        return tudoEmDia && bloco.isMultiple(of: 2) ? .celebrar : doDia
    }

    var titulo: String {
        switch self {
        case .acenar: "Bom dia!"
        case .areia: "Tudo calmo."
        case .celebrar: "Tudo em dia."
        case .dormir: "Boa noite."
        case .preocupado: "Está a apertar."
        case .ko: "Ai. Foi tudo."
        }
    }

    var subtitulo: String {
        switch self {
        case .acenar: "Nada pendente por agora."
        case .areia: "O tempo corre a teu favor."
        case .celebrar: "Bom trabalho!"
        case .dormir: "O tempo pára enquanto dormes."
        case .preocupado: "Há pontos a acabar o prazo."
        case .ko: "Ainda podes recuperá-los em Expirados."
        }
    }

    /// A pose cujo cenário se desenha: como na app, o céu segue o modo do iPhone (DESIGN.md 7.23).
    /// O escuro é sempre noite e o claro sempre dia; dormir continua a ser pela hora, mas de dia
    /// fica debaixo do céu claro. Só o ko mantém o seu cenário cinzento nos dois modos.
    func cena(escuro: Bool) -> PoseMascote {
        if self == .ko { return .ko }
        if escuro { return .dormir }
        return self == .dormir ? .areia : self
    }

    /// Texto claro nos cenários escuros (festa, noite e ko).
    var cenarioEscuro: Bool { self == .celebrar || self == .dormir || self == .ko }

    /// Com um tema (trabalho, vida pessoal, viagem), as poses de dia mudam de cenário, de
    /// objetos e de frase; as outras são iguais em todos os temas.
    func doTema(_ tema: TemaMascote) -> Bool {
        (self == .acenar || self == .areia) && tema.cenario != .geral
    }

    func titulo(_ tema: TemaMascote) -> String {
        guard doTema(tema) else { return titulo }
        switch (tema.cenario, self) {
        case (.trabalho, .areia): return "Foco no trabalho."
        case (.pessoal, .areia): return "Tempo para ti."
        case (.viagem, _): return "Boa viagem!"
        default: return titulo
        }
    }

    func subtitulo(_ tema: TemaMascote) -> String {
        guard doTema(tema) else { return subtitulo }
        switch (tema, self) {
        case (.trabalho, .acenar): return "Nada urgente no trabalho."
        case (.trabalho, _): return "Nada urgente por agora."
        case (.desporto, .acenar): return "Dia para te mexeres."
        case (.pessoal, .acenar), (.desporto, _): return "Tempo para ti hoje."
        case (.pessoal, _): return "Nada pendente em casa."
        case (.viagem, .acenar): return "Tudo pronto."
        case (.viagem, _): return "Aproveita a vista."
        default: return subtitulo
        }
    }

    /// As camadas desta pose (geradas por `scripts/glassy-assets.ps1`).
    fileprivate var imagem: String {
        switch self {
        case .acenar, .areia, .dormir: "feliz"
        case .celebrar: "celebrar"
        case .preocupado: "preocupado"
        case .ko: "ko"
        }
    }

    /// A areia quando não há estado do dia para a decidir (ecrãs vazios, pré-visualizações).
    fileprivate var nivel: Double {
        switch self {
        case .acenar, .celebrar: 0
        case .areia, .dormir: 0.3
        case .preocupado: 0.6
        case .ko: 1
        }
    }

    /// No celebrar os olhos já estão fechados a sorrir, e o ko fica atordoado, sem piscar.
    fileprivate var pisca: Bool { self != .celebrar && self != .ko }
}

extension TemaMascote {
    /// O cenário que se desenha: o desporto usa, por agora, o da vida pessoal.
    var cenario: TemaMascote { self == .desporto ? .pessoal : self }
}

/// O Glassy numa pose: as camadas das imagens originais, com a areia desenhada entre elas. Tudo
/// em coordenadas das imagens originais (1194 × 1600; o recorte começa em 130, 170). Com `vivo`,
/// respira, pisca, mexe os braços e a areia corre; sem ele (widgets, que não animam em contínuo,
/// e "Reduzir movimento") desenha-se o mesmo quadro, parado.
struct Ampulheta: View {
    let pose: PoseMascote
    var tema: TemaMascote = .geral
    /// De 0, toda em cima, a 1, toda em baixo. Nil usa a areia da pose.
    var nivelAreia: Double?
    var vivo = false

    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var tempo: Double?

    private static let recorte = CGRect(x: 130, y: 170, width: 980, height: 1205)
    private static let centro: CGFloat = 620
    /// Meia largura interior do vidro por linha; a mesma tabela de `scripts/glassy-assets.ps1`.
    private static let perfil: [(y: CGFloat, meia: CGFloat)] = [
        (306, 301), (350, 301), (400, 303), (450, 298), (500, 285), (550, 263), (600, 228), (650, 185),
        (700, 150), (750, 95), (775, 62), (800, 100), (850, 150), (900, 200), (950, 240), (1000, 265),
        (1050, 280), (1100, 287), (1150, 297), (1200, 301), (1240, 301),
    ]
    private static let vidro = Path { p in
        p.addLines(perfil.map { CGPoint(x: centro - $0.meia, y: $0.y) } + perfil.reversed().map { CGPoint(x: centro + $0.meia, y: $0.y) })
        p.closeSubpath()
    }
    // Os braços separam-se da madeira e das bochechas por zonas: nenhuma pose os põe lá.
    private static let bracoEsquerdo = Path { p in
        p.addRect(CGRect(x: 0, y: 320, width: 360, height: 905))
        p.addRect(CGRect(x: 360, y: 680, width: 260, height: 545))
    }
    private static let bracoDireito = Path { p in
        p.addRect(CGRect(x: 880, y: 320, width: 314, height: 905))
        p.addRect(CGRect(x: 620, y: 680, width: 260, height: 545))
    }
    private static let semBracos = Path { p in
        p.addRect(CGRect(x: 0, y: 0, width: 1194, height: 320))
        p.addRect(CGRect(x: 360, y: 320, width: 520, height: 360))
        p.addRect(CGRect(x: 0, y: 1225, width: 1194, height: 375))
    }

    /// No trabalho e na vida pessoal, de dia, segura um objeto à frente: o portátil e o café,
    /// ou um livro.
    private var objeto: TemaMascote? {
        guard pose.doTema(tema), tema.cenario == .trabalho || tema.cenario == .pessoal else { return nil }
        return tema.cenario
    }

    var body: some View {
        let anima = vivo && !reduzirMovimento
        quadro(anima ? tempo : nil)
            .aspectRatio(Self.recorte.width / Self.recorte.height, contentMode: .fit)
            .accessibilityHidden(true)
            // Sem TimelineView: aninhada na da raiz, deixa a app em branco ao abrir (History.md).
            // Isto só redesenha o Glassy e cancela-se quando ele sai do ecrã.
            .task(id: anima) {
                guard anima else { return }
                while !Task.isCancelled {
                    tempo = Date.timeIntervalSinceReferenceDate
                    try? await Task.sleep(for: .milliseconds(33))
                }
            }
    }

    /// `t` em segundos; nil desenha o Glassy parado.
    private func quadro(_ t: Double?) -> some View {
        Canvas { c, tamanho in
            let escala = min(tamanho.width / Self.recorte.width, tamanho.height / Self.recorte.height)
            c.translateBy(
                x: (tamanho.width - Self.recorte.width * escala) / 2,
                y: (tamanho.height - Self.recorte.height * escala) / 2
            )
            c.scaleBy(x: escala, y: escala)
            c.translateBy(x: -Self.recorte.minX, y: -Self.recorte.minY)
            if let t {
                // Respira a partir da base; no ko, cambaleia.
                c.translateBy(x: Self.centro, y: Self.recorte.maxY)
                if pose == .ko { c.rotate(by: .degrees(sin(t * 0.9) * 1.2)) }
                c.scaleBy(x: 1, y: 1 + 0.012 * sin(t * 1.7))
                c.translateBy(x: -Self.centro, y: -Self.recorte.maxY)
            }
            desenharTras(em: c, t)
            // Sem isto, o céu passa pelo vidro e o Glassy mistura-se com o fundo. Por baixo da
            // areia, para ela não perder a cor.
            c.fill(Self.vidro, with: .color(.white.opacity(0.4)))
            desenharAreia(em: c, t)
            c.draw(c.resolve(Image("glassy_\(pose.imagem)_frente")), in: Self.recorte)
            desenharPalpebras(em: c, t)

            // O que vem do desenho antigo está num espaço de 100 × 120.
            var antigo = c
            antigo.translateBy(x: Self.recorte.minX, y: Self.recorte.minY)
            antigo.scaleBy(x: 9.8, y: 9.8)
            if let objeto { desenharObjeto(objeto, em: &antigo) }
            if pose == .dormir { desenharSono(em: antigo, t) }
        }
    }

    // MARK: - Camadas

    private func desenharTras(em c: GraphicsContext, _ t: Double?) {
        let imagem = c.resolve(Image("glassy_\(pose.imagem)_tras"))
        guard let t else {
            c.draw(imagem, in: Self.recorte)
            return
        }
        // Graus de cada braço; negativo levanta o direito e positivo levanta o esquerdo.
        let (esquerdo, direito): (Double, Double) = switch pose {
        case .acenar: (sin(t * 1.2) * 1.5, -9 + sin(t * 5.5) * 9)
        case .areia: (sin(t * 1.3) * 1.5, -sin(t * 1.3) * 1.5)
        case .celebrar: (sin(t * 7) * 6, -sin(t * 7) * 6)
        case .preocupado: (sin(t * 22) * 1.2, sin(t * 22) * 1.2)
        case .ko: (sin(t * 1.1) * 0.8, -sin(t * 1.1) * 0.8)
        case .dormir: (0, 0)
        }
        var corpo = c
        corpo.clip(to: Self.semBracos)
        corpo.draw(imagem, in: Self.recorte)
        for (zona, ombro, graus) in [
            (Self.bracoEsquerdo, CGPoint(x: 440, y: 860), esquerdo),
            (Self.bracoDireito, CGPoint(x: 800, y: 860), direito),
        ] {
            var braco = c
            braco.translateBy(x: ombro.x, y: ombro.y)
            braco.rotate(by: .degrees(graus))
            braco.translateBy(x: -ombro.x, y: -ombro.y)
            braco.clip(to: zona)
            braco.draw(imagem, in: Self.recorte)
        }
    }

    /// O cone encolhe para o gargalo (o volume de um cone varia com o cubo), o monte sobe a
    /// partir da base e o fio liga os dois.
    private func desenharAreia(em contexto: GraphicsContext, _ t: Double?) {
        var c = contexto
        c.clip(to: Self.vidro)
        let nivel = CGFloat(min(1, max(0, nivelAreia ?? pose.nivel)))
        let meio = Self.centro
        let alturaMonte: CGFloat = 340 * (0.06 + 0.94 * nivel)
        let topoMonte: CGFloat = 1245 - alturaMonte
        let cone: CGFloat = pow(1 - nivel, 1.0 / 3)
        // À noite o tempo pára, e sem areia de um dos lados não há o que cair.
        let corre = nivel > 0.01 && nivel < 0.99 && pose != .dormir

        if corre {
            let fio = CGRect(x: meio - 65, y: 770, width: 130, height: topoMonte - 770 + 12)
            var coluna = c
            coluna.clip(to: Path(fio))
            let imagem = c.resolve(Image("glassy_areia_fio"))
            let desvio = t.map { CGFloat(($0 * 140).truncatingRemainder(dividingBy: Double(fio.height))) } ?? 0
            coluna.draw(imagem, in: fio.offsetBy(dx: 0, dy: desvio))
            coluna.draw(imagem, in: fio.offsetBy(dx: 0, dy: desvio - fio.height))
        }
        if cone > 0.02 {
            let caixa = CGRect(x: meio - 315 * cone, y: 775 - 440 * cone, width: 640 * cone, height: 440 * cone)
            c.draw(c.resolve(Image("glassy_areia_cima")), in: caixa)
        }
        c.draw(c.resolve(Image("glassy_areia_monte")), in: CGRect(x: meio - 310, y: topoMonte, width: 620, height: alturaMonte))

        guard let t else { return }
        let dourado = Color(red: 0.87, green: 0.63, blue: 0.33)
        if corre {
            // Grãos soltos a cair, mais depressa à medida que descem.
            for i in 0..<10 {
                let fase = (t * 0.7 + Double(i) * 0.137).truncatingRemainder(dividingBy: 1)
                let x = meio + CGFloat(sin(Double(i) * 12.9) * 38 * fase)
                let y = 780 + (topoMonte - 780) * CGFloat(fase * fase)
                let raio = CGFloat(3 + i % 3)
                c.fill(Path(ellipseIn: CGRect(x: x - raio, y: y - raio, width: raio * 2, height: raio * 2)), with: .color(dourado))
            }
        }
        // Os brilhos da areia acendem e apagam, cada um no seu tempo.
        for i in 0..<8 {
            let brilho = pow(max(0, sin(t * 2 + Double(i) * 1.7)), 8)
            guard brilho > 0.01 else { continue }
            let emCima = i.isMultiple(of: 2)
            if emCima && cone <= 0.2 { continue }
            let lugar = CGFloat(i)
            let x: CGFloat = meio + (lugar - 4) * (emCima ? 42 * cone : 58)
            let y: CGFloat = emCima ? 775 - 300 * cone + lugar * 8 : topoMonte + alturaMonte * (0.3 + 0.08 * lugar)
            let raio = 5 * CGFloat(brilho)
            c.fill(Path(ellipseIn: CGRect(x: x - raio, y: y - raio, width: raio * 2, height: raio * 2)), with: .color(.white.opacity(0.9)))
        }
    }

    /// As imagens só têm os olhos abertos: a pálpebra desenha-se por cima. A dormir fica fechada.
    private func desenharPalpebras(em c: GraphicsContext, _ t: Double?) {
        guard pose.pisca else { return }
        var fechado = pose == .dormir ? 1.0 : 0.0
        if let t, pose != .dormir {
            let momento = t.truncatingRemainder(dividingBy: 4.3)
            if momento < 0.16 { fechado = sin(.pi * momento / 0.16) }
        }
        guard fechado > 0 else { return }
        let castanho = Color(red: 0.25, green: 0.12, blue: 0.06)
        for centro in [CGPoint(x: 506, y: 520), CGPoint(x: 734, y: 520)] {
            let olho = CGRect(x: centro.x - 65, y: centro.y - 66, width: 130, height: 132)
            let aba = olho.minY + olho.height * fechado
            var palpebra = c
            palpebra.clip(to: Path(ellipseIn: olho))
            palpebra.fill(Path(CGRect(x: olho.minX, y: olho.minY, width: olho.width, height: aba - olho.minY)), with: .color(Color(red: 0.94, green: 0.89, blue: 0.84)))
            // A pestana desce com a pálpebra e, fechada, curva como a do olho a dormir.
            var pestana = Path()
            pestana.move(to: CGPoint(x: olho.minX + 6, y: aba - olho.height * 0.5 * fechado))
            pestana.addQuadCurve(
                to: CGPoint(x: olho.maxX - 6, y: aba - olho.height * 0.5 * fechado),
                control: CGPoint(x: centro.x, y: aba + 12)
            )
            c.stroke(pestana, with: .color(castanho), style: StrokeStyle(lineWidth: 11, lineCap: .round))
        }
    }

    /// Os "z" do sono, a subir devagar.
    private func desenharSono(em c: GraphicsContext, _ t: Double?) {
        let lilas = Color(red: 0.69, green: 0.66, blue: 0.93)
        let sobe = t.map { CGFloat(sin($0 * 0.9) * 2) } ?? 0
        c.draw(Text("z").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(lilas), at: CGPoint(x: 84, y: 22 + sobe))
        c.draw(Text("z").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(lilas), at: CGPoint(x: 93, y: 12 - sobe))
    }

    /// O portátil e a chávena de café (trabalho), ou um livro aberto (vida pessoal).
    private func desenharObjeto(_ objeto: TemaMascote, em c: inout GraphicsContext) {
        func cor(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        if objeto == .trabalho {
            let ecra = Path { p in
                p.move(to: CGPoint(x: 12, y: 82))
                p.addLine(to: CGPoint(x: 26, y: 68))
                p.addLine(to: CGPoint(x: 76, y: 68))
                p.addLine(to: CGPoint(x: 62, y: 82))
                p.closeSubpath()
            }
            c.fill(ecra, with: .color(cor(0.37, 0.42, 0.48)))
            c.fill(Path(ellipseIn: CGRect(x: 41.6, y: 72.6, width: 4.8, height: 4.8)), with: .color(cor(0.87, 0.89, 0.92)))
            c.fill(Path(roundedRect: CGRect(x: 4, y: 82, width: 74, height: 6), cornerRadius: 3), with: .color(cor(0.53, 0.58, 0.64)))
            c.fill(Path(roundedRect: CGRect(x: 80, y: 71, width: 14, height: 17), cornerRadius: 3), with: .color(.white))
            var asa = Path()
            asa.move(to: CGPoint(x: 94, y: 75))
            asa.addQuadCurve(to: CGPoint(x: 94, y: 84), control: CGPoint(x: 100, y: 79.5))
            c.stroke(asa, with: .color(.white), lineWidth: 2.5)
            var vapor = Path()
            for x in [84.0, 90.0] {
                vapor.move(to: CGPoint(x: x, y: 66))
                vapor.addQuadCurve(to: CGPoint(x: x, y: 56), control: CGPoint(x: x + 2.5, y: 61))
            }
            c.stroke(vapor, with: .color(cor(0.6, 0.65, 0.71)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        } else {
            let livro = Path { p in
                p.move(to: CGPoint(x: 20, y: 72))
                p.addLine(to: CGPoint(x: 49, y: 66))
                p.addLine(to: CGPoint(x: 78, y: 72))
                p.addLine(to: CGPoint(x: 78, y: 94))
                p.addLine(to: CGPoint(x: 49, y: 88))
                p.addLine(to: CGPoint(x: 20, y: 94))
                p.closeSubpath()
            }
            c.fill(livro, with: .color(cor(0.85, 0.35, 0.19)))
            var linhas = Path()
            linhas.move(to: CGPoint(x: 49, y: 66))
            linhas.addLine(to: CGPoint(x: 49, y: 88))
            for (x0, x1, y0) in [(24.0, 46.0, 75.0), (24.0, 46.0, 80.0), (52.0, 74.0, 70.0), (52.0, 74.0, 75.0)] {
                linhas.move(to: CGPoint(x: x0, y: y0))
                linhas.addLine(to: CGPoint(x: x1, y: x0 < 49 ? y0 - 4.5 : y0 + 4.5))
            }
            c.stroke(linhas, with: .color(.white.opacity(0.75)), lineWidth: 1.1)
        }
    }
}

/// O cenário de cada pose, atrás da Ampulheta: manhã com sol, dia com nuvens, festa com
/// confettis, noite com lua e estrelas.
struct CenarioMascote: View {
    let pose: PoseMascote
    var tema: TemaMascote = .geral

    @Environment(\.colorScheme) private var esquema

    var body: some View {
        let cena = pose.cena(escuro: esquema == .dark)
        if cena.doTema(tema) {
            CenarioTema(tema: tema.cenario)
        } else {
            cenarioDoDia(cena)
        }
    }

    private func cenarioDoDia(_ pose: PoseMascote) -> some View {
        Canvas { c, t in
            let caixa = CGRect(origin: .zero, size: t)
            func cor(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
            let (de, ate): (Color, Color) = switch pose {
            case .acenar: (cor(1, 0.89, 0.70), cor(0.75, 0.87, 0.97))
            case .areia: (cor(0.81, 0.91, 0.98), cor(0.92, 0.96, 0.99))
            case .celebrar: (cor(0.36, 0.79, 0.65), cor(0.11, 0.62, 0.46))
            case .dormir: (cor(0.24, 0.20, 0.54), cor(0.11, 0.09, 0.25))
            case .preocupado: (cor(1, 0.86, 0.62), cor(0.98, 0.70, 0.50))
            case .ko: (cor(0.42, 0.45, 0.55), cor(0.20, 0.22, 0.31))
            }
            c.fill(Path(caixa), with: .linearGradient(
                Gradient(colors: [de, ate]),
                startPoint: .zero,
                endPoint: pose == .areia ? CGPoint(x: 0, y: t.height) : CGPoint(x: t.width, y: t.height)
            ))

            func nuvem(_ x: CGFloat, _ y: CGFloat, _ escala: CGFloat) {
                c.fill(Path(ellipseIn: CGRect(x: x - 26 * escala, y: y - 9 * escala, width: 52 * escala, height: 18 * escala)), with: .color(.white.opacity(0.85)))
                c.fill(Path(ellipseIn: CGRect(x: x - 1 * escala, y: y - 17 * escala, width: 30 * escala, height: 20 * escala)), with: .color(.white.opacity(0.85)))
            }

            switch pose {
            case .acenar:
                c.fill(Path(ellipseIn: CGRect(x: t.width - 74, y: -6, width: 68, height: 68)), with: .color(cor(1, 0.78, 0.38).opacity(0.9)))
                nuvem(t.width * 0.58, 40, 1)
            case .areia:
                nuvem(t.width * 0.68, 30, 1.1)
                nuvem(t.width * 0.88, t.height - 30, 0.8)
            case .celebrar:
                let papelinhos: [(CGFloat, CGFloat, Color)] = [
                    (0.47, 0.14, cor(0.98, 0.78, 0.46)), (0.74, 0.23, cor(0.96, 0.64, 0.75)),
                    (0.89, 0.71, .white), (0.38, 0.82, cor(0.98, 0.78, 0.46)),
                    (0.63, 0.14, .white), (0.94, 0.38, cor(0.98, 0.78, 0.46)), (0.06, 0.14, cor(0.96, 0.64, 0.75)),
                ]
                for (i, (x, y, tom)) in papelinhos.enumerated() {
                    var papel = c
                    papel.translateBy(x: t.width * x, y: t.height * y)
                    papel.rotate(by: .degrees(Double(i) * 37))
                    papel.fill(Path(roundedRect: CGRect(x: -4, y: -2, width: 8, height: 4), cornerRadius: 2), with: .color(tom))
                }
            case .dormir:
                let lua = CGPoint(x: t.width - 48, y: 36)
                // Recortada a sério: tapada com uma cor, via-se o disco sobre o gradiente.
                c.drawLayer { camada in
                    camada.fill(Path(ellipseIn: CGRect(x: lua.x - 20, y: lua.y - 20, width: 40, height: 40)), with: .color(cor(0.98, 0.93, 0.85)))
                    camada.blendMode = .destinationOut
                    camada.fill(Path(ellipseIn: CGRect(x: lua.x - 7, y: lua.y - 24, width: 34, height: 34)), with: .color(.black))
                }
                for (x, y, r) in [(0.5, 0.14, 1.6), (0.63, 0.29, 1.2), (0.72, 0.11, 1.8), (0.93, 0.6, 1.3), (0.41, 0.86, 1.2), (0.08, 0.11, 1.4)] {
                    c.fill(Path(ellipseIn: CGRect(x: t.width * x - r, y: t.height * y - r, width: r * 2, height: r * 2)), with: .color(.white))
                }
            case .preocupado, .ko:
                break
            }
        }
    }
}

/// Os cenários dos temas, de dia (DESIGN.md 7.14): um escritório claro com janela e
/// secretária; um parque com sol, relva e uma árvore; a cabine de um avião com a janela à
/// esquerda (a Ampulheta senta-se ao lado).
private struct CenarioTema: View {
    let tema: TemaMascote

    var body: some View {
        Canvas { c, t in
            func cor(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
            func gradiente(_ de: Color, _ ate: Color, vertical: Bool = false) {
                c.fill(Path(CGRect(origin: .zero, size: t)), with: .linearGradient(
                    Gradient(colors: [de, ate]),
                    startPoint: .zero,
                    endPoint: vertical ? CGPoint(x: 0, y: t.height) : CGPoint(x: t.width, y: t.height)
                ))
            }
            switch tema {
            case .trabalho:
                gradiente(cor(0.91, 0.89, 0.97), cor(0.81, 0.85, 0.95))
                let janela = CGRect(x: t.width * 0.6, y: 16, width: 64, height: 48)
                c.fill(Path(roundedRect: janela, cornerRadius: 6), with: .color(.white.opacity(0.7)))
                var caixilho = Path()
                caixilho.move(to: CGPoint(x: janela.midX, y: janela.minY))
                caixilho.addLine(to: CGPoint(x: janela.midX, y: janela.maxY))
                caixilho.move(to: CGPoint(x: janela.minX, y: janela.midY))
                caixilho.addLine(to: CGPoint(x: janela.maxX, y: janela.midY))
                c.stroke(caixilho, with: .color(cor(0.81, 0.85, 0.95)), lineWidth: 3)
                c.fill(Path(CGRect(x: 0, y: t.height - 36, width: t.width, height: 36)), with: .color(cor(0.73, 0.54, 0.37).opacity(0.35)))
            case .pessoal:
                gradiente(cor(0.81, 0.94, 0.98), cor(0.91, 0.97, 0.93), vertical: true)
                c.fill(Path(ellipseIn: CGRect(x: t.width - 62, y: 6, width: 44, height: 44)), with: .color(cor(1, 0.82, 0.48)))
                let relva = Path { p in
                    p.move(to: CGPoint(x: 0, y: t.height - 36))
                    p.addQuadCurve(to: CGPoint(x: t.width * 0.53, y: t.height - 38), control: CGPoint(x: t.width * 0.26, y: t.height - 54))
                    p.addQuadCurve(to: CGPoint(x: t.width, y: t.height - 42), control: CGPoint(x: t.width * 0.8, y: t.height - 26))
                    p.addLine(to: CGPoint(x: t.width, y: t.height))
                    p.addLine(to: CGPoint(x: 0, y: t.height))
                }
                c.fill(relva, with: .color(cor(0.59, 0.77, 0.35)))
                // Na ponta direita, para não tapar a frase.
                let tronco = CGPoint(x: t.width - 18, y: t.height - 40)
                c.fill(Path(roundedRect: CGRect(x: tronco.x - 4, y: tronco.y - 50, width: 8, height: 52), cornerRadius: 3), with: .color(cor(0.54, 0.35, 0.2)))
                for (dx, dy, r, tom) in [(0.0, -58.0, 24.0, cor(0.39, 0.6, 0.13)), (-16.0, -48.0, 14.0, cor(0.48, 0.68, 0.21)), (16.0, -46.0, 14.0, cor(0.48, 0.68, 0.21))] {
                    c.fill(Path(ellipseIn: CGRect(x: tronco.x + dx - r, y: tronco.y + dy - r, width: r * 2, height: r * 2)), with: .color(tom))
                }
            case .viagem:
                gradiente(cor(0.91, 0.93, 0.95), cor(0.79, 0.83, 0.87))
                let moldura = CGRect(x: 14, y: 12, width: 112, height: t.height - 24)
                c.fill(Path(roundedRect: moldura, cornerRadius: 44), with: .color(cor(0.68, 0.73, 0.78)))
                let vidro = moldura.insetBy(dx: 9, dy: 9)
                c.fill(Path(roundedRect: vidro, cornerRadius: 38), with: .linearGradient(
                    Gradient(colors: [cor(0.36, 0.66, 0.94), cor(0.75, 0.88, 0.98)]),
                    startPoint: CGPoint(x: 0, y: vidro.minY),
                    endPoint: CGPoint(x: 0, y: vidro.maxY)
                ))
                var ceu = c
                ceu.clip(to: Path(roundedRect: vidro, cornerRadius: 38))
                for (x, y, l) in [(0.35, 0.72, 44.0), (0.6, 0.66, 28.0), (0.82, 0.32, 26.0)] {
                    let centro = CGPoint(x: vidro.minX + vidro.width * x, y: vidro.minY + vidro.height * y)
                    ceu.fill(Path(ellipseIn: CGRect(x: centro.x - l / 2, y: centro.y - l / 6, width: l, height: l / 3)), with: .color(.white))
                }
            case .geral, .desporto:
                break
            }
        }
    }
}
