import AppKit
import AuthenticationServices
import CryptoKit
import Foundation
import Network

@MainActor
final class GoogleOAuthService {
    private let session: URLSession
    private let store: SharedStore
    private var cachedTokens: OAuthTokens?
    private var webAuthSession: ASWebAuthenticationSession?
    private let presentationContextProvider = WebAuthenticationPresentationContextProvider()

    init(session: URLSession = .shared, store: SharedStore) {
        self.session = session
        self.store = store
        self.cachedTokens = store.loadTokens()
    }

    var configuredClientID: String {
        store.loadOAuthClientID()
    }

    var configuredClientSecret: String {
        store.loadOAuthClientSecret()
    }

    var debugConfigurationSummary: String {
        let clientID = configuredClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = configuredClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let idStatus = clientID.isEmpty ? "未設定" : "設定済み"
        let secretStatus = secret.isEmpty ? "なし" : "あり"
        #if DEBUG
        let suffix = clientID.isEmpty ? "" : " (末尾: \(String(clientID.suffix(8))))"
        return "client_id: \(idStatus)\(suffix) / secret: \(secretStatus)"
        #else
        return "client_id: \(idStatus) / secret: \(secretStatus)"
        #endif
    }

    func signIn() async throws -> OAuthTokens {
        let clientID = configuredClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = configuredClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else {
            throw OAuthError.missingClientID
        }

        let verifier = Self.randomString()
        let challenge = Self.sha256(verifier)
        let state = Self.randomString()
        let redirectServer = try LoopbackRedirectServer()
        let redirectURI = try await redirectServer.start()

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            .init(name: "client_id", value: clientID),
            .init(name: "redirect_uri", value: redirectURI),
            .init(name: "response_type", value: "code"),
            .init(name: "scope", value: "https://www.googleapis.com/auth/tasks"),
            .init(name: "code_challenge", value: challenge),
            .init(name: "code_challenge_method", value: "S256"),
            .init(name: "access_type", value: "offline"),
            .init(name: "prompt", value: "consent"),
            .init(name: "state", value: state)
        ]

        try startAuthenticationSession(url: components.url!, redirectServer: redirectServer)
        let callbackURL = try await redirectServer.waitForRedirect()
        webAuthSession?.cancel()
        webAuthSession = nil

