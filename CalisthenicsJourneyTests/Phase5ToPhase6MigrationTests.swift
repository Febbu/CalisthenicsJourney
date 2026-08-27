import Compression
import Foundation
import SwiftData
import XCTest
@testable import CalisthenicsJourney

@MainActor
final class Phase5ToPhase6MigrationTests: XCTestCase {
    private let exerciseID = UUID(uuidString: "00000000-0000-0000-0000-000000006001")!
    private let variationID = UUID(uuidString: "00000000-0000-0000-0000-000000006002")!
    private let stageID = UUID(uuidString: "00000000-0000-0000-0000-000000006004")!
    private let setID = UUID(uuidString: "00000000-0000-0000-0000-000000006007")!

    func testLockedPhase5StoreMigratesWithoutChangingHistoryOrMastery() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Phase5ToPhase6-\(UUID().uuidString).store")
        defer { removeStore(at: storeURL) }
        try decodedPhase5Store().write(to: storeURL, options: .atomic)

        do {
            let container = try makeContainer(at: storeURL)
            let context = container.mainContext
            let exercise = try XCTUnwrap(
                context.fetch(FetchDescriptor<Exercise>()).first { $0.id == exerciseID }
            )
            let variation = try XCTUnwrap(
                context.fetch(FetchDescriptor<ExerciseVariation>()).first { $0.id == variationID }
            )
            let stage = try XCTUnwrap(
                context.fetch(FetchDescriptor<SkillStage>()).first { $0.id == stageID }
            )
            let session = try XCTUnwrap(context.fetch(FetchDescriptor<WorkoutSession>()).first)
            let set = try XCTUnwrap(
                context.fetch(FetchDescriptor<SetLog>()).first { $0.id == setID }
            )
            let profile = try XCTUnwrap(context.fetch(FetchDescriptor<AthleteProfile>()).first)

            XCTAssertEqual(exercise.name, "Phase 5 movement")
            XCTAssertEqual(variation.exercise?.id, exerciseID)
            XCTAssertEqual(set.evidenceVariationID, variationID)
            XCTAssertEqual(set.reps, 5)
            XCTAssertTrue(set.hasActualPerformanceEvidence)
            XCTAssertTrue(stage.isCompleted)
            XCTAssertTrue(ProgressionEngine.isMastered(stage, against: [session]))
            XCTAssertEqual(profile.id, AthleteProfileBootstrap.localProfileID)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<ExercisePrescriptionState>()), 0)

            _ = try PrescriptionStateService.storeEstimate(
                athleteID: profile.id,
                variationID: variation.id,
                mode: .reps,
                values: ThreeWorkingSetValues(first: 5, second: 4, third: 3),
                context: context
            )
            try context.save()
        }

        do {
            let reopened = try makeContainer(at: storeURL)
            let context = reopened.mainContext
            let state = try XCTUnwrap(
                context.fetch(FetchDescriptor<ExercisePrescriptionState>()).first
            )
            XCTAssertEqual(state.variationID, variationID)
            XCTAssertEqual(state.athleteID, AthleteProfileBootstrap.localProfileID)
            XCTAssertEqual(state.workingSetValues, ThreeWorkingSetValues(first: 5, second: 4, third: 3))
            XCTAssertEqual(try context.fetch(FetchDescriptor<SetLog>()).first?.id, setID)
            XCTAssertTrue(try XCTUnwrap(context.fetch(FetchDescriptor<SkillStage>()).first).isCompleted)
        }
    }

    private func decodedPhase5Store() throws -> Data {
        let compactBase64 = Phase5StoreFixture.lzfseBase64.filter { !$0.isWhitespace }
        let compressed = try XCTUnwrap(Data(base64Encoded: compactBase64))
        var decoded = Data(count: Phase5StoreFixture.uncompressedByteCount)
        let decodedByteCount = decoded.withUnsafeMutableBytes { decodedBuffer in
            compressed.withUnsafeBytes { compressedBuffer in
                compression_decode_buffer(
                    decodedBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    decodedBuffer.count,
                    compressedBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    compressedBuffer.count,
                    nil,
                    COMPRESSION_LZFSE
                )
            }
        }
        guard decodedByteCount == Phase5StoreFixture.uncompressedByteCount else {
            throw MigrationFixtureError.decompressionFailed(decodedByteCount)
        }
        return decoded
    }

    private func makeContainer(at storeURL: URL) throws -> ModelContainer {
        try ModelContainer(
            for: Exercise.self, ExerciseVariation.self, WorkoutTemplate.self,
            WorkoutTemplateExercise.self, WorkoutSession.self, ExerciseLog.self, SetLog.self,
            JourneyLevel.self, LevelRequirement.self, Requirement.self, RequirementImplication.self,
            Skill.self, SkillStage.self, EquipmentDefinition.self, AthleteProfile.self,
            EquipmentAvailability.self, SkillGoal.self, SkillStageConnection.self,
            SkillExerciseLink.self, VariationEquipmentMapping.self,
            VariationEquipmentSetup.self, VariationEquipmentItem.self,
            ExercisePrescriptionState.self,
            configurations: ModelConfiguration(url: storeURL)
        )
    }

    private func removeStore(at url: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: url.path + suffix)
        }
    }

    private enum MigrationFixtureError: Error {
        case decompressionFailed(Int)
    }
}
