import Compression
import Foundation
import SwiftData
import XCTest
@testable import CalisthenicsJourney

@MainActor
final class Phase31ToPhase4MigrationTests: XCTestCase {
    private let exerciseID = UUID(uuidString: "00000000-0000-0000-0000-000000001001")!
    private let variationID = UUID(uuidString: "00000000-0000-0000-0000-000000001002")!
    private let sessionID = UUID(uuidString: "00000000-0000-0000-0000-000000001003")!
    private let setID = UUID(uuidString: "00000000-0000-0000-0000-000000001005")!
    private let sourceRequirementID = UUID(uuidString: "00000000-0000-0000-0000-000000001006")!
    private let implicationID = UUID(uuidString: "00000000-0000-0000-0000-000000001008")!
    private let skillID = UUID(uuidString: "00000000-0000-0000-0000-000000001009")!
    private let foundationStageID = UUID(uuidString: "00000000-0000-0000-0000-000000001010")!
    private let destinationStageID = UUID(uuidString: "00000000-0000-0000-0000-000000001011")!
    private let availabilityID = UUID(uuidString: "00000000-0000-0000-0000-000000001012")!
    private let goalID = UUID(uuidString: "00000000-0000-0000-0000-000000001013")!

    func testRealPhase31StoreMigratesPreservesHistoryAndReopensWithPhase4Rows() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Phase31ToPhase4-\(UUID().uuidString).store")
        defer {
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(
                    at: URL(fileURLWithPath: storeURL.path + suffix)
                )
            }
        }
        try decodedPhase31Store().write(to: storeURL, options: .atomic)

        do {
            let container = try makeContainer(at: storeURL)
            let context = container.mainContext
            let exercise = try XCTUnwrap(
                context.fetch(FetchDescriptor<Exercise>()).first { $0.id == exerciseID }
            )
            let variation = try XCTUnwrap(
                context.fetch(FetchDescriptor<ExerciseVariation>()).first { $0.id == variationID }
            )
            let session = try XCTUnwrap(
                context.fetch(FetchDescriptor<WorkoutSession>()).first { $0.id == sessionID }
            )
            let set = try XCTUnwrap(
                context.fetch(FetchDescriptor<SetLog>()).first { $0.id == setID }
            )
            let sourceRequirement = try XCTUnwrap(
                context.fetch(FetchDescriptor<Requirement>()).first { $0.id == sourceRequirementID }
            )
            let implication = try XCTUnwrap(
                context.fetch(FetchDescriptor<RequirementImplication>()).first { $0.id == implicationID }
            )
            let skill = try XCTUnwrap(
                context.fetch(FetchDescriptor<Skill>()).first { $0.id == skillID }
            )
            let stages = try context.fetch(FetchDescriptor<SkillStage>())
            let foundation = try XCTUnwrap(stages.first { $0.id == foundationStageID })
            let destination = try XCTUnwrap(stages.first { $0.id == destinationStageID })
            let profile = try XCTUnwrap(context.fetch(FetchDescriptor<AthleteProfile>()).first)
            let availability = try XCTUnwrap(
                context.fetch(FetchDescriptor<EquipmentAvailability>()).first { $0.id == availabilityID }
            )
            let goal = try XCTUnwrap(
                context.fetch(FetchDescriptor<SkillGoal>()).first { $0.id == goalID }
            )

            XCTAssertEqual(exercise.id, exerciseID)
            XCTAssertEqual(variation.exercise?.id, exerciseID)
            XCTAssertEqual(session.exerciseLogs.first?.variationID, variationID)
            XCTAssertEqual(set.reps, 5)
            XCTAssertEqual(set.evidenceVariationID, variationID)
            XCTAssertTrue(RequirementEvaluator.evaluate(sourceRequirement, against: [session]).isSatisfied)
            XCTAssertEqual(implication.sourceRequirementID, sourceRequirementID)
            XCTAssertEqual(implication.sourceRequirement?.id, sourceRequirementID)
            XCTAssertEqual(skill.stages.map(\.id).sorted(by: uuidLessThan), [foundationStageID, destinationStageID])
            XCTAssertTrue(foundation.isCompleted)
            XCTAssertFalse(foundation.isCurrent)
            XCTAssertTrue(destination.isCurrent)
            XCTAssertFalse(destination.isCompleted)
            XCTAssertEqual(foundation.nodeKind, .primary)
            XCTAssertEqual(foundation.prerequisiteMode, .all)
            XCTAssertFalse(foundation.isSkillCompletion)
            XCTAssertEqual(profile.id, AthleteProfileBootstrap.localProfileID)
            XCTAssertEqual(availability.equipmentID, EquipmentCatalog.items.first { $0.kind == .pullUpBar }?.id)
            XCTAssertTrue(availability.isAvailable)
            XCTAssertEqual(goal.skillID, skillID)
            XCTAssertEqual(goal.priority, 2)
            XCTAssertTrue(goal.isSelected)

            let connection = SkillStageConnection(source: foundation, destination: destination)
            let link = SkillExerciseLink(
                skill: skill,
                stage: destination,
                variation: variation,
                role: .direct
            )
            let mapping = VariationEquipmentMapping(variation: variation, kind: .baselineOnly)
            context.insert(connection)
            context.insert(link)
            context.insert(mapping)
            try context.save()
        }

        do {
            let reopened = try makeContainer(at: storeURL)
            let context = reopened.mainContext
            let connection = try XCTUnwrap(context.fetch(FetchDescriptor<SkillStageConnection>()).first)
            let link = try XCTUnwrap(context.fetch(FetchDescriptor<SkillExerciseLink>()).first)
            let mapping = try XCTUnwrap(context.fetch(FetchDescriptor<VariationEquipmentMapping>()).first)

            XCTAssertEqual(connection.sourceStageID, foundationStageID)
            XCTAssertEqual(connection.destinationStageID, destinationStageID)
            XCTAssertEqual(link.skillID, skillID)
            XCTAssertEqual(link.stageID, destinationStageID)
            XCTAssertEqual(link.variationID, variationID)
            XCTAssertEqual(link.role, .direct)
            XCTAssertEqual(mapping.variationID, variationID)
            XCTAssertEqual(mapping.kind, .baselineOnly)
            XCTAssertEqual(try context.fetch(FetchDescriptor<SetLog>()).first?.id, setID)
            XCTAssertEqual(try context.fetch(FetchDescriptor<SkillGoal>()).first?.priority, 2)
        }
    }

    private func decodedPhase31Store() throws -> Data {
        let compactBase64 = Phase31StoreFixture.lzfseBase64
            .filter { !$0.isWhitespace }
        let compressed = try XCTUnwrap(Data(base64Encoded: compactBase64))
        var decoded = Data(count: Phase31StoreFixture.uncompressedByteCount)
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
        guard decodedByteCount == Phase31StoreFixture.uncompressedByteCount else {
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

    nonisolated private func uuidLessThan(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }

    private enum MigrationFixtureError: Error {
        case decompressionFailed(Int)
    }
}
