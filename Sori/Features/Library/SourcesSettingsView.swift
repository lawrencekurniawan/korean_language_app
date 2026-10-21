import SwiftUI

struct SourcesSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var openSubtitlesAPIKey = SecretStore.shared.value(for: .openSubtitlesAPIKey) ?? ""
    @State private var openSubtitlesUsername = SecretStore.shared.value(for: .openSubtitlesUsername) ?? ""
    @State private var openSubtitlesPassword = SecretStore.shared.value(for: .openSubtitlesPassword) ?? ""
    @State private var omdbAPIKey = SecretStore.shared.value(for: .omdbAPIKey) ?? ""
    @State private var savedMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                SecureField("API key", text: $openSubtitlesAPIKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
                TextField("Username", text: $openSubtitlesUsername)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $openSubtitlesPassword)
                    .textContentType(.password)
            } header: {
                Text("OpenSubtitles")
            } footer: {
                Text("The API key searches the catalogue. Username and password are only used to request a download token. Create a free account at opensubtitles.com.")
            }

            Section {
                Link(
                    "Open OpenSubtitles API settings",
                    destination: URL(string: "https://www.opensubtitles.com/en/consumers")!
                )
            }

            Section {
                SecureField("API key", text: $omdbAPIKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
            } header: {
                Text("OMDb")
            } footer: {
                Text("OMDb supplies the IMDb title rating used by the quality filter. A free key is available at omdbapi.com.")
            }

            Section {
                Link("Request an OMDb key", destination: URL(string: "https://www.omdbapi.com/apikey.aspx")!)
            }

            Section {
                Button("Save keys") { save() }
                    .font(SoriFont.callout)
                if let savedMessage {
                    Label(savedMessage, systemImage: "checkmark.circle.fill")
                        .font(SoriFont.caption)
                        .foregroundStyle(Color.soriCorrect)
                }
                Button("Remove all keys", role: .destructive) {
                    SecretStore.shared.clearAll()
                    openSubtitlesAPIKey = ""
                    openSubtitlesUsername = ""
                    openSubtitlesPassword = ""
                    omdbAPIKey = ""
                    savedMessage = nil
                }
            } footer: {
                Text("Keys are stored in the iOS Keychain with device-only access, so they are not included in backups.")
            }
        }
        .scrollContentBackground(.hidden)
        .soriScreenBackground()
        .navigationTitle("Subtitle sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .alert(
            "Couldn't save keys",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func save() {
        let results = [
            SecretStore.shared.set(openSubtitlesAPIKey, for: .openSubtitlesAPIKey),
            SecretStore.shared.set(openSubtitlesUsername, for: .openSubtitlesUsername),
            SecretStore.shared.set(openSubtitlesPassword, for: .openSubtitlesPassword),
            SecretStore.shared.set(omdbAPIKey, for: .omdbAPIKey)
        ]
        if results.allSatisfy({ $0 }) {
            savedMessage = "Saved on this iPhone"
        } else {
            errorMessage = "One or more items could not be written to the Keychain."
        }
    }
}
