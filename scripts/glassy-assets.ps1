# Gera as camadas do Glassy a partir das imagens em Glassy2/ (fundo verde, areia desenhada).
# Cada pose dá duas camadas, com a areia a desenhar-se por código entre elas:
#   <pose>_tras.png   madeira e braços (o que fica atrás da areia)
#   <pose>_frente.png vidro vazio, cara e mãos (o que fica à frente da areia)
# Mais as formas da areia (areia_cima, areia_monte, areia_fio). Escreve em Assets.xcassets/Glassy.
# Uso: scripts/glassy-assets.ps1 (só é preciso voltar a correr se as imagens mudarem)
# As imagens originais não estão no repositório: as camadas geradas é que são o que a app usa.
$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $raiz 'Glassy2'))) {
    throw "Faltam as imagens originais em Glassy2/, que não estão no repositório. As camadas em Assets.xcassets/Glassy continuam válidas."
}
$Saida = Join-Path $raiz 'App/Resources/Assets.xcassets/Glassy'
$Largura = 490

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public class Camada {
    public int L, A;
    public float[] R, G, B, Al; // Cor sem pré-multiplicar, de 0 a 1.
    public Camada(int l, int a) {
        L = l; A = a;
        R = new float[l * a]; G = new float[l * a]; B = new float[l * a]; Al = new float[l * a];
    }
}

public static class Glassy {
    public const int W = 1194, H = 1600, CX = 620;
    // Recorte final: cabe nos braços de todas as poses.
    public const int RX = 130, RY = 170, RL = 980, RA = 1205;

    // Meia largura interior do vidro por linha (medida nas imagens). Repetida em Swift.
    static readonly double[,] Perfil = {
        {306,301},{350,301},{400,303},{450,298},{500,285},{550,263},{600,228},{650,185},
        {700,150},{750,95},{775,62},{800,100},{850,150},{900,200},{950,240},{1000,265},
        {1050,280},{1100,287},{1150,297},{1200,301},{1240,301}
    };

    public static double MeiaLargura(double y) {
        int n = Perfil.GetLength(0);
        if (y < Perfil[0, 0] || y > Perfil[n - 1, 0]) return -1;
        for (int i = 0; i < n - 1; i++) {
            if (y <= Perfil[i + 1, 0]) {
                double t = (y - Perfil[i, 0]) / (Perfil[i + 1, 0] - Perfil[i, 0]);
                return Perfil[i, 1] + (Perfil[i + 1, 1] - Perfil[i, 1]) * t;
            }
        }
        return -1;
    }

    static bool NoVidro(int x, int y) {
        double m = MeiaLargura(y);
        return m > 0 && Math.Abs(x - CX) <= m;
    }

    static double Suave(double de, double ate, double v) {
        double t = Math.Max(0, Math.Min(1, (v - de) / (ate - de)));
        return t * t * (3 - 2 * t);
    }

    // Lê para BGRA; a celebrar tem outro enquadramento e alinha-se às restantes.
    static byte[] Ler(string ficheiro, bool celebrar) {
        using (var origem = new Bitmap(ficheiro))
        using (var alvo = new Bitmap(W, H, PixelFormat.Format32bppArgb))
        using (var g = Graphics.FromImage(alvo)) {
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            if (celebrar) {
                const float s = 1.03f;
                g.DrawImage(origem, new RectangleF(CX - 745 * s, 182 - 178 * s, origem.Width * s, origem.Height * s));
            } else {
                g.DrawImage(origem, 0, 0, W, H);
            }
            var d = alvo.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var px = new byte[W * H * 4];
            Marshal.Copy(d.Scan0, px, 0, px.Length);
            alvo.UnlockBits(d);
            return px;
        }
    }

    static void Hsv(byte r, byte g, byte b, out double h, out double s, out double v) {
        int ma = Math.Max(r, Math.Max(g, b)), mi = Math.Min(r, Math.Min(g, b));
        v = ma / 255.0;
        s = ma == 0 ? 0 : (ma - mi) / (double)ma;
        if (ma == mi) { h = 0; return; }
        double c = ma - mi;
        if (ma == r) h = 60 * (((g - b) / c + 6) % 6);
        else if (ma == g) h = 60 * ((b - r) / c + 2);
        else h = 60 * ((r - g) / c + 4);
    }

