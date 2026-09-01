import SwiftUI

struct ContentView: View {
    @StateObject private var accountStore = AccountStore()
    @State private var selectedAccountId: UUID?
    @State private var showingAddAccount = false
    @State private var newAccountName = ""
    @State private var selectedSymbol = "message.fill"
    @State private var selectedColor = "blue"
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selectedAccountId) {
                ForEach(accountStore.accounts) { account in
                    NavigationLink(value: account.id) {
                        Label {
                            Text(account.name)
                        } icon: {
                            Image(systemName: account.symbolName)
                                .foregroundColor(account.color)
                        }
                    }
                    .contextMenu {
                        Button("Delete") {
                            accountStore.removeAccount(id: account.id)
                            WebViewManager.shared.removeWebView(for: account.id)
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
        } detail: {
            HStack(spacing: 0) {
                if columnVisibility == .detailOnly {
                    VStack(spacing: 12) {
                        ForEach(accountStore.accounts) { account in
                            HStack(spacing: 4) {
                                // Indicator capsule (Discord style)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(selectedAccountId == account.id ? Color.primary : Color.clear)
                                    .frame(width: 4, height: selectedAccountId == account.id ? 24 : 0)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: selectedAccountId)
                                
                                Button(action: {
                                    selectedAccountId = account.id
                                }) {
                                    Image(systemName: account.symbolName)
                                        .font(.title2)
                                        .foregroundColor(selectedAccountId == account.id ? .white : account.color)
                                        .frame(width: 44, height: 44)
                                        .background(selectedAccountId == account.id ? account.color : account.color.opacity(0.15))
                                        .clipShape(selectedAccountId == account.id ? RoundedRectangle(cornerRadius: 14) : RoundedRectangle(cornerRadius: 22))
                                        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: selectedAccountId)
                                }
                                .buttonStyle(.plain)
                                .help(account.name)
                            }
                            .frame(width: 56)
                        }
                        
                        Spacer()
                        
                        // Refresh button
                        Button(action: {
                            if let selectedId = selectedAccountId {
                                WebViewManager.shared.reloadWebView(for: selectedId)
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .frame(width: 44, height: 44)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .help("Refresh WhatsApp")
                        .disabled(selectedAccountId == nil)
                        
                        // Expand sidebar button at the bottom
                        Button(action: {
                            columnVisibility = .all
                        }) {
                            Image(systemName: "sidebar.left")
                                .font(.title3)
                                .foregroundColor(.secondary)
                                .frame(width: 44, height: 44)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .help("Show Sidebar")
                        .padding(.bottom, 12)
                    }
                    .padding(.top, 16)
                    .frame(width: 60)
                    .background(Color(.windowBackgroundColor))
                    
                    Divider()
                }
                
                ZStack {
                    if accountStore.accounts.isEmpty {
                        Text("Select or add an account")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(accountStore.accounts) { account in
                            if selectedAccountId == account.id {
                                WhatsAppWebView(accountId: account.id)
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if let selectedId = selectedAccountId {
                            WebViewManager.shared.reloadWebView(for: selectedId)
                        }
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(selectedAccountId == nil)
                    .help("Refresh WhatsApp")
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { 
                        selectedSymbol = accountStore.availableSymbols.first ?? "message.fill"
                        selectedColor = accountStore.availableColors.first ?? "blue"
                        showingAddAccount = true 
                    }) {
                        Label("Add Account", systemImage: "plus")
                    }
                }
            }
        }
        .onAppear {
            if selectedAccountId == nil {
                selectedAccountId = accountStore.accounts.first?.id
            }
        }
        .sheet(isPresented: $showingAddAccount) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Add New Account")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Account Name").font(.subheadline).foregroundColor(.secondary)
                    TextField("e.g. Personal, Work, Support", text: $newAccountName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Select Icon").font(.subheadline).foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(accountStore.availableSymbols, id: \.self) { symbol in
                                Button(action: { selectedSymbol = symbol }) {
                                    Image(systemName: symbol)
                                        .font(.title3)
                                        .frame(width: 32, height: 32)
                                        .background(selectedSymbol == symbol ? Color.accentColor.opacity(0.2) : Color(.windowBackgroundColor))
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.accentColor, lineWidth: selectedSymbol == symbol ? 1.5 : 0)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 2)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Select Color").font(.subheadline).foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(accountStore.availableColors, id: \.self) { colorName in
                                Button(action: { selectedColor = colorName }) {
                                    Circle()
                                        .fill(colorForName(colorName))
                                        .frame(width: 24, height: 24)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: selectedColor == colorName ? 2 : 0)
                                        )
                                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 2)
                    }
                }
                
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showingAddAccount = false
                        newAccountName = ""
                    }
                    Button("Add") {
                        if !newAccountName.isEmpty {
                            accountStore.addAccount(
                                name: newAccountName,
                                symbolName: selectedSymbol,
                                colorName: selectedColor
                            )
                            showingAddAccount = false
                            newAccountName = ""
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top, 5)
            }
            .padding(20)
            .frame(width: 360)
        }
    }
    
    private func colorForName(_ name: String) -> Color {
        switch name {
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

#Preview {
    ContentView()
}
