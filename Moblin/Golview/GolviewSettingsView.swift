import SwiftUI

private let golviewStreamName = "Golview"

struct GolviewSettingsView: View {
    @EnvironmentObject var model: Model
    @State private var joinToken = ""
    @State private var connecting = false
    @State private var connected = false
    @State private var errorMessage: String?

    private func makeGolviewStream() -> SettingsStream {
        if let stream = model.database.streams.first(where: { $0.name == golviewStreamName }) {
            return stream
        }
        let stream = SettingsStream(name: golviewStreamName)
        model.database.streams.append(stream)
        return stream
    }

    private func connect() {
        connecting = true
        connected = false
        errorMessage = nil
        let joinToken = joinToken.trim()
        Task { @MainActor in
            do {
                let join = try await GolviewClient.join(
                    joinToken: joinToken,
                    deviceModel: UIDevice.current.model
                )
                let liveConfig = try await GolviewClient.fetchLiveConfig(deviceToken: join.deviceToken)
                guard liveConfig.liveEnabled, let publishSrtUrl = liveConfig.publishSrtUrl,
                      !publishSrtUrl.isEmpty
                else {
                    throw "La sesión no tiene transmisión en vivo habilitada"
                }
                let stream = makeGolviewStream()
                stream.url = publishSrtUrl
                model.setCurrentStream(stream: stream)
                model.reloadStream()
                model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
                connected = true
            } catch {
                errorMessage = (error as? String) ?? error.localizedDescription
            }
            connecting = false
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Código de sesión", text: $joinToken)
                    .textInputAutocapitalization(.characters)
                    .disableAutocorrection(true)
            } footer: {
                Text("Ingresa el código que aparece en golview.mx para usar este teléfono como cámara.")
            }
            Section {
                Button {
                    connect()
                } label: {
                    HStack {
                        Spacer()
                        if connecting {
                            ProgressView()
                        } else {
                            Text("Conectar")
                        }
                        Spacer()
                    }
                }
                .disabled(connecting || joinToken.trim().isEmpty || model.isLive)
            } footer: {
                if connected {
                    Text("Conectado. El stream \"\(golviewStreamName)\" está listo y seleccionado.")
                        .foregroundStyle(.green)
                        .bold()
                } else if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .bold()
                }
            }
        }
        .navigationTitle("Golview")
    }
}
