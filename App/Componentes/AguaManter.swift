import QuartzCore
import SwiftUI

/// Física do botão Manter: molas amortecidas integradas a cada fotograma, para as gotas terem
/// inércia, ressalto e líquido lá dentro que balança, em vez de animações de duração fixa.
/// A cápsula segue o dedo, as bolhas seguem a cápsula com atraso (o pescoço de vidro estica)
/// e o líquido passa da cápsula para a bolha escolhida, com a superfície a inclinar-se e a ondular.
@MainActor
@Observable
final class AguaManter {
    /// Mola de massa 1. `amortecimento` vai de 0 (ressalta para sempre) a 1 (sem ressalto).
    struct Mola {
        var x: CGFloat
        var v: CGFloat = 0
        var alvo: CGFloat
        let rigidez: CGFloat
        var amortecimento: CGFloat
        /// Abaixo disto a mola conta como parada.
        let tolerancia: CGFloat

        init(_ x: CGFloat = 0, rigidez: CGFloat, amortecimento: CGFloat, tolerancia: CGFloat = 0.3) {
            self.x = x
            alvo = x
            self.rigidez = rigidez
            self.amortecimento = amortecimento
            self.tolerancia = tolerancia
        }

        /// Avança `dt` segundos com uma força extra e devolve a aceleração.
        @discardableResult
        mutating func avancar(_ dt: CGFloat, forca: CGFloat = 0) -> CGFloat {
            let atrito = 2 * amortecimento * rigidez.squareRoot()
            let a = -rigidez * (x - alvo) - atrito * v + forca
            v += a * dt
            x += v * dt
            return a
        }

        var parada: Bool { abs(v) < tolerancia && abs(x - alvo) < tolerancia }

        mutating func assentar() {
            x = alvo
            v = 0
        }
    }

    /// O líquido dentro de uma gota.
    struct Recipiente {
        /// 0 vazio, 1 cheio.
        var nivel: Mola
        /// Declive da superfície; a aceleração da gota empurra o líquido para trás.
        var inclinacao = Mola(rigidez: 110, amortecimento: 0.12, tolerancia: 0.004)
        /// Achatamento e esticão da gota (geleia), chutado nos momentos principais.
        var pulso = Mola(rigidez: 320, amortecimento: 0.18, tolerancia: 0.002)

        init(cheio: Bool) {
            nivel = Mola(cheio ? 1 : 0, rigidez: 70, amortecimento: 0.55, tolerancia: 0.003)
        }

        mutating func avancar(_ dt: CGFloat, aceleracao: CGFloat, comInercia: Bool) {
            nivel.avancar(dt)
            inclinacao.avancar(dt, forca: comInercia ? aceleracao * 0.045 : 0)
            inclinacao.x = max(-0.7, min(0.7, inclinacao.x))
            pulso.avancar(dt)
        }

        var parado: Bool { nivel.parada && inclinacao.parada && pulso.parada }

        mutating func assentar() {
            nivel.assentar()
            inclinacao.assentar()
            pulso.assentar()
        }
    }

    enum Gota { case capsula, curto, longo }

    /// De -1 a 1, como o dedo, mas com inércia (as bolhas crescem e encolhem com ressalto).
    private(set) var progresso = Mola(rigidez: 180, amortecimento: 0.45, tolerancia: 0.002)
    /// Posições horizontais absolutas: a cápsula e o centro de cada bolha (em relação ao lugar dela).
    private(set) var capsula = Mola(rigidez: 240, amortecimento: 0.4)
    private(set) var curto = Mola(rigidez: 150, amortecimento: 0.28)
    private(set) var longo = Mola(rigidez: 150, amortecimento: 0.28)
    private(set) var liquidoCapsula = Recipiente(cheio: true)
    private(set) var liquidoCurto = Recipiente(cheio: false)
    private(set) var liquidoLongo = Recipiente(cheio: false)
    /// Fase das ondas, sempre a correr enquanto há movimento.
    private(set) var fase: CGFloat = 0
    private(set) var aberto = false

    var reduzirMovimento = false {
        didSet {
            let amortecer: CGFloat = reduzirMovimento ? 1 : 0
            capsula.amortecimento = max(0.4, amortecer)
            curto.amortecimento = max(0.28, amortecer)
            longo.amortecimento = max(0.28, amortecer)
            progresso.amortecimento = max(0.45, amortecer)
        }
    }

    private var dedo: CGFloat = 0
    @ObservationIgnored private var ligacao: CADisplayLink?
    @ObservationIgnored private var ultimo: CFTimeInterval?
    @ObservationIgnored private var limiar: CGFloat = 40

    /// O dedo mexeu-se (ou soltou-se, com `aberto` falso).
    func definir(dedo: CGFloat, aberto: Bool, limiar: CGFloat) {
        self.dedo = dedo
        self.aberto = aberto
        self.limiar = limiar
        atualizarAlvos()
        arrancar()
    }

    /// As bolhas nascem de dentro da cápsula e saltam para fora.
    func nascer() {
        curto.x = capsula.x + 56
        longo.x = capsula.x - 56
        curto.v = 0
        longo.v = 0
        salpicar(.capsula, forca: 1.6)
        arrancar()
    }

    /// Um toque de geleia numa gota (nascer, passar o limiar, confirmar).
    func salpicar(_ gota: Gota, forca: CGFloat) {
        guard !reduzirMovimento else { return }
        switch gota {
        case .capsula: liquidoCapsula.pulso.v += forca
        case .curto: liquidoCurto.pulso.v += forca
        case .longo: liquidoLongo.pulso.v += forca
        }
        arrancar()
    }

