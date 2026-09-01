import Foundation
import Combine
import SwiftUI

struct Account: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var symbolName: String
    var colorName: String
    
    var color: Color {
        switch colorName {
        case "red": return .red
        case "orange": return .orange
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "cyan": return .cyan
        case "yellow": return .yellow
        default: return .blue
        }
    }
}

class AccountStore: ObservableObject {
    @Published var accounts: [Account] = []
    
    let availableSymbols = [
        "message.fill", "person.fill", "briefcase.fill", "heart.fill",
        "globe", "bubble.left.and.bubble.right.fill", "house.fill", "star.fill",
        "phone.fill", "envelope.fill"
    ]
    
    let availableColors = [
        "blue", "green", "red", "orange", "purple", "pink", "cyan", "yellow"
    ]
    
    init() {
        load()
    }
    
    func load() {
        if let data = UserDefaults.standard.data(forKey: "whatsapp_accounts"),
           let decoded = try? JSONDecoder().decode([Account].self, from: data) {
            self.accounts = decoded
        }
        if self.accounts.isEmpty {
            self.accounts = [
                Account(id: UUID(), name: "Personal", symbolName: "person.fill", colorName: "blue"),
                Account(id: UUID(), name: "Work", symbolName: "briefcase.fill", colorName: "orange")
            ]
            save()
        }
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: "whatsapp_accounts")
        }
    }
    
    func addAccount(name: String, symbolName: String, colorName: String) {
        let account = Account(id: UUID(), name: name, symbolName: symbolName, colorName: colorName)
        accounts.append(account)
        save()
    }
    
    func removeAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        save()
    }
}
