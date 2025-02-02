//
//  HordeDefaults.swift
//  Inneal
//
//  Created by Brad Root on 4/15/24.
//

import Foundation

let defaultHordeParams = HordeRequestParams(
    n: 1,
    maxContentLength: 4096,
    maxLength: 120,
    repPen: 1.1,
    temperature: 0.7,
    topP: 0.92,
    topK: 100,
    topA: 0,
    typical: 1,
    tfs: 1,
    repPenRange: 320,
    repPenSlope: 0.7,
    samplerOrder: [6, 0, 1, 3, 4, 2, 5],
    useDefaultBadwordsids: false,
    stopSequence: ["{{user}}:", "\n{{user}} ", "\n{{char}}: "],
    minP: 0,
    dynatempRange: 0,
    dynatempExponent: 1,
    smoothingFactor: 0
)

let defaultHordeRequest = HordeRequest(
    prompt: "",
    params: defaultHordeParams,
    models: [
        "aphrodite/KoboldAI/LLaMA2-13B-Estopia",
        "aphrodite/KoboldAI/LLaMA2-13B-Psyfighter2",
        "aphrodite/NeverSleep_Noromaid-20b-v0.1.1",
        "aphrodite/Sao10K/Fimbulvetr-11B-v2",
        "Henk717/airochronos-33B",
        "koboldcpp/Doctor-Shotgun/mythospice-70b",
        "koboldcpp/Fimbulvetr-11B-v2",
        "koboldcpp/llama-2-7b-chat.Q6_K",
        "koboldcpp/mistral-7b-instruct-v0.2",
        "koboldcpp/mistral-claudelimarp-v3-7b.Q5_K_M",
        "koboldcpp/Noromaid-v0.4-Mixtral-Instruct-8x7b-Zloss",
        "koboldcpp/OpenHermes-2.5-Mistral-7B",
    ],
    workers: []
)
