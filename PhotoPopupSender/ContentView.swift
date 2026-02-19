//
//  ContentView.swift
//  PhotoPopupSender
//
//  Created by Bart Swart on 18/02/2026.
//

import SwiftUI
import PhotosUI

// Hoofdscherm waarmee je een foto kiest of maakt en die via HTTP naar een Windows receiver stuurt.

// SwiftUI view voor het selecteren/scannen en versturen van een foto
struct ContentView: View {
    // MARK: - Status en invoervelden
    @State private var baseUrl: String = "http://192.168.2.20:5055" // Basis-URL van de Windows receiver (zonder pad)
    @State private var showCamera = false                          // Toont de camera-sheet

    @State private var selectedItem: PhotosPickerItem?             // Geselecteerd item uit de fotobibliotheek
    @State private var previewImage: UIImage?                      // Voorvertoning van de gekozen/gemaakte foto
    @State private var isUploading = false                         // Upload is bezig-indicator
    @State private var statusText: String = "Kies een foto om te beginnen." // Status/feedback naar de gebruiker

    // MARK: - UI
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {

                    // Invoer voor doel-URL
                    GroupBox("Windows receiver") {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Base URL (bv. http://192.168.2.20:5055)", text: $baseUrl)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .textFieldStyle(.roundedBorder) // Voer de basis-URL van de receiver in
                                .submitLabel(.done)
                        }
                    }

                    // Foto kiezen uit bibliotheek of alternatieven (camera)
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                            Text("Kies foto")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding()
                        .background(.blue.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)

                    HStack(spacing: 12) {
                        // Start de camera om direct een foto te nemen
                        Button {
                            showCamera = true
                        } label: {
                            Label("Maak foto", systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    }

                    // Voorvertoning van de geselecteerde/gemaakte foto
                    if let img = previewImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 160)
                            .cornerRadius(12)
                            .shadow(radius: 4)
                            .padding(.vertical)
                    }
                    // Verstuurknop; disabled tijdens upload of zonder afbeelding
                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text(isUploading ? "Versturen..." : "Stuur naar PC")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(previewImage == nil || isUploading)
                    .buttonStyle(.borderedProminent)

                    // Korte statusmelding voor de gebruiker
                    Text(statusText)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer()
                }
                .padding(.horizontal)
            }
            .navigationTitle("PhotoPopup Sender")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Gereed") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            // Laad een voorvertoning wanneer de gebruiker een foto kiest
            .onChange(of: selectedItem) { _, newItem in

                Task { await loadPreview(from: newItem) }

            }
            .sheet(isPresented: $showCamera) {
                // Callback met de gemaakte foto
                ImagePicker(source: .camera) { img in
                    previewImage = img
                    statusText = "Klaar om te versturen ✅"
                }
            }

        }
    }

    // MARK: - Helpers
    /// Laadt een UIImage-voorvertoning uit een PhotosPickerItem
    private func loadPreview(from item: PhotosPickerItem?) async {
        guard let item else { return } // Geen item geselecteerd
        statusText = "Foto laden…"
        // Laad binaire data en maak er een UIImage van
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let ui = UIImage(data: data) {
                previewImage = ui // Voorvertoning instellen
                statusText = "Klaar om te versturen ✅"
            } else {
                statusText = "Kon foto niet laden."
            }
        } catch {
            statusText = "Fout bij laden: \(error.localizedDescription)"
        }
    }

    /// Converteert de afbeelding naar JPEG en verstuurt die naar de server
    private func send() async {
        guard let previewImage else { return } // Niets te versturen
        isUploading = true
        defer { isUploading = false }

        // Converteer naar JPEG met redelijke kwaliteit voor Windows/clipboard
        guard let jpegData = previewImage.jpegData(compressionQuality: 0.92) else {
            statusText = "Kon JPEG niet maken."
            return
        }

        // Bouw endpoint-URL (zorg dat trailing slashes verwijderd zijn)
        let trimmed = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/push-photo") else {
            statusText = "URL is ongeldig."
            return // Valideer samengestelde URL
        }

        // Start upload
        statusText = "Uploaden…"
        do {
            try await uploadJPEG(to: url, jpegData: jpegData)
            statusText = "Verstuurd ✅ (popup zou nu op je PC moeten verschijnen)" // Succesmelding
        } catch {
            statusText = "Upload mislukt: \(error.localizedDescription)"
        }
    }

    /// Maakt een multipart/form-data POST met het JPEG-bestand
    private func uploadJPEG(to url: URL, jpegData: Data) async throws {
        var request = URLRequest(url: url)

        request.httpMethod = "POST" // We gebruiken upload via POST

        // Stel multipart boundary en Content-Type in
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        // Bouw multipart-body: 1 veld met bestandsnaam 'photo.jpg'
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        // Voer upload uit en controleer HTTP-respons
        let (data, resp) = try await URLSession.shared.upload(for: request, from: body)
        guard let http = resp as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard (200...299).contains(http.statusCode) else { // Gooi fout bij niet-2xx
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)" // Lees eventuele foutboodschap van server
            throw NSError(domain: "Upload", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }
}

