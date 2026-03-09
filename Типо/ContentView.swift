import SwiftUI

struct ContentView: View {
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Голосовой диктант")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            ScrollView {
                Text(speechRecognizer.highlightedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .frame(maxHeight: 300)
            
            VStack(alignment: .leading) {
                Text("Слова для поиска (через запятую):")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                TextField("например: привет, как дела, окей", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: searchText) { newValue in
                        speechRecognizer.updateSearchWords(newValue)
                    }
            }

            Button(action: {
                if speechRecognizer.isRecording {
                    speechRecognizer.stopRecording()
                } else {
                    do {
                        try speechRecognizer.startRecording()
                    } catch {
                        print("Ошибка записи: \(error.localizedDescription)")
                    }
                }
            }) {
                VStack {
                    Image(systemName: speechRecognizer.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(speechRecognizer.isRecording ? .red : .blue)
                    
                    Text(speechRecognizer.isRecording ? "Остановить" : "Начать запись")
                        .foregroundColor(.primary)
                }
            }

            Spacer()
        }
        .padding()
        .onAppear {
            speechRecognizer.requestPermissions()
        }
    }
}
