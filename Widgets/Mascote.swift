import SwiftUI
import ToDoCore

/// A Ampulheta, a mascote da app (DESIGN.md 7.14). Aparece no widget quando não há nada a
/// pedir atenção e muda de pose ao longo do dia (o WidgetKit anima a passagem). A areia conta
/// o dia: de manhã está quase toda em cima, cai devagar à tarde, fica toda em baixo quando está
/// tudo feito, e à noite a ampulheta deita-se: o tempo pára enquanto dormes. Desenhada em
/// código (Canvas), para ficar nítida em qualquer tamanho.
enum PoseMascote: String, CaseIterable {
    /// De manhã, a acenar.
    case acenar
    /// À tarde, a ver a areia cair.
    case areia
    /// Tudo em dia: braços no ar.
    case celebrar
    /// À noite, deitada a dormir.
    case dormir

    /// Dorme à noite; de dia acena (manhã) ou vê a areia (tarde) e, com tudo feito, celebra
    /// de 20 em 20 minutos, para estar sempre a fazer outra coisa quando se olha para ela.
    static func para(_ data: Date, tudoEmDia: Bool, calendario: Calendar = .current) -> PoseMascote {
        let hora = calendario.component(.hour, from: data)
        if hora >= 23 || hora < 7 { return .dormir }
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
        }
    }

    var subtitulo: String {
        switch self {
        case .acenar: "Nada pendente por agora."
        case .areia: "O tempo corre a teu favor."
        case .celebrar: "Bom trabalho!"
        case .dormir: "O tempo pára enquanto dormes."
        }
    }

    /// Texto claro nos cenários escuros (festa e noite).
    var cenarioEscuro: Bool { self == .celebrar || self == .dormir }

    /// Com um tema (trabalho, vida pessoal, viagem), as poses de dia mudam de cenário, de
    /// objetos e de frase; celebrar e dormir são iguais em todos os temas.
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
}

extension TemaMascote {
    /// O cenário que se desenha: o desporto usa, por agora, o da vida pessoal.
    var cenario: TemaMascote { self == .desporto ? .pessoal : self }
}

/// A Ampulheta numa pose. Desenhada num espaço de 100 × 120 (deitada, 120 × 100).
struct Ampulheta: View {
    let pose: PoseMascote
    var tema: TemaMascote = .geral

    /// No trabalho e na vida pessoal, de dia, segura um objeto à frente: o portátil e o café,
    /// ou um livro.
    private var objeto: TemaMascote? {
        guard pose.doTema(tema), tema.cenario == .trabalho || tema.cenario == .pessoal else { return nil }
        return tema.cenario
    }

    private static let madeira = Color(red: 0.88, green: 0.54, blue: 0.31)
    private static let madeiraClara = Color(red: 0.94, green: 0.65, blue: 0.42)
    private static let areia = Color(red: 0.96, green: 0.73, blue: 0.35)
    private static let areiaClara = Color(red: 0.99, green: 0.84, blue: 0.54)
    private static let escuro = Color(red: 0.16, green: 0.08, blue: 0.03)
    private static let rosa = Color(red: 0.96, green: 0.64, blue: 0.75)

    var body: some View {
        let deitada = pose == .dormir
        Canvas { contexto, tamanho in
            let espaco = deitada ? CGSize(width: 120, height: 100) : CGSize(width: 100, height: 120)
            let escala = min(tamanho.width / espaco.width, tamanho.height / espaco.height)
            contexto.translateBy(
                x: (tamanho.width - espaco.width * escala) / 2,
                y: (tamanho.height - espaco.height * escala) / 2
            )
            contexto.scaleBy(x: escala, y: escala)
            if deitada {
                var corpo = contexto
                // Roda à volta do centro: o bolbo de cima fica à esquerda.
                corpo.translateBy(x: 60, y: 50)
                corpo.rotate(by: .degrees(-90))
                corpo.translateBy(x: -50, y: -60)
                desenharCorpo(em: &corpo)
                // A cara deita-se com o corpo, como quem dorme de lado na almofada.
                desenharRostoDeitado(em: &corpo)
                desenharSono(em: &contexto)
            } else {
                desenharCorpo(em: &contexto)
                desenharRosto(em: &contexto)
                if let objeto {
                    desenharObjeto(objeto, em: &contexto)
                }
            }
        }
        .aspectRatio(deitada ? 1.2 : 100.0 / 120, contentMode: .fit)
        .accessibilityHidden(true)
    }

