import SwiftData
import XCTest
@testable import CalisthenicsJourney

@MainActor
final class WorkoutSaveProgressTests: XCTestCase {
    private enum SaveError: Error { case injected }

    func testFailedNextKeepsUnsavedEntryOnCurrentExerciseUntilRetrySucceeds() throws {
        let container = try ModelContainer(for: WorkoutSession.self, SetLog.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.autosaveEnabled = false
        let session = WorkoutSession(workoutName: "Training")
        let log = ExerciseLog(exercise: Exercise(name: "Pull-up", metric: .reps), orderIndex: 0, session: session)
        let set = SetLog(setNumber: 1, exerciseLog: log)
        context.insert(session)
        context.insert(log)
        context.insert(set)
        try context.save()
        set.reps = 8
        var progress = WorkoutSaveProgress()

        progress.advance(session: session, exerciseCount: 2) { throw SaveError.injected }
        XCTAssertEqual(progress.exerciseIndex, 0)
        XCTAssertTrue(progress.saveFailed)
        XCTAssertFalse(progress.showFinished)
        XCTAssertEqual(set.reps, 8)

        progress.advance(session: session, exerciseCount: 2, save: context.save)
        XCTAssertEqual(progress.exerciseIndex, 1)
        XCTAssertFalse(progress.saveFailed)
        XCTAssertFalse(progress.showFinished)
        XCTAssertNil(session.completedAt)
        let reader = ModelContext(container)
        XCTAssertEqual(try reader.fetch(FetchDescriptor<SetLog>()).first?.reps, 8)
    }

    func testFinishStopsIfPerformanceSaveFails() {
        let session = WorkoutSession(workoutName: "Training")
        var progress = WorkoutSaveProgress()
        var saves = 0

        progress.advance(session: session, exerciseCount: 1) {
            saves += 1
            throw SaveError.injected
        }

        XCTAssertEqual(saves, 1)
        XCTAssertTrue(progress.saveFailed)
        XCTAssertFalse(progress.showFinished)
        XCTAssertNil(session.completedAt)
    }

    func testNormalNextAndFinishOnlyCompleteOnce() {
        let session = WorkoutSession(workoutName: "Training")
        var progress = WorkoutSaveProgress()
        progress.advance(session: session, exerciseCount: 2) {}
        XCTAssertEqual(progress.exerciseIndex, 1)
        XCTAssertNil(session.completedAt)

        progress.advance(session: session, exerciseCount: 2) {}
        XCTAssertTrue(progress.showFinished)
        XCTAssertFalse(progress.saveFailed)
        let completedAt = session.completedAt
        XCTAssertNotNil(completedAt)

        progress.advance(session: session, exerciseCount: 2) { XCTFail("Already finished") }
        XCTAssertEqual(session.completedAt, completedAt)
    }

    func testFailedCompletionSavePreservesPerformanceAndRetryPersistsSameSession() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("workout.store")
        func openStore() throws -> ModelContainer {
            try ModelContainer(for: WorkoutSession.self, ExerciseLog.self, SetLog.self,
                               Exercise.self, ExerciseVariation.self, configurations: ModelConfiguration(url: url))
        }

        let sessionID: UUID
        let setID: UUID
        do {
            let container = try openStore()
            let context = container.mainContext
            context.autosaveEnabled = false
            let session = WorkoutSession(workoutName: "Training")
            let exercise = Exercise(name: "Pull-up", metric: .reps)
            let log = ExerciseLog(exercise: exercise, orderIndex: 0, session: session)
            let set = SetLog(setNumber: 1, reps: 5, exerciseLog: log)
            context.insert(session)
            context.insert(log)
            context.insert(set)
            sessionID = session.id
            setID = set.id
            var progress = WorkoutSaveProgress()

            progress.advance(session: session, exerciseCount: 1) {
                if session.completedAt != nil { throw SaveError.injected }
                try context.save()
            }
            XCTAssertEqual(progress.exerciseIndex, 0)
            XCTAssertTrue(progress.saveFailed)
            XCTAssertFalse(progress.showFinished)
            XCTAssertNil(session.completedAt)
            XCTAssertEqual(set.reps, 5)

            let reader = ModelContext(container)
            let unfinished = try XCTUnwrap(reader.fetch(FetchDescriptor<WorkoutSession>()).first)
            XCTAssertNil(unfinished.completedAt)
            XCTAssertEqual(unfinished.exerciseLogs.first?.sets.first?.reps, 5)

            progress.advance(session: session, exerciseCount: 1, save: context.save)
            XCTAssertTrue(progress.showFinished)
            XCTAssertFalse(progress.saveFailed)
        }

        let reopened = try openStore()
        let sessions = try reopened.mainContext.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(sessions.map(\.id), [sessionID])
        let finished = try XCTUnwrap(sessions.first)
        XCTAssertNotNil(finished.completedAt)
        let sets = finished.exerciseLogs.flatMap(\.sets)
        XCTAssertEqual(sets.map(\.id), [setID])
        XCTAssertEqual(sets.first?.reps, 5)
    }
}
