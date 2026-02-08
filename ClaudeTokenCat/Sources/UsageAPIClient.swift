import Foundation

// MARK: - Usage API Response Model

struct UsageBucket: Codable {
    let utilization: Double
    let resets_at: String?
}

struct ExtraUsageBucket: Codable {
    let is_enabled: Bool
    let monthly_limit: Int?
    let used_credits: Double?
    let utilization: Double?
}

struct UsageResponse: Codable {
    let five_hour: UsageBucket?
    let seven_day: UsageBucket?
    let extra_usage: ExtraUsageBucket?
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

// MARK: - Profile API Response Model

struct ProfileAccount: Codable {
    let email: String
}

struct ProfileOrganization: Codable {
    let organization_type: String?
}

struct ProfileResponse: Codable {
    let account: ProfileAccount
    let organization: ProfileOrganization?
}

// MARK: - API Client

struct UsageAPIClient {

    private static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let profileEndpoint = URL(string: "https://api.anthropic.com/api/oauth/profile")!

    private static func authorizedRequest(url: URL, accessToken: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("claude-code/2.1.5", forHTTPHeaderField: "User-Agent")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        return request
    }

    private static func performRequest(_ request: URLRequest) async throws -> Data {
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
            return data
        case 401:
            throw UsageAPIError.unauthorized
        case 403:
            throw UsageAPIError.forbidden
        default:
            throw UsageAPIError.unexpectedStatus(httpResponse.statusCode)
        }
    }

    static func fetchUsage(accessToken: String) async throws -> UsageResponse {
        let request = authorizedRequest(url: endpoint, accessToken: accessToken)
        let data = try await performRequest(request)
        do {
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            throw UsageAPIError.decodingError(error)
        }
    }

    static func fetchProfile(accessToken: String) async throws -> ProfileResponse {
        let request = authorizedRequest(url: profileEndpoint, accessToken: accessToken)
        let data = try await performRequest(request)
        do {
            return try JSONDecoder().decode(ProfileResponse.self, from: data)
        } catch {
            throw UsageAPIError.decodingError(error)
        }
    }
}
