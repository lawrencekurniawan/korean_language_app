import SwiftUI
import UniformTypeIdentifiers

struct BackupsView: View {
    @Environment(AppEnvironment.self) private var env

    @State private var showingImporter = false
    @State private var pendingRestoreURL: URL?
    @State private var showingRestoreConfirmation = false
    @State private var isRestoring = false
    @State private var statusMessage: String?
    @State private var alertMessage: String?

    var body: some View {
        List {
            Section {
                Button {
                    createBackup()
                } label: {
                    if env.backup.isWorking {
                        HStack(spacing: SoriSpacing.sm) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Creating backup…")
                        }
                    } else {
                        Label("Back up now", systemImage: "archivebox")
                    }
                }
                .disabled(env.backup.isWorking || isRestoring)

                LabeledContent(
                    "Last backup",
                    value: env.settings.lastBackupAt?.formatted(
                        date: .abbreviated,
                        time: .shortened
                    ) ?? "Never"
                )

                if let statusMessage {
                    Text(statusMessage)
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriCorrect)
                }

                if let error = env.backup.errorMessage {
                    Text(error)
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriWarning)
                }
            } header: {
                Text("Create")
            } footer: {
                Text("The database and settings are packaged into an unencrypted ZIP archive. API keys in the Keychain and personal textbook audio are never included.")
            }

            Section {
                if let latest = env.backup.latestBackup {
                    ShareLink(item: latest.url) {
                        Label("Export latest backup", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Text("Create a backup before exporting a copy.")
                        .foregroundStyle(Color.soriSecondary)
                }
            } header: {
                Text("Off this iPhone")
            } footer: {
                Text("Choose iCloud Drive, Google Drive, or another file provider in the share sheet. Sori does not upload backups automatically.")
            }

            Section {
                if env.backup.localBackups.isEmpty {
                    Text("No local backups yet.")
                        .foregroundStyle(Color.soriSecondary)
                } else {
                    ForEach(env.backup.dailyBackups) { record in
                        backupRow(record)
                    }
                    if !env.backup.weeklyBackups.isEmpty {
                        ForEach(env.backup.weeklyBackups) { record in
                            backupRow(record)
                        }
                    }
                }
            } header: {
                Text("On this iPhone")
            } footer: {
                Text("Sori keeps the seven newest daily backups and four newest weekly backups. The oldest files are removed automatically.")
            }

            Section {
                Button {
                    showingImporter = true
                } label: {
                    Label("Restore from file…", systemImage: "arrow.counterclockwise")
                }
                .disabled(env.backup.isWorking || isRestoring)

                if isRestoring {
                    HStack(spacing: SoriSpacing.sm) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Restoring…")
                    }
                }
            } header: {
                Text("Restore")
            } footer: {
                Text("Restoring replaces progress, practice history, review scheduling, library imports, usage history, and settings. Personal audio and Keychain keys are not changed.")
            }
        }
        .scrollContentBackground(.hidden)
        .soriScreenBackground()
        .navigationTitle("Backups")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            env.backup.refreshLocalBackups()
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.soriBackup],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                requestRestore(url)
            case .failure(let error):
                alertMessage = error.localizedDescription
            }
        }
        .confirmationDialog(
            "Restore this backup?",
            isPresented: $showingRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restore", role: .destructive) {
                let url = pendingRestoreURL
                pendingRestoreURL = nil
                guard let url else { return }
                restore(url)
            }
            Button("Cancel", role: .cancel) {
                pendingRestoreURL = nil
            }
        } message: {
            Text("Your current progress, practice history, review scheduling, library imports, usage history, and settings will be replaced. This cannot be undone.")
        }
        .alert(
            "Backups",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func backupRow(_ record: BackupRecord) -> some View {
        HStack(spacing: SoriSpacing.sm) {
            Image(systemName: record.frequency == .daily ? "sun.max" : "calendar")
                .foregroundStyle(Color.soriAccent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(SoriFont.callout)
                    .foregroundStyle(Color.soriInk)
                Text("\(record.frequency.title) · \(record.sizeText)")
                    .font(SoriFont.caption)
                    .foregroundStyle(Color.soriSecondary)
            }

            Spacer(minLength: SoriSpacing.sm)

            Menu {
                Button {
                    requestRestore(record.url)
                } label: {
                    Label("Restore", systemImage: "arrow.counterclockwise")
                }

                ShareLink(item: record.url) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }

                Button(role: .destructive) {
                    delete(record)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.soriSecondary)
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Backup actions")
        }
        .padding(.vertical, 2)
    }

    private func createBackup() {
        statusMessage = nil
        Task {
            do {
                _ = try await env.backup.createBackup()
                statusMessage = "Backup created."
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    private func requestRestore(_ url: URL) {
        pendingRestoreURL = url
        showingRestoreConfirmation = true
    }

    private func restore(_ url: URL) {
        statusMessage = nil
        isRestoring = true
        Task {
            defer { isRestoring = false }
            do {
                let manifest = try await env.backup.restore(from: url)
                await env.afterRestore()
                statusMessage = "Restored the backup from \(manifest.createdAt.formatted(date: .abbreviated, time: .shortened))."
            } catch {
                alertMessage = error.localizedDescription
            }
        }
    }

    private func delete(_ record: BackupRecord) {
        do {
            try env.backup.delete(record)
            statusMessage = nil
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

extension UTType {
    static let soriBackup = UTType(exportedAs: "com.lawrencekurniawan.sori.backup")
}