    /// Salta logo para o estado final, sem movimento (capturas de demonstração).
    func assentar() {
        atualizarAlvos()
        progresso.assentar()
        capsula.assentar()
        curto.alvo = capsula.x + relativoCurto
        longo.alvo = capsula.x + relativoLongo
        curto.assentar()
        longo.assentar()
        liquidoCapsula.assentar()
        liquidoCurto.assentar()
        liquidoLongo.assentar()
    }

    func parar() {
        ligacao?.invalidate()
        ligacao = nil
        ultimo = nil
    }

    /// A superfície do líquido de uma gota, pronta a desenhar.
    func superficie(_ recipiente: Recipiente, atras: Bool = false) -> SuperficieLiquida {
        let nivel = max(0, min(1, recipiente.nivel.x))
        // Cheio ou vazio, a superfície acalma (não há onde ondular).
        let borda = min(1, min(nivel, 1 - nivel) * 6)
        let agitacao = reduzirMovimento ? 0 : (aberto ? 1.4 : 0) + min(5, abs(recipiente.inclinacao.v) * 4)
        return SuperficieLiquida(
            nivel: nivel,
            inclinacao: reduzirMovimento ? 0 : recipiente.inclinacao.x * borda,
            amplitude: agitacao * borda * (atras ? 0.8 : 1),
            fase: atras ? -fase * 0.8 + 2 : fase
        )
    }

    // MARK: - Simulação

    private func atualizarAlvos() {
        let p = aberto ? tanh(dedo / 60) : 0
        progresso.alvo = p
        capsula.alvo = p * 40
        let esquerda = aberto ? suave(-dedo / limiar) : 0
        let direita = aberto ? suave(dedo / limiar) : 0
        liquidoCurto.nivel.alvo = esquerda
        liquidoLongo.nivel.alvo = direita
        // O líquido sai da cápsula para a bolha escolhida e volta a enchê-la ao soltar.
        liquidoCapsula.nivel.alvo = aberto ? 0.3 * (1 - max(esquerda, direita)) : 1
    }

    /// Onde cada bolha quer estar em relação à cápsula: a escolhida aproxima-se e funde-se,
    /// a outra afasta-se até se soltar.
    private var relativoCurto: CGFloat { progresso.x < 0 ? -16 * progresso.x : -26 * progresso.x }
    private var relativoLongo: CGFloat { progresso.x > 0 ? -16 * progresso.x : -26 * progresso.x }

    private func arrancar() {
        guard ligacao == nil else { return }
        let batida = Batida()
        batida.agua = self
        let nova = CADisplayLink(target: batida, selector: #selector(Batida.passo(_:)))
        nova.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        nova.add(to: .main, forMode: .common)
        ligacao = nova
    }

    fileprivate func passo(_ ligacao: CADisplayLink) {
        let dt = CGFloat(min(1.0 / 30, ultimo.map { ligacao.timestamp - $0 } ?? 1.0 / 60))
        ultimo = ligacao.timestamp
        let comInercia = !reduzirMovimento
        // Dois subpassos: as molas mais rígidas ficam estáveis mesmo a 60 Hz.
        let h = dt / 2
        for _ in 0..<2 {
            progresso.avancar(h)
            let aCapsula = capsula.avancar(h)
            curto.alvo = capsula.x + relativoCurto
            longo.alvo = capsula.x + relativoLongo
            let aCurto = curto.avancar(h)
            let aLongo = longo.avancar(h)
            liquidoCapsula.avancar(h, aceleracao: aCapsula, comInercia: comInercia)
            liquidoCurto.avancar(h, aceleracao: aCurto, comInercia: comInercia)
            liquidoLongo.avancar(h, aceleracao: aLongo, comInercia: comInercia)
        }
        fase += dt * 7

        let parado = progresso.parada && capsula.parada && curto.parada && longo.parada
            && liquidoCapsula.parado && liquidoCurto.parado && liquidoLongo.parado
        // Aberto, as ondas continuam a mexer; fechado e assente, desliga-se para poupar bateria.
        if parado && !aberto {
            parar()
        }
    }

    /// 0 até ao centro, 1 a partir do limiar, com entrada e saída suaves.
    private func suave(_ t: CGFloat) -> CGFloat {
        let c = max(0, min(1, t))
        return c * c * (3 - 2 * c)
    }
}

/// Alvo do CADisplayLink, que guarda uma referência forte: assim a física pode desaparecer.
@MainActor
private final class Batida: NSObject {
    weak var agua: AguaManter?

    @objc func passo(_ ligacao: CADisplayLink) {
        guard let agua else {
            ligacao.invalidate()
            return
        }
        agua.passo(ligacao)
    }
}

/// O líquido até um nível, com a superfície inclinada e uma onda por cima.
struct SuperficieLiquida: Shape {
    var nivel: CGFloat
    var inclinacao: CGFloat
    var amplitude: CGFloat
    var fase: CGFloat

    func path(in r: CGRect) -> Path {
        var caminho = Path()
        guard nivel > 0.002 else { return caminho }
        // Um pouco acima do topo quando cheio, para não ficar uma linha por encher.
        let base = r.maxY - (r.height + 4) * nivel
        let comprimento = max(r.width * 0.85, 40)
        func altura(_ x: CGFloat) -> CGFloat {
            base + inclinacao * (x - r.midX) + amplitude * sin(2 * .pi * (x - r.minX) / comprimento + fase)
        }
        caminho.move(to: CGPoint(x: r.minX, y: r.maxY))
        for x in stride(from: r.minX, to: r.maxX, by: 2) {
            caminho.addLine(to: CGPoint(x: x, y: altura(x)))
        }
        caminho.addLine(to: CGPoint(x: r.maxX, y: altura(r.maxX)))
        caminho.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        caminho.closeSubpath()
        return caminho
    }
}
