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
    let style: String
    let params: HordeParams
}

struct HordeParams: Codable {
    let n: Int
}

struct HordeRequestResponse: Codable {
    let id: UUID
    let kudos: Float
}

struct HordeCheckRequestResponse: Codable {
    let generations: [HordeGeneration]?
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
    let img: String

    enum CodingKeys: String, CodingKey {
        case img
    }
}
