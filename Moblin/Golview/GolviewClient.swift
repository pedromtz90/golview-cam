import Foundation

// Simple HTTP client for the Golview API (https://golview.mx).
enum GolviewClient {
    private static let baseUrl = "https://golview.mx/api/v1"

    struct Session: Codable {
        let id: String
    }

    struct JoinResponse: Codable {
        let deviceToken: String
        let session: Session
    }

    struct LiveConfig: Codable {
        let liveEnabled: Bool
        let isLive: Bool
        let publishSrtUrl: String?
        let viewerHlsUrl: String?
    }

    private struct JoinRequest: Codable {
        let joinToken: String
        let role: String
        let deviceModel: String
    }

    static func join(joinToken: String, deviceModel: String) async throws -> JoinResponse {
        guard let url = URL(string: "\(baseUrl)/sessions/join") else {
            throw "Invalid Golview API URL"
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setContentType("application/json")
        request.httpBody = try JSONEncoder().encode(JoinRequest(
            joinToken: joinToken,
            role: "CAMERA",
            deviceModel: deviceModel
        ))
        return try await perform(request: request)
    }

    static func fetchLiveConfig(deviceToken: String) async throws -> LiveConfig {
        guard let url = URL(string: "\(baseUrl)/devices/live-config") else {
            throw "Invalid Golview API URL"
        }
        var request = URLRequest(url: url)
        request.setValue(deviceToken, forHTTPHeaderField: "x-device-token")
        return try await perform(request: request)
    }

    private static func perform<T: Decodable>(request: URLRequest) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response.http else {
            throw "Not an HTTP response"
        }
        guard response.isSuccessful else {
            if response.isNotFound || response.isUnauthorized {
                throw "Código inválido o sesión no encontrada"
            }
            throw "Error del servidor Golview (HTTP \(response.statusCode))"
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
