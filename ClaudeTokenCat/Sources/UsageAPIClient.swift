import Foundation

// MARK: - Usage API Response Model

struct UsageBucket: Codable {
    let utilization: Double
    let resets_at: String?
}

struct UsageResponse: Codable {
    let five_hour: UsageBucket?
    let seven_day: UsageBucket?
    let seven_day_opus: UsageBucket?
}

// MARK: - API Errors

enum UsageAPIError: Error, LocalizedError {
    case unauthorized
    case forbidden
    case networkError(Error)
    case decodingError(Error)
    case unexpectedStatus(Int)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Authentication expired. Run `claude login` to reconnect."
        case .forbidden:
            return "Access denied. Check your Claude subscription."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError:
            return "Unexpected API response format."
        case .unexpectedStatus(let code):
            return "API returned status \(code)."
        }
    }
}

// MARK: - API Client

struct UsageAPIClient {

    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetchUsage(accessToken: String) async throws -> UsageResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/2.1.5", forHTTPHeaderField: "User-Agent")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageAPIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageAPIError.networkError(URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw UsageAPIError.unauthorized
        case 403:
            throw UsageAPIError.forbidden
        default:
            throw UsageAPIError.unexpectedStatus(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            throw UsageAPIError.decodingError(error)
        }
    }
}