        guard
            let callback = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
            callback.queryItems?.first(where: { $0.name == "state" })?.value == state,
            let code = callback.queryItems?.first(where: { $0.name == "code" })?.value
        else {
            throw OAuthError.invalidCallback
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]
        let requestBody = clientSecret.isEmpty ? body : body.merging(["client_secret": clientSecret]) { current, _ in current }
        request.httpBody = requestBody
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let data = try await performTokenRequest(request, context: "authorization_code")
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let tokens = OAuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiryDate: tokenResponse.expiresIn.map { Date.now.addingTimeInterval(TimeInterval($0)) }
        )
        cachedTokens = tokens
        store.saveTokens(tokens)
        return tokens
    }

    private func startAuthenticationSession(url: URL, redirectServer: LoopbackRedirectServer) throws {
        let completion: ASWebAuthenticationSession.CompletionHandler = { [weak self] callbackURL, error in
            DispatchQueue.main.async {
                self?.webAuthSession = nil
                if let callbackURL {
                    Task { await redirectServer.finish(with: .success(callbackURL)) }
                    return
                }
                if let error = error as? ASWebAuthenticationSessionError,
                   error.code == .canceledLogin {
                    Task { await redirectServer.finish(with: .failure(OAuthError.cancelled)) }
                    return
                }
                if let error {
                    Task { await redirectServer.finish(with: .failure(error)) }
                    return
                }
                Task { await redirectServer.finish(with: .failure(OAuthError.invalidCallback)) }
            }
        }

        let authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: nil,
            completionHandler: completion
        )
        authSession.presentationContextProvider = presentationContextProvider
        authSession.prefersEphemeralWebBrowserSession = false
        webAuthSession = authSession

        guard authSession.start() else {
            webAuthSession = nil
            throw OAuthError.unableToOpenBrowser
        }
    }

    func signOut() {
        cachedTokens = nil
        store.saveTokens(nil)
    }

    func loadTokens() -> OAuthTokens? {
        if let cachedTokens {
            return cachedTokens
        }
        let tokens = store.loadTokens()
        cachedTokens = tokens
        return tokens
    }

    func refreshIfNeeded() async throws -> OAuthTokens? {
        guard let tokens = loadTokens() else { return nil }
        guard let refreshToken = tokens.refreshToken else { return tokens }
        // Refresh token if less than 30 seconds until expiry to keep session alive
        if let expiry = tokens.expiryDate, expiry > Date.now.addingTimeInterval(30) {
            return tokens
        }

        let clientID = configuredClientID
        let clientSecret = configuredClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else { throw OAuthError.missingClientID }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        let requestBody = clientSecret.isEmpty ? body : body.merging(["client_secret": clientSecret]) { current, _ in current }
        request.httpBody = requestBody
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)

        let data = try await performTokenRequest(request, context: "refresh_token")
        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
        let nextTokens = OAuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: refreshToken,
            expiryDate: tokenResponse.expiresIn.map { Date.now.addingTimeInterval(TimeInterval($0)) }
        )
        cachedTokens = nextTokens
        store.saveTokens(nextTokens)
        return nextTokens
    }

    private func performTokenRequest(_ request: URLRequest, context: String) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            return data
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let googleError = try? JSONDecoder().decode(GoogleOAuthErrorResponse.self, from: data)
            throw OAuthError.serverError(
                code: googleError?.error,
                message: googleError?.errorDescription ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
                context: context,
                clientID: configuredClientID
            )
        }
        return data
    }

    private static func randomString(length: Int = 64) -> String {
        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return String((0..<length).compactMap { _ in charset.randomElement() })
    }

    private static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return Data(digest).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private actor LoopbackRedirectServer {
    private let listener: NWListener
    private var continuation: CheckedContinuation<URL, Error>?

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
    }

    func start() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            listener.stateUpdateHandler = { [listener] state in
                switch state {
                case .ready:
                    guard let port = listener.port?.rawValue else {
                        continuation.resume(throwing: OAuthError.invalidRedirectServer)
                        return
                    }
                    continuation.resume(returning: "http://127.0.0.1:\(port)/oauth2callback")
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { await self?.handle(connection: connection) }
            }
            listener.start(queue: .main)
        }
    }

    func waitForRedirect() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func finish(with result: Result<URL, Error>) {
        guard let activeContinuation = continuation else { return }
        continuation = nil
        switch result {
        case .success(let callbackURL):
            activeContinuation.resume(returning: callbackURL)
        case .failure(let error):
            activeContinuation.resume(throwing: error)
        }
        listener.cancel()
    }

    private func handle(connection: NWConnection) async {
        connection.start(queue: .main)
        do {
            let requestData = try await receive(on: connection)
            guard
                let request = String(data: requestData, encoding: .utf8),
                let firstLine = request.components(separatedBy: "\r\n").first,
                firstLine.hasPrefix("GET "),
                let path = firstLine.split(separator: " ").dropFirst().first
            else {
                try await respond(on: connection, status: "400 Bad Request", body: "Invalid callback")
                finish(with: .failure(OAuthError.invalidCallback))
                return
            }

            let callbackURL = URL(string: "http://127.0.0.1\(path)")!
            try await respond(
                on: connection,
                status: "200 OK",
                body: "Authentication complete. You can close this window."
            )
            finish(with: .success(callbackURL))
        } catch {
            finish(with: .failure(error))
        }
        connection.cancel()
    }

    private func receive(on connection: NWConnection) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: data ?? Data())
            }
        }
    }

    private func respond(on connection: NWConnection, status: String, body: String) async throws {
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: text/plain; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            connection.send(content: response.data(using: .utf8), completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            })
        }
    }
}

private final class WebAuthenticationPresentationContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        NSApplication.shared.keyWindow
            ?? NSApplication.shared.mainWindow
            ?? NSApplication.shared.windows.first { $0.isVisible }
            ?? ASPresentationAnchor()
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct GoogleOAuthErrorResponse: Decodable {
    let error: String?
    let errorDescription: String?

    private enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

enum OAuthError: Error, LocalizedError {
    case missingClientID
    case invalidCallback
    case invalidRedirectServer
    case unableToOpenBrowser
    case cancelled
    case serverError(code: String?, message: String, context: String, clientID: String)

    var requiresReauthentication: Bool {
        guard case .serverError(let code, _, let context, _) = self else {
            return false
        }
        return context == "refresh_token" && code == "invalid_grant"
    }

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            return "OAuth Client ID が未設定です。設定画面で入力してください。"
        case .invalidCallback:
            return "Google ログイン後の戻り先を確認できませんでした。もう一度お試しください。"
        case .invalidRedirectServer:
            return "ローカル認証サーバーを起動できませんでした。アプリを再起動してもう一度お試しください。"
        case .unableToOpenBrowser:
            return "Google ログイン用のブラウザを開けませんでした。"
        case .cancelled:
            return "Google ログインがキャンセルされました。"
        case .serverError(_, let message, let context, _):
            if requiresReauthentication {
                return "Google ログインの有効期限が切れました。もう一度ログインしてください。"
            }
            if message.contains("client_secret is missing") {
                return "Google ログインで client_secret missing が返りました (flow=\(context))。Desktop クライアントが正しく設定されているか確認してください。"
            }
            #if DEBUG
            return "Google ログインでエラーが発生しました: \(message) (flow=\(context))"
            #else
            return "Google ログインでエラーが発生しました。もう一度お試しください。"
            #endif
        }
    }
}
