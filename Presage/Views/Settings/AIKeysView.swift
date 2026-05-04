import SwiftUI

struct AIKeysView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var bridge = AILLMBridge.shared
    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    WhisperLabel(text: "Bring your own keys")
                    Text("AI keys")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(DS.Palette.textPrimary)
                        .kerning(-0.4)
                }

                Text("Présage never proxies your data through a server. Your API keys live on this device only and call the model directly when you ask.")
                    .font(.system(size: 13))
                    .foregroundStyle(DS.Palette.textSecondary)
                    .lineSpacing(2)

                keyCard("OpenAI", model: .gpt5, binding: $openAIKey)
                keyCard("Anthropic", model: .claude46, binding: $anthropicKey)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(DS.Palette.surfacePrimary)
        .navigationTitle("AI keys")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            openAIKey = bridge.apiKey(for: .gpt5) ?? ""
            anthropicKey = bridge.apiKey(for: .claude46) ?? ""
        }
    }

    private func keyCard(_ provider: String, model: AIModel, binding: Binding<String>) -> some View {
        PariCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(provider)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.Palette.textPrimary)
                    Spacer()
                    if bridge.hasKey(for: model) {
                        Label("Stored", systemImage: "lock.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(DS.Palette.accent)
                    }
                }
                SecureField("API key", text: binding)
                    .padding(12)
                    .background(DS.Palette.surfaceTertiary, in: RoundedRectangle(cornerRadius: 12))
                PariButton("Save \(provider) key", style: .secondary) {
                    bridge.storeAPIKey(binding.wrappedValue, for: model)
                    HapticEngine.shared.resolutionReveal()
                }
            }
        }
    }
}