    // O fundo de cada zona: mediana dos verdes saturados de uma grelha (o vidro é menos
    // saturado, por isso não entra); as células sem fundo preenchem-se pelas vizinhas.
    static float[][] Fundo(byte[] px) {
        const int C = 32;
        int cl = W / C + 1, ca = H / C + 1;
        var m = new float[3][];
        for (int k = 0; k < 3; k++) m[k] = new float[cl * ca];
        var tem = new bool[cl * ca];
        for (int cy = 0; cy < ca; cy++) for (int cx = 0; cx < cl; cx++) {
            var lr = new List<byte>(); var lg = new List<byte>(); var lb = new List<byte>();
            for (int y = cy * C; y < Math.Min(H, (cy + 1) * C); y++) for (int x = cx * C; x < Math.Min(W, (cx + 1) * C); x++) {
                int i = (y * W + x) * 4;
                double h, s, v;
                Hsv(px[i + 2], px[i + 1], px[i], out h, out s, out v);
                if (h > 148 && h < 170 && s >= 0.5) { lr.Add(px[i + 2]); lg.Add(px[i + 1]); lb.Add(px[i]); }
            }
            if (lr.Count >= C * C / 3) {
                lr.Sort(); lg.Sort(); lb.Sort();
                int j = cy * cl + cx;
                m[0][j] = lr[lr.Count / 2]; m[1][j] = lg[lg.Count / 2]; m[2][j] = lb[lb.Count / 2];
                tem[j] = true;
            }
        }
        for (bool falta = true; falta; ) {
            falta = false;
            var novo = (bool[])tem.Clone();
            for (int cy = 0; cy < ca; cy++) for (int cx = 0; cx < cl; cx++) {
                int j = cy * cl + cx;
                if (tem[j]) continue;
                float[] soma = new float[3]; int n = 0;
                for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
                    int yy = cy + dy, xx = cx + dx;
                    if (yy < 0 || xx < 0 || yy >= ca || xx >= cl || !tem[yy * cl + xx]) continue;
                    for (int k = 0; k < 3; k++) soma[k] += m[k][yy * cl + xx];
                    n++;
                }
                if (n > 0) { for (int k = 0; k < 3; k++) m[k][j] = soma[k] / n; novo[j] = true; }
                else falta = true;
            }
            tem = novo;
        }
        var f = new float[3][];
        for (int k = 0; k < 3; k++) f[k] = new float[W * H];
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            double gx = (x - C / 2.0) / C, gy = (y - C / 2.0) / C;
            int x0 = Math.Max(0, (int)Math.Floor(gx)), y0 = Math.Max(0, (int)Math.Floor(gy));
            int x1 = Math.Min(cl - 1, x0 + 1), y1 = Math.Min(ca - 1, y0 + 1);
            float tx = (float)Math.Max(0, Math.Min(1, gx - x0)), ty = (float)Math.Max(0, Math.Min(1, gy - y0));
            for (int k = 0; k < 3; k++) {
                float a = m[k][y0 * cl + x0] * (1 - tx) + m[k][y0 * cl + x1] * tx;
                float b = m[k][y1 * cl + x0] * (1 - tx) + m[k][y1 * cl + x1] * tx;
                f[k][y * W + x] = (a * (1 - ty) + b * ty) / 255f;
            }
        }
        return f;
    }

    // Tira o verde: o vidro fica translúcido de verdade e o que é opaco (quente, escuro ou
    // branco dos olhos) fica opaco, com a orla suave.
    public static Camada Matte(string ficheiro, bool celebrar, double[][] olhos) {
        var px = Ler(ficheiro, celebrar);
        var f = Fundo(px);
        var c = new Camada(W, H);
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            int j = y * W + x, i = j * 4;
            float r = px[i + 2] / 255f, g = px[i + 1] / 255f, b = px[i] / 255f;
            float fr = f[0][j], fg = f[1][j], fb = f[2][j];
            double ca = Math.Max(Dif(r, fr), Math.Max(Dif(g, fg), Dif(b, fb)));
            if (ca < 0.035) ca = 0;
            double v = Math.Max(r, Math.Max(g, b));
            double opaco = Math.Max(Suave(-0.024, 0.086, r - g), Suave(0.45, 0.30, v));
            foreach (var o in olhos) {
                double dx = (x - o[0]) / o[2], dy = (y - o[1]) / o[3];
                double d = Math.Sqrt(dx * dx + dy * dy);
                opaco = Math.Max(opaco, Suave(1.0, 0.96, d));
            }
            // Halos e brilhos à volta do vidro eram do fundo verde: fora do contorno, só o opaco.
            double meia = MeiaLargura(y);
            if (opaco < 0.2 && (meia < 0 || Math.Abs(x - CX) > meia + 12)) ca = 0;
            double a = Math.Max(ca, opaco);
            c.Al[j] = (float)a;
            if (a > 0.001) {
                // O vidro não tem cor própria: a recuperada dá o complementar do verde (rosa).
                // Fica branco-menta onde clareia o fundo e sombra onde o escurece.
                bool clareia = r > fr;
                double peso = Suave(0.2, 0.8, opaco);
                c.R[j] = Lim(Mistura(clareia ? 0.78 : 0.10, (r - (1 - a) * fr) / a, peso));
                c.G[j] = Lim(Mistura(clareia ? 0.92 : 0.25, (g - (1 - a) * fg) / a, peso));
                c.B[j] = Lim(Mistura(clareia ? 0.90 : 0.22, (b - (1 - a) * fb) / a, peso));
            }
        }
        Limpar(c);
        return c;
    }

    static double Dif(float v, float f) { return v > f ? (v - f) / Math.Max(0.001f, 1 - f) : (f - v) / Math.Max(0.001f, f); }
    static float Lim(double v) { return (float)Math.Max(0, Math.Min(1, v)); }
    static double Mistura(double a, double b, double t) { return a + (b - a) * t; }

    // Fica só o Glassy: o que não liga à madeira (confetis, brilhos) e a sombra do chão saem.
    static void Limpar(Camada c) {
        var visto = new bool[W * H];
        var pilha = new Stack<int>();
        pilha.Push(240 * W + CX);
        visto[240 * W + CX] = true;
        while (pilha.Count > 0) {
            int j = pilha.Pop();
            int x = j % W, y = j / W;
            foreach (int n in new[] { x > 0 ? j - 1 : -1, x < W - 1 ? j + 1 : -1, y > 0 ? j - W : -1, y < H - 1 ? j + W : -1 }) {
                if (n >= 0 && !visto[n] && c.Al[n] > 0.09) { visto[n] = true; pilha.Push(n); }
            }
        }
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            int j = y * W + x;
            bool sombra = y > 1368 || (y > 1240 && (x < 208 || x > 1034));
            if (!visto[j] || sombra) c.Al[j] = 0;
        }
    }

    // A areia desenhada: dentro do vidro, quente e clara, sem cara nem mãos.
    public static bool[] MascaraAreia(string ficheiro, bool celebrar, Camada c, double[][] olhos, int faixaGraos) {
        var px = Ler(ficheiro, celebrar);
        var m = new bool[W * H];
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            int j = y * W + x, i = j * 4;
            if (!NoVidro(x, y) || c.Al[j] < 0.15) continue;
            byte r = px[i + 2], g = px[i + 1], b = px[i];
            if (r <= g) continue;
            double h, s, v;
            Hsv(r, g, b, out h, out s, out v);
            bool dentroOlho = false;
            foreach (var o in olhos) {
                double dx = (x - o[0]) / o[2], dy = (y - o[1]) / o[3];
                if (dx * dx + dy * dy < 1) dentroOlho = true;
            }
            if (dentroOlho) continue;
            // A areia em sombra chega aos vermelhos; os braços e as mãos têm o mesmo tom, por
            // isso separa-se pelo sítio: acima do monte, fora da faixa dos grãos, não há areia,
            // e junto à parede do vidro só conta o tom claro da areia.
            double desvio = Math.Abs(x - CX), minimo;
            if (y < 790) minimo = 15;
            else if (y >= 1040) minimo = desvio > MeiaLargura(y) - 25 ? 29 : 18;
            else if (desvio <= faixaGraos) minimo = 18;
            else if (y >= 1010 && desvio <= 110) minimo = 29;
            else continue;
            if (h >= minimo && h <= 58 && v > 0.4) m[j] = true;
        }
        // Alarga 3 px para levar a orla, sem tocar no que é escuro ou rosa (boca e bochechas).
        for (int passo = 0; passo < 3; passo++) {
            var novo = (bool[])m.Clone();
            for (int y = 1; y < H - 1; y++) for (int x = 1; x < W - 1; x++) {
                int j = y * W + x;
                if (m[j] || !NoVidro(x, y)) continue;
                if (!(m[j - 1] || m[j + 1] || m[j - W] || m[j + W])) continue;
                int i = j * 4;
                double h, s, v;
                Hsv(px[i + 2], px[i + 1], px[i], out h, out s, out v);
                bool protegido = v < 0.5 || h > 330 || h < 15;
                if (!protegido) novo[j] = true;
            }
            m = novo;
        }
        return m;
    }

    // Uma linha de vidro limpo, em função da posição relativa (-1 a 1) na largura do bolbo.
    public static float[][] Molde(Camada c, int y0, int y1) {
        const int N = 400;
        var soma = new float[4][];
        for (int k = 0; k < 4; k++) soma[k] = new float[N + 1];
        var n = new int[N + 1];
        for (int y = y0; y <= y1; y++) {
            double m = MeiaLargura(y);
            for (int x = CX - (int)m; x <= CX + (int)m; x++) {
                int u = (int)Math.Round(((x - CX) / m + 1) / 2 * N);
                int j = y * W + x;
                float a = c.Al[j];
                if (c.R[j] > c.G[j]) continue; // Braços vistos pelo vidro não são vidro.
                soma[0][u] += c.R[j] * a; soma[1][u] += c.G[j] * a; soma[2][u] += c.B[j] * a; soma[3][u] += a;
                n[u]++;
            }
        }
        for (int u = 0; u <= N; u++) {
            if (n[u] == 0) continue;
            float a = soma[3][u];
            if (a > 0.0001f) { soma[0][u] /= a; soma[1][u] /= a; soma[2][u] /= a; }
            soma[3][u] = a / n[u];
        }
        // Reflexos suaves e mais leves: por cima da areia, o vidro cheio tirava-lhe a cor.
        var alfa = new float[N + 1];
        for (int u = 0; u <= N; u++) {
            float total = 0; int conta = 0;
            for (int k = Math.Max(0, u - 7); k <= Math.Min(N, u + 7); k++) { total += soma[3][k]; conta++; }
            alfa[u] = total / conta * 0.7f;
        }
        soma[3] = alfa;
        return soma;
    }

    // Troca a areia por vidro vazio. O vidro à volta também, a partir de `desdeY`: se não, o
    // sítio onde estava o monte nota-se, porque o vidro original tem outra densidade.
    public static void Esvaziar(Camada c, bool[] areia, float[][] cima, float[][] baixo, int desdeY) {
        const int N = 400;
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            int j = y * W + x;
            bool vidro = y >= desdeY && NoVidro(x, y) && c.Al[j] < 0.85 && c.R[j] <= c.G[j];
            if (!areia[j] && !vidro) continue;
            double m = MeiaLargura(y);
            int u = (int)Math.Round(((x - CX) / m + 1) / 2 * N);
            u = Math.Max(0, Math.Min(N, u));
            var t = y < 775 ? cima : baixo;
            c.R[j] = t[0][u]; c.G[j] = t[1][u]; c.B[j] = t[2][u]; c.Al[j] = t[3][u];
        }
    }

    // Sem o verde atrás, o vidro desaparecia em fundos claros: ganha corpo e uma parede escura.
    public static void Definir(Camada c) {
        for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
            int j = y * W + x;
            if (!NoVidro(x, y) || c.Al[j] > 0.9) continue;
            double a = Math.Max(c.Al[j], 0.10);
            double parede = MeiaLargura(y) - Math.Abs(x - CX);
            double rim = 0.42 * (1 - Suave(0, 8, parede));
            double total = rim + a * (1 - rim);
            c.R[j] = Lim((0.30 * rim + c.R[j] * a * (1 - rim)) / total);
            c.G[j] = Lim((0.50 * rim + c.G[j] * a * (1 - rim)) / total);
            c.B[j] = Lim((0.50 * rim + c.B[j] * a * (1 - rim)) / total);
            c.Al[j] = (float)total;
        }
    }

    // Separa pelo contorno do vidro, recorta ao enquadramento comum e reduz.
    public static void Gravar(Camada c, string ficheiro, bool frente, int largura) {
        int alt = (int)Math.Round(largura * (double)RA / RL);
        using (var total = new Bitmap(RL, RA, PixelFormat.Format32bppArgb)) {
            var d = total.LockBits(new Rectangle(0, 0, RL, RA), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            var px = new byte[RL * RA * 4];
            for (int y = 0; y < RA; y++) for (int x = 0; x < RL; x++) {
                int sx = x + RX, sy = y + RY, j = sy * W + sx, i = (y * RL + x) * 4;
                if (NoVidro(sx, sy) != frente) continue;
                px[i] = (byte)(c.B[j] * 255); px[i + 1] = (byte)(c.G[j] * 255);
                px[i + 2] = (byte)(c.R[j] * 255); px[i + 3] = (byte)(c.Al[j] * 255);
            }
            Marshal.Copy(px, 0, d.Scan0, px.Length);
            total.UnlockBits(d);
            using (var reduzida = new Bitmap(largura, alt, PixelFormat.Format32bppArgb))
            using (var g = Graphics.FromImage(reduzida)) {
                g.CompositingMode = CompositingMode.SourceCopy;
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.DrawImage(total, new Rectangle(0, 0, largura, alt));
                reduzida.Save(ficheiro, ImageFormat.Png);
            }
        }
    }

    // Recorta uma forma de areia do fundo liso. A diferença entre vermelho e verde mede bem a
    // cobertura, por isso os grãos soltos ficam com a orla certa.
    public static void Forma(string ficheiro, Rectangle zona, string saida, int largura) {
        using (var origem = new Bitmap(ficheiro))
        using (var src = origem.Clone(new Rectangle(0, 0, origem.Width, origem.Height), PixelFormat.Format32bppArgb))
        using (var dst = new Bitmap(zona.Width, zona.Height, PixelFormat.Format32bppArgb)) {
            Color c = src.GetPixel(12, 12);
            float fr = c.R / 255f, fg = c.G / 255f, fb = c.B / 255f;
            var ds = src.LockBits(new Rectangle(0, 0, src.Width, src.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
            var dd = dst.LockBits(new Rectangle(0, 0, zona.Width, zona.Height), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            var ps = new byte[src.Width * src.Height * 4];
            var pd = new byte[zona.Width * zona.Height * 4];
            Marshal.Copy(ds.Scan0, ps, 0, ps.Length);
            for (int y = 0; y < zona.Height; y++) for (int x = 0; x < zona.Width; x++) {
                int i = ((y + zona.Y) * src.Width + x + zona.X) * 4, o = (y * zona.Width + x) * 4;
                float r = ps[i + 2] / 255f, g = ps[i + 1] / 255f, b = ps[i] / 255f;
                double a = Math.Max(0, Math.Min(1, ((r - g) - (fr - fg)) / 0.5 - 0.08));
                if (a <= 0) continue;
                pd[o + 2] = (byte)(Lim((r - (1 - a) * fr) / a) * 255);
                pd[o + 1] = (byte)(Lim((g - (1 - a) * fg) / a) * 255);
                pd[o] = (byte)(Lim((b - (1 - a) * fb) / a) * 255);
                pd[o + 3] = (byte)(a * 255);
            }
            Marshal.Copy(pd, 0, dd.Scan0, pd.Length);
            src.UnlockBits(ds);
            dst.UnlockBits(dd);
            using (var reduzida = new Bitmap(largura, largura * zona.Height / zona.Width, PixelFormat.Format32bppArgb))
            using (var g = Graphics.FromImage(reduzida)) {
                g.CompositingMode = CompositingMode.SourceCopy;
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.DrawImage(dst, new Rectangle(0, 0, reduzida.Width, reduzida.Height));
                reduzida.Save(saida, ImageFormat.Png);
            }
        }
    }


}
'@

$utf8 = New-Object System.Text.UTF8Encoding($false)
$info = '"info": { "author": "xcode", "version": 1 }'
New-Item -ItemType Directory -Force $Saida | Out-Null
[System.IO.File]::WriteAllText((Join-Path $Saida 'Contents.json'), "{ $info }`n", $utf8)

# Cria o conjunto de imagem no catálogo e devolve onde gravar o PNG.
function Conjunto([string]$nome) {
    $dir = Join-Path $Saida "glassy_$nome.imageset"
    New-Item -ItemType Directory -Force $dir | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $dir 'Contents.json'), "{ `"images`": [ { `"filename`": `"$nome.png`", `"idiom`": `"universal`" } ], $info }`n", $utf8)
    return (Join-Path $dir "$nome.png")
}

$pasta = Join-Path $raiz 'Glassy2'
$sem = [double[][]]@()
$olhosNormais = [double[][]]@(@(506.0, 520.0, 63.0, 64.0), @(734.0, 520.0, 63.0, 64.0))
# No ko também as bochechas: estão tão pálidas que pareciam vidro.
$olhosKo = [double[][]]@(@(508.0, 529.0, 59.0, 59.0), @(725.0, 532.0, 59.0, 59.0), @(442.0, 628.0, 47.0, 28.0), @(797.0, 628.0, 47.0, 28.0))

# Faixa: até onde os grãos a cair se afastam do centro sem chegar às mãos.
# VidroDesde: a partir de que linha o vidro é o limpo; no ko, abaixo das rachas.
$poses = @(
    @{ Nome = 'feliz';      Fich = 'default.png';             Celebrar = $false; Olhos = $olhosNormais; Faixa = 95; VidroDesde = 0 },
    @{ Nome = 'celebrar';   Fich = 'default_eyes_closed.png'; Celebrar = $true;  Olhos = $sem;          Faixa = 95; VidroDesde = 0 },
    @{ Nome = 'preocupado'; Fich = 'preocupado.png';          Celebrar = $false; Olhos = $olhosNormais; Faixa = 55; VidroDesde = 0 },
    @{ Nome = 'ko';         Fich = 'ko.png';                  Celebrar = $false; Olhos = $olhosKo;      Faixa = 95; VidroDesde = 790 }
)

# O vidro limpo vem de onde não há areia, grãos nem rachas: por cima da cara no preocupado e
# por cima do monte no ko (o único sem grãos a cair).
$refCima = [Glassy]::Matte((Join-Path $pasta 'preocupado.png'), $false, $olhosNormais)
$refBaixo = [Glassy]::Matte((Join-Path $pasta 'ko.png'), $false, $olhosKo)
$moldeCima = [Glassy]::Molde($refCima, 335, 385)
$moldeBaixo = [Glassy]::Molde($refBaixo, 955, 1000)

foreach ($p in $poses) {
    $fich = Join-Path $pasta $p.Fich
    $c = [Glassy]::Matte($fich, $p.Celebrar, $p.Olhos)
    $areia = [Glassy]::MascaraAreia($fich, $p.Celebrar, $c, $p.Olhos, $p.Faixa)
    [Glassy]::Esvaziar($c, $areia, $moldeCima, $moldeBaixo, $p.VidroDesde)
    [Glassy]::Definir($c)
    [Glassy]::Gravar($c, (Conjunto "$($p.Nome)_tras"), $false, $Largura)
    [Glassy]::Gravar($c, (Conjunto "$($p.Nome)_frente"), $true, $Largura)
    Write-Output "$($p.Nome): feito"
}

# As formas da areia, cada uma da imagem onde está melhor.
[Glassy]::Forma((Join-Path $pasta 'areia full.png'), (New-Object System.Drawing.Rectangle 155, 75, 600, 575), (Conjunto 'areia_cima'), 320)
[Glassy]::Forma((Join-Path $pasta 'areia_default.png'), (New-Object System.Drawing.Rectangle 430, 1290, 720, 455), (Conjunto 'areia_monte'), 310)
# Sem o gargalo nem o monte da imagem: o fio repete-se a correr, e estes não podiam repetir-se.
[Glassy]::Forma((Join-Path $pasta 'areia a cair.png'), (New-Object System.Drawing.Rectangle 215, 150, 435, 800), (Conjunto 'areia_fio'), 130)

