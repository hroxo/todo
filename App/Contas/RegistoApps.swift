/// Identificadores da app registada na Google Cloud e no Microsoft Entra (Azure), para a
/// Melhoria 7. Não são segredos: uma app nativa usa OAuth com PKCE, sem segredo de cliente,
/// por isso podem ficar no repositório público. Vazio: a conta aparece "por configurar".
enum RegistoApps {
    /// Google Cloud › APIs e serviços › Credenciais › ID de cliente OAuth do tipo iOS
    /// ("123-abc.apps.googleusercontent.com").
    static let googleClientId = ""
    /// Microsoft Entra › Registos de aplicações › ID da aplicação (cliente), com o retorno
    /// `todo-hugo://auth` em "Aplicações móveis e de ambiente de trabalho".
    static let microsoftClientId = ""
}