    // MARK: - Corpo

    private func desenharCorpo(em c: inout GraphicsContext) {
        let traco = StrokeStyle(lineWidth: 8, lineCap: .round)
        for braco in bracos {
            c.stroke(braco, with: .color(Self.madeira), style: traco)
        }

        let vidro = Path { p in
            p.move(to: CGPoint(x: 22, y: 14))
            p.addLine(to: CGPoint(x: 78, y: 14))
            p.addQuadCurve(to: CGPoint(x: 54, y: 60), control: CGPoint(x: 78, y: 44))
            p.addQuadCurve(to: CGPoint(x: 78, y: 106), control: CGPoint(x: 78, y: 76))
            p.addLine(to: CGPoint(x: 22, y: 106))
            p.addQuadCurve(to: CGPoint(x: 46, y: 60), control: CGPoint(x: 22, y: 76))
            p.addQuadCurve(to: CGPoint(x: 22, y: 14), control: CGPoint(x: 22, y: 44))
            p.closeSubpath()
        }
        c.fill(vidro, with: .color(Color(red: 0.96, green: 0.98, blue: 1).opacity(0.94)))

        let gradienteAreia = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [Self.areiaClara, Self.areia]),
            startPoint: CGPoint(x: 50, y: 14),
            endPoint: CGPoint(x: 50, y: 106)
        )
        for monte in areia {
            c.fill(monte, with: gradienteAreia)
        }
        if pose == .areia {
            // O fio de areia a cair.
            var fio = Path()
            fio.move(to: CGPoint(x: 50, y: 56))
            fio.addLine(to: CGPoint(x: 50, y: 88))
            c.stroke(fio, with: .color(Self.areia), style: StrokeStyle(lineWidth: 1.6, dash: [2, 3]))
        }

        c.stroke(vidro, with: .color(.white), style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
        var reflexo = Path()
        reflexo.move(to: CGPoint(x: 28, y: 20))
        reflexo.addQuadCurve(to: CGPoint(x: 36, y: 44), control: CGPoint(x: 28, y: 36))
        c.stroke(reflexo, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: 3, lineCap: .round))

        for y in [4.0, 105.0] {
            let tampa = Path(roundedRect: CGRect(x: 12, y: y, width: 76, height: 11), cornerRadius: 5.5)
            c.fill(tampa, with: .linearGradient(
                Gradient(colors: [Self.madeiraClara, Self.madeira]),
                startPoint: CGPoint(x: 0, y: y),
                endPoint: CGPoint(x: 0, y: y + 11)
            ))
            c.stroke(tampa, with: .color(.white), lineWidth: 2)
        }
    }

    private var bracos: [Path] {
        func braco(_ de: CGPoint, _ controlo: CGPoint, _ ate: CGPoint) -> Path {
            Path { p in
                p.move(to: de)
                p.addQuadCurve(to: ate, control: controlo)
            }
        }
        if objeto != nil {
            // Os dois braços à frente, a segurar o objeto.
            return [
                braco(CGPoint(x: 30, y: 44), CGPoint(x: 20, y: 62), CGPoint(x: 34, y: 74)),
                braco(CGPoint(x: 70, y: 44), CGPoint(x: 80, y: 62), CGPoint(x: 66, y: 74)),
            ]
        }
        switch pose {
        case .acenar:
            return [
                braco(CGPoint(x: 72, y: 40), CGPoint(x: 92, y: 30), CGPoint(x: 96, y: 12)),
                braco(CGPoint(x: 28, y: 42), CGPoint(x: 12, y: 52), CGPoint(x: 10, y: 64)),
            ]
        case .areia:
            return [
                braco(CGPoint(x: 28, y: 42), CGPoint(x: 14, y: 52), CGPoint(x: 12, y: 62)),
                braco(CGPoint(x: 72, y: 42), CGPoint(x: 86, y: 52), CGPoint(x: 88, y: 62)),
            ]
        case .celebrar:
            return [
                braco(CGPoint(x: 26, y: 40), CGPoint(x: 10, y: 28), CGPoint(x: 10, y: 12)),
                braco(CGPoint(x: 74, y: 40), CGPoint(x: 90, y: 28), CGPoint(x: 90, y: 12)),
            ]
        case .dormir:
            return []
        }
    }

    private var areia: [Path] {
        switch pose {
        case .acenar:
            return [
                Path { p in
                    p.move(to: CGPoint(x: 27, y: 20))
                    p.addLine(to: CGPoint(x: 73, y: 20))
                    p.addQuadCurve(to: CGPoint(x: 54, y: 55), control: CGPoint(x: 71, y: 40))
                    p.addLine(to: CGPoint(x: 46, y: 55))
                    p.addQuadCurve(to: CGPoint(x: 27, y: 20), control: CGPoint(x: 29, y: 40))
                },
                Path { p in
                    p.move(to: CGPoint(x: 38, y: 104))
                    p.addQuadCurve(to: CGPoint(x: 62, y: 104), control: CGPoint(x: 50, y: 98))
                },
            ]
        case .areia:
            return [
                Path { p in
                    p.move(to: CGPoint(x: 33, y: 34))
                    p.addLine(to: CGPoint(x: 67, y: 34))
                    p.addQuadCurve(to: CGPoint(x: 54, y: 55), control: CGPoint(x: 64, y: 46))
                    p.addLine(to: CGPoint(x: 46, y: 55))
                    p.addQuadCurve(to: CGPoint(x: 33, y: 34), control: CGPoint(x: 36, y: 46))
                },
                Path { p in
                    p.move(to: CGPoint(x: 30, y: 104))
                    p.addQuadCurve(to: CGPoint(x: 70, y: 104), control: CGPoint(x: 50, y: 86))
                },
            ]
        case .celebrar:
            return [
                Path { p in
                    p.move(to: CGPoint(x: 25, y: 104))
                    p.addQuadCurve(to: CGPoint(x: 46, y: 68), control: CGPoint(x: 26, y: 80))
                    p.addLine(to: CGPoint(x: 54, y: 68))
                    p.addQuadCurve(to: CGPoint(x: 75, y: 104), control: CGPoint(x: 74, y: 80))
                },
            ]
        case .dormir:
            // Deitada, a areia assenta no lado esquerdo de cada bolbo (que fica em baixo).
            return [
                Path { p in
                    p.move(to: CGPoint(x: 23, y: 15))
                    p.addLine(to: CGPoint(x: 34, y: 15))
                    p.addLine(to: CGPoint(x: 34, y: 50))
                    p.addQuadCurve(to: CGPoint(x: 23, y: 15), control: CGPoint(x: 26, y: 42))
                },
                Path { p in
                    p.move(to: CGPoint(x: 23, y: 105))
                    p.addLine(to: CGPoint(x: 34, y: 105))
                    p.addLine(to: CGPoint(x: 34, y: 70))
                    p.addQuadCurve(to: CGPoint(x: 23, y: 105), control: CGPoint(x: 26, y: 78))
                },
            ]
        }
    }

    // MARK: - Rosto

    /// Olhos brilhantes (estilo A): ovais escuros com um só reflexo. A ver a areia, olham
    /// para baixo.
    private func desenharRosto(em c: inout GraphicsContext) {
        bochechas(em: &c, centros: [CGPoint(x: 33, y: 46), CGPoint(x: 67, y: 46)])
        if pose == .celebrar {
            for x in [34.0, 56.0] {
                var arco = Path()
                arco.move(to: CGPoint(x: x, y: 34))
                arco.addQuadCurve(to: CGPoint(x: x + 10, y: 34), control: CGPoint(x: x + 5, y: 27))
                c.stroke(arco, with: .color(Self.escuro), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            }
            var boca = Path()
            boca.move(to: CGPoint(x: 43, y: 43))
            boca.addQuadCurve(to: CGPoint(x: 57, y: 43), control: CGPoint(x: 50, y: 54))
            boca.closeSubpath()
            c.fill(boca, with: .color(Self.escuro))
            return
        }
        let baixo: CGFloat = pose == .areia ? 2 : 0
        for x in [40.0, 60.0] {
            let olho = Path(ellipseIn: CGRect(x: x - 4.2, y: 27 + baixo, width: 8.4, height: 12))
            c.fill(olho, with: .radialGradient(
                Gradient(colors: [Color(red: 0.29, green: 0.16, blue: 0.08), Self.escuro]),
                center: CGPoint(x: x - 1, y: 30 + baixo),
                startRadius: 0,
                endRadius: 7
            ))
            c.fill(Path(ellipseIn: CGRect(x: x - 0.2, y: 29 + baixo, width: 3.2, height: 3.2)), with: .color(.white))
        }
        var sorriso = Path()
        sorriso.move(to: CGPoint(x: 46, y: 46))
        sorriso.addQuadCurve(to: CGPoint(x: 54, y: 46), control: CGPoint(x: 50, y: 49.5))
        c.stroke(sorriso, with: .color(Self.escuro), style: StrokeStyle(lineWidth: 2, lineCap: .round))
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

    /// A cara a dormir, desenhada no referencial do corpo deitado (rodado): olhos fechados em
    /// arcos suaves, as bochechas e a boca num "o" pequenino. Deitada, os olhos ficam um por
    /// cima do outro.
    private func desenharRostoDeitado(em c: inout GraphicsContext) {
        // Mais para dentro do que de pé: deitada, o vidro estreita junto às bochechas.
        bochechas(em: &c, centros: [CGPoint(x: 36, y: 40), CGPoint(x: 64, y: 40)])
        for x in [40.0, 60.0] {
            var palpebra = Path()
            palpebra.move(to: CGPoint(x: x - 5.5, y: 32))
            palpebra.addQuadCurve(to: CGPoint(x: x + 5.5, y: 32), control: CGPoint(x: x, y: 38))
            c.stroke(palpebra, with: .color(Self.escuro), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
        }
        c.fill(Path(ellipseIn: CGRect(x: 47.6, y: 43.6, width: 4.8, height: 3.8)), with: .color(Self.escuro))
    }

    /// Os "z" do sono, por cima da ampulheta deitada (fora do referencial rodado).
    private func desenharSono(em c: inout GraphicsContext) {
        let lilas = Color(red: 0.69, green: 0.66, blue: 0.93)
        c.draw(Text("z").font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(lilas), at: CGPoint(x: 100, y: 16))
        c.draw(Text("z").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(lilas), at: CGPoint(x: 110, y: 7))
    }

    private func bochechas(em c: inout GraphicsContext, centros: [CGPoint]) {
        for centro in centros {
            c.fill(
                Path(ellipseIn: CGRect(x: centro.x - 4.6, y: centro.y - 2.6, width: 9.2, height: 5.2)),
                with: .color(Self.rosa.opacity(0.85))
            )
        }
    }
}

/// O cenário de cada pose, atrás da Ampulheta: manhã com sol, dia com nuvens, festa com
/// confettis, noite com lua e estrelas.
struct CenarioMascote: View {
    let pose: PoseMascote
    var tema: TemaMascote = .geral

    var body: some View {
        if pose.doTema(tema) {
            CenarioTema(tema: tema.cenario)
        } else {
            cenarioDoDia
        }
    }

    private var cenarioDoDia: some View {
        Canvas { c, t in
            let caixa = CGRect(origin: .zero, size: t)
            func cor(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
            let (de, ate): (Color, Color) = switch pose {
            case .acenar: (cor(1, 0.89, 0.70), cor(0.75, 0.87, 0.97))
            case .areia: (cor(0.81, 0.91, 0.98), cor(0.92, 0.96, 0.99))
            case .celebrar: (cor(0.36, 0.79, 0.65), cor(0.11, 0.62, 0.46))
            case .dormir: (cor(0.24, 0.20, 0.54), cor(0.11, 0.09, 0.25))
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
                c.fill(Path(ellipseIn: CGRect(x: lua.x - 20, y: lua.y - 20, width: 40, height: 40)), with: .color(cor(0.98, 0.93, 0.85)))
                c.fill(Path(ellipseIn: CGRect(x: lua.x - 7, y: lua.y - 24, width: 34, height: 34)), with: .color(cor(0.17, 0.14, 0.40)))
                for (x, y, r) in [(0.5, 0.14, 1.6), (0.63, 0.29, 1.2), (0.72, 0.11, 1.8), (0.93, 0.6, 1.3), (0.41, 0.86, 1.2), (0.08, 0.11, 1.4)] {
                    c.fill(Path(ellipseIn: CGRect(x: t.width * x - r, y: t.height * y - r, width: r * 2, height: r * 2)), with: .color(.white))
                }
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
