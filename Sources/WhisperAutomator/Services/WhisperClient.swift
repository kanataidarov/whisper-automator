import Foundation

enum WhisperClient {
    private static let transcriptionEndpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
    private static let chatCompletionsEndpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    static func transcribeAndTranslate(fileURL: URL, targetLanguage: TranscriptionLanguage) async throws -> String {
        guard let apiKey = KeychainStore.loadAPIKey(), !apiKey.isEmpty else {
            throw WhisperError.missingAPIKey
        }

        let transcribedText = try await transcribeAudio(fileURL: fileURL, apiKey: apiKey)
        guard !transcribedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return transcribedText
        }

        return try await translate(text: transcribedText, targetLanguage: targetLanguage, apiKey: apiKey)
    }

    private static func transcribeAudio(fileURL: URL, apiKey: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: transcriptionEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let audioData = try Data(contentsOf: fileURL)
        let body = buildMultipartBody(
            boundary: boundary,
            audioData: audioData,
            filename: fileURL.lastPathComponent
        )
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhisperError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return result.text
    }

    private static func translate(
        text: String,
        targetLanguage: TranscriptionLanguage,
        apiKey: String
    ) async throws -> String {
        var request = URLRequest(url: chatCompletionsEndpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let payload = ChatCompletionRequest(
            model: "gpt-4o-mini",
            temperature: 0,
            messages: [
                .init(
                    role: "system",
                    content: """
                    You are a translation engine.
                    Translate the user's text into \(targetLanguage.translationTargetName).
                    Keep meaning, punctuation, and paragraph breaks.
                    Return only the translated text.
                    """
                ),
                .init(role: "user", content: text),
            ]
        )

        request.httpBody = try JSONEncoder().encode(payload)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhisperError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let result = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let translated = result.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !translated.isEmpty else {
            throw WhisperError.invalidResponse
        }

        return translated
    }

    private static func buildMultipartBody(
        boundary: String,
        audioData: Data,
        filename: String
    ) -> Data {
        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        appendField(name: "model", value: "whisper-1")

        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: audio/m4a\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        body.append("--\(boundary)--\r\n")
        return body
    }
}

private struct TranscriptionResponse: Decodable {
    let text: String
}

private struct ChatCompletionRequest: Encodable {
    let model: String
    let temperature: Double
    let messages: [Message]

    struct Message: Encodable {
        let role: String
        let content: String
    }
}

private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message
    }

    struct Message: Decodable {
        let content: String?
    }
}

enum WhisperError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OpenAI API key not configured. Set it in Settings."
        case .invalidResponse:
            "Received an invalid response from the server."
        case .apiError(let code, let message):
            "API error (\(code)): \(message)"
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
