import Foundation
import SwiftData

/// Seeds the database with a starter pack of training questions on
/// first launch of training mode. Real apps would load these from a
/// remote bundle; we ship a curated 30-question starter offline.
enum TrainingPack {

    @MainActor
    static func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<TrainingQuestion>()
        let existing = (try? context.fetch(descriptor)) ?? []
        if existing.isEmpty {
            for q in starterQuestions {
                context.insert(q)
            }
            try? context.save()
        }
    }

    static var starterQuestions: [TrainingQuestion] {
        [
            // Geography
            TrainingQuestion(prompt: "Mount Everest is taller than 9,000 meters.",
                           correctAnswer: "False — 8,849 m", isYesAnswer: false, topic: .geography),
            TrainingQuestion(prompt: "The Nile is the longest river in the world.",
                           correctAnswer: "Disputed but commonly Yes", isYesAnswer: true, topic: .geography),
            TrainingQuestion(prompt: "Australia is larger than Greenland by area.",
                           correctAnswer: "Yes — Australia is ~3.5× Greenland", isYesAnswer: true, topic: .geography),
            TrainingQuestion(prompt: "Reykjavík is the northernmost capital city in the world.",
                           correctAnswer: "Yes", isYesAnswer: true, topic: .geography),
            TrainingQuestion(prompt: "Russia borders more than 12 countries.",
                           correctAnswer: "Yes — 14 countries", isYesAnswer: true, topic: .geography),

            // History
            TrainingQuestion(prompt: "World War I ended before 1920.",
                           correctAnswer: "Yes — 1918", isYesAnswer: true, topic: .history),
            TrainingQuestion(prompt: "The Roman Empire fell before 500 AD.",
                           correctAnswer: "Western half: yes (476 AD)", isYesAnswer: true, topic: .history),
            TrainingQuestion(prompt: "The Berlin Wall came down in the 1980s.",
                           correctAnswer: "Yes — November 1989", isYesAnswer: true, topic: .history),
            TrainingQuestion(prompt: "Napoleon was shorter than the average Frenchman of his time.",
                           correctAnswer: "No — he was around average height", isYesAnswer: false, topic: .history),
            TrainingQuestion(prompt: "The Magna Carta was signed before 1300 AD.",
                           correctAnswer: "Yes — 1215", isYesAnswer: true, topic: .history),

            // Science
            TrainingQuestion(prompt: "Sound travels faster in water than in air.",
                           correctAnswer: "Yes — about 4× faster", isYesAnswer: true, topic: .science),
            TrainingQuestion(prompt: "A day on Venus is longer than its year.",
                           correctAnswer: "Yes", isYesAnswer: true, topic: .science),
            TrainingQuestion(prompt: "Humans share over 90% of their DNA with chimpanzees.",
                           correctAnswer: "Yes — about 98–99%", isYesAnswer: true, topic: .science),
            TrainingQuestion(prompt: "Lightning is hotter than the surface of the sun.",
                           correctAnswer: "Yes — about 5×", isYesAnswer: true, topic: .science),
            TrainingQuestion(prompt: "Octopuses have three hearts.",
                           correctAnswer: "Yes", isYesAnswer: true, topic: .science),
            TrainingQuestion(prompt: "Sharks are mammals.",
                           correctAnswer: "No — they are fish", isYesAnswer: false, topic: .science),

            // Sports
            TrainingQuestion(prompt: "Brazil has won more FIFA World Cups than any other country.",
                           correctAnswer: "Yes — 5 titles", isYesAnswer: true, topic: .sports),
            TrainingQuestion(prompt: "Michael Jordan won more NBA championships than LeBron James.",
                           correctAnswer: "Yes — 6 vs 4", isYesAnswer: true, topic: .sports),
            TrainingQuestion(prompt: "The first modern Olympics took place in Greece.",
                           correctAnswer: "Yes — Athens 1896", isYesAnswer: true, topic: .sports),
            TrainingQuestion(prompt: "A standard tennis match has 5 sets.",
                           correctAnswer: "No — best of 3 (most), 5 (Grand Slam men)", isYesAnswer: false, topic: .sports),

            // General
            TrainingQuestion(prompt: "There are more stars in the observable universe than grains of sand on Earth.",
                           correctAnswer: "Yes — by current estimates", isYesAnswer: true, topic: .general),
            TrainingQuestion(prompt: "The shortest war in history lasted less than an hour.",
                           correctAnswer: "Yes — Anglo-Zanzibar War, 38–45 minutes", isYesAnswer: true, topic: .general),
            TrainingQuestion(prompt: "Honey never spoils.",
                           correctAnswer: "Yes — properly stored honey is shelf-stable indefinitely", isYesAnswer: true, topic: .general),
            TrainingQuestion(prompt: "There are more bacteria cells in your body than human cells.",
                           correctAnswer: "Roughly equal — recent research suggests ~1:1", isYesAnswer: false, topic: .general),
            TrainingQuestion(prompt: "A group of crows is called a 'murder'.",
                           correctAnswer: "Yes", isYesAnswer: true, topic: .general),
            TrainingQuestion(prompt: "Bananas are technically berries.",
                           correctAnswer: "Yes — botanically", isYesAnswer: true, topic: .general),
            TrainingQuestion(prompt: "Strawberries are technically berries.",
                           correctAnswer: "No — they are aggregate fruits", isYesAnswer: false, topic: .general),
            TrainingQuestion(prompt: "The Great Wall of China is visible from space with the naked eye.",
                           correctAnswer: "No — common myth", isYesAnswer: false, topic: .general),
            TrainingQuestion(prompt: "Goldfish have a memory of only 3 seconds.",
                           correctAnswer: "No — they remember for months", isYesAnswer: false, topic: .general),
            TrainingQuestion(prompt: "Lightning never strikes the same place twice.",
                           correctAnswer: "No — common myth, it often does", isYesAnswer: false, topic: .general),
        ]
    }

    @MainActor
    static func nextUnanswered(in context: ModelContext, topic: TrainingTopic? = nil) -> TrainingQuestion? {
        var descriptor = FetchDescriptor<TrainingQuestion>(
            predicate: #Predicate<TrainingQuestion> { $0.userAnsweredAt == nil }
        )
        descriptor.fetchLimit = 1
        let questions = (try? context.fetch(descriptor)) ?? []
        if let topic {
            return questions.first { $0.topic == topic }
        }
        return questions.first
    }

    @MainActor
    static func userScore(in context: ModelContext) -> (count: Int, brier: Double?) {
        let descriptor = FetchDescriptor<TrainingQuestion>(
            predicate: #Predicate<TrainingQuestion> { $0.userBrierScore != nil }
        )
        let answered = (try? context.fetch(descriptor)) ?? []
        guard !answered.isEmpty else { return (0, nil) }
        let total = answered.compactMap { $0.userBrierScore }.reduce(0, +)
        return (answered.count, total / Double(answered.count))
    }
}
