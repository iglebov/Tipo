import Foundation
import Speech
import Combine
import AVFoundation
import UIKit

class SpeechRecognizer: NSObject, ObservableObject {
    @Published var recognizedText = ""
    @Published var isRecording = false
    @Published var highlightedText = AttributedString("")
    
    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru_RU"))
    
    private var searchWords: [String] = []
    private var wordCount: [String: Int] = [:]
    private var totalWordCount: Int = 0
    
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Разрешение получено")
                case .denied:
                    print("Разрешение отклонено")
                case .restricted:
                    print("Распознавание речи ограничено")
                case .notDetermined:
                    print("Разрешение не запрашивалось")
                @unknown default:
                    print("Неизвестный статус")
                }
            }
        }
        
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Доступ к микрофону получен")
                } else {
                    print("Доступ к микрофону отклонен")
                }
            }
        }
    }
    
    func updateSearchWords(_ wordsString: String) {
        searchWords = wordsString.lowercased()
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        highlightedText = highlightWords(in: recognizedText)
    }
    
    private func highlightWords(in text: String) -> AttributedString {
        var attributedString = AttributedString(text)
        guard !searchWords.isEmpty else {
            return attributedString
        }
        
        resetCounters()
        
        let lowercasedText = text.lowercased()
        
        for word in searchWords where !word.isEmpty {
            var searchStartIndex = lowercasedText.startIndex
            while searchStartIndex < lowercasedText.endIndex,
                  let range = lowercasedText.range(of: word, range: searchStartIndex..<lowercasedText.endIndex),
                  !range.isEmpty {
                
                let startIndex = AttributedString.Index(range.lowerBound, within: attributedString)
                let endIndex = AttributedString.Index(range.upperBound, within: attributedString)
                
                if let start = startIndex, let end = endIndex {
                    attributedString[start..<end].backgroundColor = .yellow
                    
                    // Увеличиваем счётчик для этого слова
                    wordCount[word, default: 0] += 1
                    totalWordCount += 1
                }
                
                searchStartIndex = range.upperBound
            }
        }
        
        return attributedString
    }
    
    private func resetCounters() {
        wordCount.removeAll()
        totalWordCount = 0
    }
    
    private func showSummaryAlert() {
        guard !searchWords.isEmpty else { return }
        
        var message = "Найдено слов: \(totalWordCount)\n\n"
        
        if totalWordCount > 0 {
            message += "По отдельности:\n"
            for word in searchWords {
                let count = wordCount[word] ?? 0
                message += "• \(word): \(count)\n"
            }
        } else {
            message += "Искомые слова не найдены"
        }
        
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Статистика записи",
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                
                var topController = rootViewController
                while let presentedController = topController.presentedViewController {
                    topController = presentedController
                }
                
                topController.present(alert, animated: true)
            }
        }
    }
    
    func startRecording() throws {
        if isRecording {
            stopRecording()
        }
        
        resetCounters()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            throw NSError(domain: "SpeechRecognizer", code: 1, userInfo: [NSLocalizedDescriptionKey: "Распознавание речи недоступно"])
        }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    let bestString = result.bestTranscription.formattedString
                    self?.recognizedText = bestString
                    self?.highlightedText = self?.highlightWords(in: bestString) ?? AttributedString(bestString)
                }
                
                if error != nil {
                    self?.stopRecording()
                    
                    if let self = self, !self.searchWords.isEmpty {
                        self.showSummaryAlert()
                    }
                }
            }
        }
        
        isRecording = true
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        
        recognitionTask?.cancel()
        
        isRecording = false
        
        if !searchWords.isEmpty {
            showSummaryAlert()
        }
    }
}
