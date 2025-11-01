import SwiftUI
import Firebase

// MARK: - Translation Model

struct Translation: Identifiable {
    let id = UUID()
    let original: String
    let translated: String
}

// MARK: - Main View

struct ContentView: View {
    @State private var inputText = ""
    @State private var translatedText = ""
    @State private var sourceLang = "English"
    @State private var targetLang = "Spanish"
    @State private var history: [Translation] = []

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text("🌍 TranslateMe")
                        .font(.largeTitle.bold())
                        .foregroundColor(.blue)
                        .padding(.top)

                    TextField("Enter text to translate", text: $inputText)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 2)
                        .padding(.horizontal)

                    HStack {
                        Picker("From", selection: $sourceLang) {
                            ForEach(["English", "Spanish", "French", "German", "Italian"], id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(.blue)

                        Image(systemName: "arrow.right")

                        Picker("To", selection: $targetLang) {
                            ForEach(["English", "Spanish", "French", "German", "Italian"], id: \.self) {
                                Text($0).tag($0)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .accentColor(.green)
                    }
                    .padding(.horizontal)

                    Button(action: translateText) {
                        Label("Translate", systemImage: "globe")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(radius: 2)
                    }
                    .padding(.horizontal)

                    if !translatedText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Translation")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text(translatedText)
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    }

                    NavigationLink(destination: HistoryView(history: $history, onClear: {
                        clearHistory {
                            history.removeAll()
                        }
                    })) {
                        Label("View History", systemImage: "clock.arrow.circlepath")
                            .font(.subheadline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .onAppear {
                    fetchHistory { translations in
                        history = translations
                    }
                }
            }
        }
    }

    // MARK: - Translation Logic

    func translateText() {
        let fromCode = languageCode(for: sourceLang)
        let toCode = languageCode(for: targetLang)

        translate(text: inputText, from: fromCode, to: toCode) { result in
            if let result = result {
                translatedText = result
                saveTranslation(original: inputText, translated: result)
                fetchHistory { translations in
                    history = translations
                }
            }
        }
    }

    func languageCode(for name: String) -> String {
        switch name {
        case "English": return "en"
        case "Spanish": return "es"
        case "French": return "fr"
        case "German": return "de"
        case "Italian": return "it"
        default: return "en"
        }
    }

    func translate(text: String, from sourceLang: String, to targetLang: String, completion: @escaping (String?) -> Void) {
        let urlString = "https://api.mymemory.translated.net/get?q=\(text)&langpair=\(sourceLang)|\(targetLang)"
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Network error: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            do {
                let result = try JSONDecoder().decode(TranslationResponse.self, from: data)
                DispatchQueue.main.async {
                    completion(result.responseData.translatedText)
                }
            } catch {
                print("Decoding error: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    func saveTranslation(original: String, translated: String) {
        let db = Firestore.firestore()
        db.collection("translations").addDocument(data: [
            "original": original,
            "translated": translated,
            "timestamp": Timestamp()
        ])
    }

    func fetchHistory(completion: @escaping ([Translation]) -> Void) {
        let db = Firestore.firestore()
        db.collection("translations").order(by: "timestamp", descending: true).getDocuments { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                print("Fetch error: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            let translations = snapshot.documents.compactMap { doc -> Translation? in
                guard let original = doc["original"] as? String,
                      let translated = doc["translated"] as? String else { return nil }
                return Translation(original: original, translated: translated)
            }
            completion(translations)
        }
    }

    func clearHistory(completion: @escaping () -> Void) {
        let db = Firestore.firestore()
        db.collection("translations").getDocuments { snapshot, error in
            guard let snapshot = snapshot, error == nil else {
                print("Clear error: \(error?.localizedDescription ?? "Unknown error")")
                completion()
                return
            }

            let batch = db.batch()
            snapshot.documents.forEach { doc in
                batch.deleteDocument(doc.reference)
            }

            batch.commit { error in
                if let error = error {
                    print("Batch delete error: \(error.localizedDescription)")
                }
                completion()
            }
        }
    }
}

// MARK: - Translation API Response

struct TranslationResponse: Codable {
    let responseData: TranslatedData
}

struct TranslatedData: Codable {
    let translatedText: String
}

// MARK: - History View

struct HistoryView: View {
    @Binding var history: [Translation]
    var onClear: () -> Void
    @State private var showAlert = false

    var body: some View {
        VStack {
            if history.isEmpty {
                Text("No translation history yet.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(history) { item in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("🔤 \(item.original)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Text("➡️ \(item.translated)")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                                Spacer()
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding()
                }
            }

            Button("Clear History") {
                showAlert = true
            }
            .foregroundColor(.red)
            .padding()
            .alert("Clear all history?", isPresented: $showAlert) {
                Button("Delete", role: .destructive) {
                    onClear()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .navigationTitle("Translation History")
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    ContentView()
        .onAppear {
            if FirebaseApp.app() == nil {
                FirebaseApp.configure()
            }
        }
}
