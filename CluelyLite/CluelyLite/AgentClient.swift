import Foundation

struct AgentClient {
    struct AgentError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    struct Result {
        let message: String
        let tool: Tool?
        let rawData: Data
    }

    struct Tool: Decodable {
        let action: ToolAction
        let target: String?
        let text: String?
    }

    enum ToolAction: String, Decodable {
        case answer
        case click
        case type
        case focus
    }

    func send(instruction: String, snapshot: [[String: Any]]? = nil) async throws -> Result {
        guard let url = URL(string: "http://127.0.0.1:8765/command") else {
            throw AgentError(message: "Bad URL")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15
        req.httpBody = try encodePayload(instruction: instruction, snapshot: snapshot)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AgentError(message: "Agent returned an invalid response")
        }

        if http.statusCode != 200 {
            if let message = extractMessage(from: data) {
                throw AgentError(message: message)
            }
            throw AgentError(message: "Agent HTTP error (status \(http.statusCode))")
        }

        if let reply = try? JSONDecoder().decode(AgentReply.self, from: data) {
            let text = reply.response ?? reply.tool?.text ?? extractMessage(from: data) ?? "(no response)"
            return Result(message: text, tool: reply.tool, rawData: data)
        }

        let fallback = extractMessage(from: data) ?? "(no response)"
        return Result(message: fallback, tool: nil, rawData: data)
    }

    private func encodePayload(instruction: String, snapshot: [[String: Any]]?) throws -> Data {
        var payload: [String: Any] = ["instruction": instruction]
        if let snapshot = snapshot, !snapshot.isEmpty {
            payload["snapshot"] = snapshot
        }

        var data = try JSONSerialization.data(withJSONObject: payload, options: [])
        let limit = 200_000
        if data.count <= limit { return data }

        guard var snapshot = snapshot, !snapshot.isEmpty else {
            return data
        }

        while data.count > limit && snapshot.count > 1 {
            let dropCount = max(1, snapshot.count / 10)
            snapshot.removeLast(dropCount)
            payload["snapshot"] = snapshot
            data = try JSONSerialization.data(withJSONObject: payload, options: [])
        }

        if data.count > limit {
            payload.removeValue(forKey: "snapshot")
            data = try JSONSerialization.data(withJSONObject: payload, options: [])
        }

        return data
    }

    private func extractMessage(from data: Data) -> String? {
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = dict["error"] as? String { return message }
            if let message = dict["response"] as? String { return message }
        }
        return String(data: data, encoding: .utf8)
    }
}

private struct AgentReply: Decodable {
    let response: String?
    let tool: AgentClient.Tool?
}
//
//  AgentClient.swift
//  CluelyLite
//
//  Created by Vikranth Reddimasu on 9/23/25.
//
