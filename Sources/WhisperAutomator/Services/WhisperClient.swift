import Foundation

enum WhisperClient {
    private static let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    static func transcribe(fileURL: URL, language: TranscriptionLanguage) async throws -> String {
        guard let apiKey = KeychainStore.loadAPIKey(), !apiKey.isEmpty else {
            throw WhisperError.missingAPIKey
        }

        let boundary = "Boundary-\(UUID().uuidString)"

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let audioData = try Data(contentsOf: fileURL)
        let body = buildMultipartBody(
            boundary: boundary,
            audioData: audioData,
            filename: fileURL.lastPathComponent,
            language: language
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

    private static func buildMultipartBody(
        boundary: String,
        audioData: Data,
        filename: String,
        language: TranscriptionLanguage
    ) -> Data {
        var body = Data()

        func appendField(name: String, value: String) {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }

        appendField(name: "model", value: "whisper-1")
        appendField(name: "language", value: language.rawValue)

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
