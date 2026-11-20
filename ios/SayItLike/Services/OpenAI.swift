import Foundation

nonisolated struct OpenAIError: LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
}

/// Minimal OpenAI client: the judge (Responses API), the announcer (speech) and a key check.
/// The key lives in the Keychain and is only ever placed in the Authorization header.
nonisolated enum OpenAI {
    static let base = URL(string: "https://api.openai.com/v1/")!

    static func request(_ path: String, apiKey: String, json: [String: Any]? = nil,
                        timeout: TimeInterval) throws -> URLRequest {
        var req = URLRequest(url: base.appendingPathComponent(path), timeoutInterval: timeout)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        if let json {
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: json)
        }
        return req
    }

    /// Turns a failed response into a readable message, using OpenAI's own error text when present.
    static func failure(_ data: Data, status: Int) -> OpenAIError {
        let body = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let message = (body?["error"] as? [String: Any])?["message"] as? String
        switch status {
        case 401: return OpenAIError(message: message ?? "The OpenAI API key was not accepted.")
        case 429: return OpenAIError(message: message ?? "OpenAI is rate limiting requests. Wait a moment and try again.")
        default: return OpenAIError(message: message ?? "OpenAI returned HTTP \(status).")
        }
    }

    static func send(_ req: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw OpenAIError(message: "No internet connection.")
        } catch let error as URLError where error.code == .timedOut {
            throw OpenAIError(message: "OpenAI took too long to answer.")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw failure(data, status: status) }
        return data
    }

    /// Checks that a key works by listing models.
    @concurrent static func checkKey(_ apiKey: String) async throws {
        _ = try await send(request("models", apiKey: apiKey, timeout: 15))
    }

    /// Generates announcer speech as MP3 data.
    @concurrent static func speech(text: String, voice: String, model: String, instructions: String,
                                   apiKey: String) async throws -> Data {
        var json: [String: Any] = ["model": model, "voice": voice, "input": text, "response_format": "mp3"]
        // Older tts-1 models don't accept delivery instructions.
        if !model.hasPrefix("tts-1") { json["instructions"] = instructions }
        return try await send(request("audio/speech", apiKey: apiKey, json: json, timeout: 20))
    }
}
