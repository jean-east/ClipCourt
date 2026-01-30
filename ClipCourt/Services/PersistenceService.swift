// PersistenceService.swift
// ClipCourt
//
// Saves and loads project state as JSON in the app's Documents directory.
// "Sleep! That's where I'm a Viking!" — and persistence is where
// your segments survive the night. With VERSIONED JSON and everything!
//
// Uses a versioned envelope so we can migrate data formats in future releases
// without losing the user's session.

import Foundation

// MARK: - Protocol

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
    case migrationFailed(fromVersion: Int, reason: String)

    var errorDescription: String? {
        switch self {
        case .encodingFailed(let reason):
            "Failed to save project: \(reason)"
        case .decodingFailed(let reason):
            "Failed to load project: \(reason)"
        case .fileSystemError(let reason):
            "File system error: \(reason)"
        case .migrationFailed(let version, let reason):
            "Failed to migrate from version \(version): \(reason)"
        }
    }
}

// MARK: - Versioned Envelope

/// Wrapper around the persisted project data with a version number.
/// When the Project model changes in future releases, we can:
/// 1. Bump `currentVersion`
/// 2. Add migration logic in `migrate(from:data:)`
/// 3. Old data is automatically upgraded on load.
private struct PersistedEnvelope: Codable {
    let version: Int
    let project: Project

    static let currentVersion = 1

    init(project: Project) {
        self.version = Self.currentVersion
        self.project = project
    }
}

// MARK: - Implementation

final class PersistenceService: ProjectPersisting {

    // MARK: - Constants

    private static let fileName = "current_project.json"

    // MARK: - Thread Safety

    /// Lock protecting file operations from concurrent access.
    /// Auto-save can be triggered from scene phase changes, timers, etc.
    private let lock = NSLock()

    // MARK: - File Path

    private var projectFileURL: URL {
        let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        return documentsDirectory.appendingPathComponent(Self.fileName)
    }

    // MARK: - Encoder / Decoder

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Save

    /// Saves the project to disk as versioned JSON.
    ///
    /// - Uses atomic writes to prevent data corruption on crash.
    /// - Thread-safe via NSLock.
    /// - The file is human-readable (pretty-printed) for debugging.
    ///
    /// - Parameter project: The project to save.
    /// - Throws: `PersistenceError` if encoding or writing fails.
    func save(_ project: Project) throws {
        lock.lock()
        defer { lock.unlock() }

        let envelope = PersistedEnvelope(project: project)

        let data: Data
        do {
            data = try encoder.encode(envelope)
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

    /// Loads the saved project from disk.
    ///
    /// - First tries to decode as a versioned envelope (v1+).
    /// - Falls back to decoding as a bare `Project` (v0 — pre-envelope format)
    ///   for backward compatibility with any data saved before versioning was added.
    /// - Runs migration if the loaded version is older than current.
    ///
    /// - Returns: The loaded (and possibly migrated) project, or nil if no save file exists.
    /// - Throws: `PersistenceError` if the file exists but can't be decoded.
    func load() throws -> Project? {
        lock.lock()
        defer { lock.unlock() }

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

        // Try versioned envelope first (v1+)
        if let envelope = try? decoder.decode(PersistedEnvelope.self, from: data) {
            if envelope.version == PersistedEnvelope.currentVersion {
                return envelope.project
            } else {
                // Future: migrate from older version
                return try migrate(from: envelope.version, data: data)
            }
        }

        // Fallback: try bare Project (v0 — before envelope was added)
        if let project = try? decoder.decode(Project.self, from: data) {
            // Re-save in the new envelope format for next time
            let envelope = PersistedEnvelope(project: project)
            if let envelopeData = try? encoder.encode(envelope) {
                try? envelopeData.write(to: url, options: .atomic)
            }
            return project
        }

        // Neither format worked
        throw PersistenceError.decodingFailed(
            "Saved project file is corrupted or in an unrecognized format."
        )
    }

    // MARK: - Delete

    /// Deletes the saved project file. No-op if no file exists.
    ///
    /// - Throws: `PersistenceError` if the file exists but can't be deleted.
    func delete() throws {
        lock.lock()
        defer { lock.unlock() }

        let url = projectFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            throw PersistenceError.fileSystemError(error.localizedDescription)
        }
    }

    // MARK: - Existence Check

    /// Returns true if a saved project file exists on disk.
    func hasExistingProject() -> Bool {
        FileManager.default.fileExists(atPath: projectFileURL.path)
    }

    // MARK: - Migration

    /// Migrates persisted data from an older version to the current version.
    ///
    /// For v1: no migration needed (it's the first version).
    /// Future versions add cases here:
    ///
    /// ```swift
    /// case 1:
    ///     // Decode v1 project, transform to v2 format
    ///     let v1Project = try decoder.decode(ProjectV1.self, from: data)
    ///     return ProjectV2(migrating: v1Project)
    /// ```
    private func migrate(from version: Int, data: Data) throws -> Project {
        switch version {
        // Currently only version 1 exists, so any other version is unexpected.
        // When we add version 2, we'd handle migration from 1→2 here.
        default:
            throw PersistenceError.migrationFailed(
                fromVersion: version,
                reason: "Unsupported data version \(version). You may need to update ClipCourt."
            )
        }
    }
}
