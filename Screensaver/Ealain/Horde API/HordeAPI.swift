//
//  HordeAPI.swift
//  Inneal
//
//  Created by Brad Root on 4/15/24.
//

import Foundation

enum APIError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse(statusCode: Int, content: String)
    case decodingFailed
    case requestTimedOut
}

class HordeAPI {
    var urlBase: String = "https://aihorde.net/api/v2"
    var userAgent: String = "Ealain:1.0:https://github.com/amiantos/ealain"

    init(urlBase: String = "https://aihorde.net/api/v2") {
        self.urlBase = urlBase
    }

    // Getters

    func submitRequest(apiKey: String, request: HordeRequest) async throws -> HordeRequestResponse {
        do {
            return try await post("/generate/async", responseType: HordeRequestResponse.self, apiKey: apiKey, body: request)
        } catch URLError.timedOut {
            throw APIError.requestTimedOut
        }
    }

    func checkRequest(apiKey: String, requestUUID: UUID) async throws -> HordeCheckRequestResponse {
        do {
            return try await get("/generate/check/\(requestUUID)", responseType: HordeCheckRequestResponse.self, apiKey: apiKey)
        } catch URLError.timedOut {
            throw APIError.requestTimedOut
        }
    }

    // Ugly Innards

    private func request(for url: URL, method: String = "GET", apiKey: String? = nil, body: Encodable? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "Client-Agent")
        if let apiKey {
            request.setValue(apiKey, forHTTPHeaderField: "apikey")
        }
        if let body {
            request.httpBody = try? JSONEncoder().encode(body)
            request.timeoutInterval = 5
        }
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest, responseType _: T.Type) async throws -> T {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let response = response as? HTTPURLResponse, !((200 ..< 300) ~= response.statusCode) {
                throw APIError.invalidResponse(statusCode: response.statusCode, content: String(describing: String(data: data, encoding: .utf8)))
            }
            do {
                let decodedResponse = try JSONDecoder().decode(T.self, from: data)
                return decodedResponse
            } catch {
                throw APIError.decodingFailed
            }
        } catch {
            throw APIError.requestFailed(error)
        }
    }

    private func get<T: Decodable>(_ path: String, responseType: T.Type, apiKey: String? = nil) async throws -> T {
        do {
            let request = request(for: URL(string: "\(urlBase)\(path)")!, apiKey: apiKey)
            return try await perform(request, responseType: T.self)
        } catch {
            throw APIError.requestFailed(error)
        }
    }

    private func post<T: Decodable>(_ path: String, responseType: T.Type, apiKey: String? = nil, body: Encodable? = nil) async throws -> T {
        do {
            let request = request(for: URL(string: "\(urlBase)\(path)")!, method: "POST", apiKey: apiKey, body: body)
            return try await perform(request, responseType: T.self)
        } catch {
            throw APIError.requestFailed(error)
        }
    }
}
