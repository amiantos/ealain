//
//  HordeModels.swift
//  Inneal
//
//  Created by Brad Root on 4/10/24.
//

import Foundation

// MARK: - Horde Request

struct HordeRequest: Codable {
    let prompt: String
    let params: HordeRequestParams
    var models: [String]
    var workers: [String]
}

struct HordeRequestParams: Codable {
    let n: Int
    var maxContentLength: Int
    var maxLength: Int
    var repPen: Float
    var temperature: Float
    var topP: Float
    var topK: Float
    var topA: Float
    var typical: Float
    var tfs: Float
    var repPenRange: Float
    var repPenSlope: Float
    var samplerOrder: [Int]
    var useDefaultBadwordsids: Bool
    var stopSequence: [String]
    var minP: Float
    var dynatempRange: Float
    var dynatempExponent: Float
    var smoothingFactor: Float

    enum CodingKeys: String, CodingKey {
        case n
        case maxContentLength = "max_content_length"
        case maxLength = "max_length"
        case repPen = "rep_pen"
        case temperature
        case topP = "top_p"
        case topK = "top_k"
        case topA = "top_a"
        case typical
        case tfs
        case repPenRange = "rep_pen_range"
        case repPenSlope = "rep_pen_slope"
        case samplerOrder = "sampler_order"
        case useDefaultBadwordsids = "use_default_badwordsids"
        case stopSequence = "stop_sequence"
        case minP = "min_p"
        case dynatempRange = "dynatemp_range"
        case dynatempExponent = "dynatemp_exponent"
        case smoothingFactor = "smoothing_factor"
    }
}

struct HordeRequestResponse: Codable {
    let id: UUID
    let kudos: Float
}

struct HordeCheckRequestResponse: Codable {
    let generations: [HordeGeneration]
    let finished: Int
    let processing: Int
    let restarted: Int
    let waiting: Int
    let done: Bool
    let faulted: Bool
    let waitTime: Int
    let queuePosition: Int
    let kudos: Float
    let isPossible: Bool

    enum CodingKeys: String, CodingKey {
        case waitTime = "wait_time"
        case generations
        case finished
        case processing
        case restarted
        case waiting
        case done
        case faulted
        case queuePosition = "queue_position"
        case kudos
        case isPossible = "is_possible"
    }
}

struct HordeGeneration: Codable {
    let text: String
    let seed: Int
    let genMetadata: [String]
    let workerId: UUID
    let workerName: String
    let model: String
    let state: String

    enum CodingKeys: String, CodingKey {
        case text
        case seed
        case genMetadata = "gen_metadata"
        case workerId = "worker_id"
        case workerName = "worker_name"
        case model
        case state
    }
}

