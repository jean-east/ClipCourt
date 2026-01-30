// PersistenceService.swift
// ClipCourt
//
// Saves and loads project state as JSON in the app's Documents directory.
// "Sleep! That's where I'm a Viking!" — and persistence is where
// your segments survive the night.

import Foundation

/// Protocol for project persistence — enables testing.
protocol ProjectPersisting {
    func save(_ project: Project) throws
    func load() throws -> Project?
    func delete() throws
    func hasExistingProject() -> Bool
}

// MARK: - Errors

enum PersistenceError: LocalizedError {
    case encodingFailed(String)
    case decodingFailed(String)
    case fileSystemError(String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed(let reason):
            "Failed to save project: \(reason)"
        case .decodingFailed(let reason):
            "Failed to load project: \(reason)"
        case .fileSystemError(let reason):
            "File system error: \(reason)"
        }
    }
}

// MARK: - Implementation

final class PersistenceService: ProjectPersisting {

    // MARK: - Constants

    private static let projectFileName = "current_project.json"

    // MARK: - File Path

    private var projectFileURL: URL {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        return documentsDirectory.appendingPathComponent(Self.projectFileName)
    }

    // MARK: - Save

    func save(_ project: Project) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(project)
        } catch {
            throw PersistenceError.encodingFailed(error.localizedDescription)
        }

        do {
            try data.write(to: projectFileURL, options: .atomic)
        } catch {
            throw PersistenceError.fileSystemError(error.localizedDescription)
        }
    }

    // MARK: - Load

    func load() throws -> Project? {
        let url = projectFileURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw PersistenceError.fileSystemError(error.localizedDescription)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let project = try decoder.decode(Project.self, from: data)
            return project
        } catch {
            throw PersistenceError.decodingFailed(error.localizedDescription)
        }
    }

    // MARK: - Delete

    func delete() throws {
        let url = projectFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw PersistenceError.fileSystemError(error.localizedDescription)
        }
    }

    // MARK: - Existence Check

    func hasExistingProject() -> Bool {
        FileManager.default.fileExists(atPath: projectFileURL.path)
    }
}
