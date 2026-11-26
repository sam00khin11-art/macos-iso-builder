import SwiftUI

// MARK: - Темы (дизайн)

struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let background: Color
    let card: Color
    let accent: Color
    let text: Color
    let secondary: Color
    let gradient: [Color]
    let scheme: ColorScheme

    static let green = AppTheme(
        id: "green", name: "Зелёная",
        background: Color(red: 0.95, green: 0.98, blue: 0.95),
        card: .white, accent: Color(red: 0.13, green: 0.65, blue: 0.27),
        text: Color(red: 0.08, green: 0.12, blue: 0.09), secondary: .gray,
        gradient: [Color(red: 0.13, green: 0.65, blue: 0.27), Color(red: 0.62, green: 0.84, blue: 0.2)],
        scheme: .light)

    static let space = AppTheme(
        id: "space", name: "Космос",
        background: Color(red: 0.06, green: 0.05, blue: 0.14),
        card: Color(red: 0.13, green: 0.11, blue: 0.27),
        accent: Color(red: 0.62, green: 0.45, blue: 1.0),
        text: .white, secondary: Color.white.opacity(0.6),
        gradient: [Color(red: 0.35, green: 0.2, blue: 0.85), Color(red: 0.95, green: 0.4, blue: 0.7)],
        scheme: .dark)

    static let candy = AppTheme(
        id: "candy", name: "Конфетка",
        background: Color(red: 1.0, green: 0.95, blue: 0.97),
        card: .white, accent: Color(red: 0.95, green: 0.3, blue: 0.55),
        text: Color(red: 0.25, green: 0.1, blue: 0.17), secondary: .gray,
        gradient: [Color(red: 1.0, green: 0.45, blue: 0.6), Color(red: 1.0, green: 0.75, blue: 0.35)],
        scheme: .light)

    static let ocean = AppTheme(
        id: "ocean", name: "Океан",
        background: Color(red: 0.92, green: 0.97, blue: 1.0),
        card: .white, accent: Color(red: 0.1, green: 0.5, blue: 0.95),
        text: Color(red: 0.05, green: 0.12, blue: 0.22), secondary: .gray,
        gradient: [Color(red: 0.1, green: 0.5, blue: 0.95), Color(red: 0.2, green: 0.85, blue: 0.85)],
        scheme: .light)

    static let all: [AppTheme] = [.green, .space, .candy, .ocean]
}

final class ThemeManager: ObservableObject {
    private let key = "sberkids.theme"
    private let radiusKey = "sberkids.radius"

    @Published var current: AppTheme {
        didSet { UserDefaults.standard.set(current.id, forKey: key) }
    }
    @Published var corner: Double {
        didSet { UserDefaults.standard.set(corner, forKey: radiusKey) }
    }

    init() {
        let id = UserDefaults.standard.string(forKey: key)
        current = AppTheme.all.first { $0.id == id } ?? .green
        let r = UserDefaults.standard.double(forKey: radiusKey)
        corner = r == 0 ? 20 : r
    }
}

// MARK: - Модели

struct Transaction: Identifiable, Codable {
    var id = UUID()
    var title: String
    var amount: Double
    var isIncome: Bool
    var date = Date()
}

struct Chore: Identifiable, Codable {
    var id = UUID()
    var title: String
    var reward: Double
    var done = false
}

struct Goal: Identifiable, Codable {
    var id = UUID()
    var title: String
    var emoji: String
    var target: Double
    var saved: Double = 0
}

// MARK: - Хранилище

final class Store: ObservableObject {
    @Published var transactions: [Transaction] = [] { didSet { save() } }
    @Published var chores: [Chore] = [] { didSet { save() } }
    @Published var goals: [Goal] = [] { didSet { save() } }

    private let key = "sberkids.store"
    private struct Snapshot: Codable {
        var t: [Transaction]; var c: [Chore]; var g: [Goal]
    }

    var balance: Double {
        transactions.reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(Snapshot.self, from: data) {
            transactions = s.t; chores = s.c; goals = s.g
        } else {
            transactions = [Transaction(title: "Карманные деньги", amount: 500, isIncome: true)]
            chores = [
                Chore(title: "Убрать комнату", reward: 100),
                Chore(title: "Вынести мусор", reward: 50),
                Chore(title: "Сделать уроки", reward: 80)
            ]
            goals = [Goal(title: "Велосипед", emoji: "🚲", target: 15000)]
        }
    }

    private func save() {
        let s = Snapshot(t: transactions, c: chores, g: goals)
        if let data = try? JSONEncoder().encode(s) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ title: String, amount: Double, income: Bool) {
        guard amount > 0 else { return }
        if !income && amount > balance { return }
        transactions.insert(Transaction(title: title, amount: amount, isIncome: income), at: 0)
    }

    func complete(_ chore: Chore) {
        guard let i = chores.firstIndex(where: { $0.id == chore.id }), !chores[i].done else { return }
        chores[i].done = true
        add("Задание: \(chore.title)", amount: chore.reward, income: true)
    }

    func resetChores() {
        for i in chores.indices { chores[i].done = false }
    }

    @discardableResult
    func deposit(_ amount: Double, to goal: Goal) -> Bool {
        guard amount > 0, amount <= balance,
              let i = goals.firstIndex(where: { $0.id == goal.id }) else { return false }
        goals[i].saved += amount
        transactions.insert(Transaction(title: "Копилка: \(goal.title)", amount: amount, isIncome: false), at: 0)
        return true
    }
}

// MARK: - Вход

@main
struct SberKidsApp: App {
    @StateObject private var theme = ThemeManager()
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(theme)
                .environmentObject(store)
                .preferredColorScheme(theme.current.scheme)
                .tint(theme.current.accent)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        TabView {
            HomeView().tabItem { Label("Главная", systemImage: "house.fill") }
            ChoresView().tabItem { Label("Задания", systemImage: "checkmark.circle.fill") }
            GoalsView().tabItem { Label("Копилки", systemImage: "banknote.fill") }
            SettingsView().tabItem { Label("Дизайн", systemImage: "paintbrush.fill") }
        }
        .animation(.easeInOut, value: theme.current)
    }
}

// MARK: - Общие компоненты

struct Screen<Content: View>: View {
    @EnvironmentObject var theme: ThemeManager
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            ZStack {
                theme.current.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) { content }.padding()
                }
            }
            .navigationTitle(title)
        }
    }
}

struct CardBox<Content: View>: View {
    @EnvironmentObject var theme: ThemeManager
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.current.card)
            .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
    }
}

func money(_ v: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.maximumFractionDigits = 0
    return (f.string(from: NSNumber(value: v)) ?? "0") + " ₽"
}

// MARK: - Главная

struct HomeView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var store: Store
    @State private var sheet: SheetKind?

    enum SheetKind: Identifiable {
        case topUp, spend
        var id: Int { hashValue }
    }

    var body: some View {
        Screen(title: "SberKids") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Мой баланс").font(.subheadline).opacity(0.85)
                Text(money(store.balance)).font(.system(size: 40, weight: .bold, design: .rounded))
                HStack(spacing: 12) {
                    actionButton("Пополнить", "plus.circle.fill") { sheet = .topUp }
                    actionButton("Потратить", "cart.fill") { sheet = .spend }
                }
                .padding(.top, 8)
            }
            .foregroundStyle(.white)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: theme.current.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))

            CardBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("История").font(.headline).foregroundStyle(theme.current.text)
                    ForEach(store.transactions.prefix(15)) { t in
                        HStack {
                            Image(systemName: t.isIncome ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                                .foregroundStyle(t.isIncome ? .green : .orange)
                            VStack(alignment: .leading) {
                                Text(t.title).foregroundStyle(theme.current.text)
                                Text(t.date, style: .date).font(.caption).foregroundStyle(theme.current.secondary)
                            }
                            Spacer()
                            Text((t.isIncome ? "+" : "−") + money(t.amount))
                                .fontWeight(.semibold)
                                .foregroundStyle(t.isIncome ? .green : theme.current.text)
                        }
                    }
                }
            }
        }
        .sheet(item: $sheet) { kind in
            AmountSheet(title: kind == .topUp ? "Пополнить" : "Потратить",
                        placeholder: kind == .topUp ? "Откуда деньги" : "На что тратим") { name, amount in
                store.add(name.isEmpty ? (kind == .topUp ? "Пополнение" : "Покупка") : name,
                          amount: amount, income: kind == .topUp)
            }
            .presentationDetents([.medium])
        }
    }

    private func actionButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .padding(.vertical, 10).padding(.horizontal, 14)
                .background(.white.opacity(0.25))
                .clipShape(Capsule())
        }
    }
}

struct AmountSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let placeholder: String
    let onDone: (String, Double) -> Void
    @State private var name = ""
    @State private var amount = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField(placeholder, text: $name)
                TextField("Сумма", text: $amount).keyboardType(.numberPad)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") {
                        onDone(name, Double(amount) ?? 0)
                        dismiss()
                    }
                    .disabled((Double(amount) ?? 0) <= 0)
                }
            }
        }
    }
}

// MARK: - Задания

struct ChoresView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var store: Store
    @State private var showAdd = false
    @State private var newTitle = ""
    @State private var newReward = ""

    var body: some View {
        Screen(title: "Задания") {
            ForEach(store.chores) { chore in
                CardBox {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chore.title)
                                .strikethrough(chore.done)
                                .foregroundStyle(theme.current.text)
                            Text("+" + money(chore.reward)).font(.caption)
                                .foregroundStyle(theme.current.accent)
                        }
                        Spacer()
                        Button {
                            withAnimation { store.complete(chore) }
                        } label: {
                            Image(systemName: chore.done ? "checkmark.circle.fill" : "circle")
                                .font(.title)
                                .foregroundStyle(theme.current.accent)
                        }
                        .disabled(chore.done)
                    }
                }
            }
            Button("Сбросить выполненные") { store.resetChores() }
                .foregroundStyle(theme.current.secondary)
        }
        .overlay(alignment: .bottomTrailing) {
            Button { showAdd = true } label: {
                Image(systemName: "plus").font(.title2.bold()).foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(theme.current.accent).clipShape(Circle())
            }
            .padding(20)
        }
        .alert("Новое задание", isPresented: $showAdd) {
            TextField("Название", text: $newTitle)
            TextField("Награда", text: $newReward).keyboardType(.numberPad)
            Button("Добавить") {
                if !newTitle.isEmpty, let r = Double(newReward), r > 0 {
                    store.chores.append(Chore(title: newTitle, reward: r))
                }
                newTitle = ""; newReward = ""
            }
            Button("Отмена", role: .cancel) { newTitle = ""; newReward = "" }
        }
    }
}

// MARK: - Копилки

struct GoalsView: View {
    @EnvironmentObject var theme: ThemeManager
    @EnvironmentObject var store: Store
    @State private var depositGoal: Goal?
    @State private var showNew = false

    var body: some View {
        Screen(title: "Копилки") {
            ForEach(store.goals) { goal in
                CardBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(goal.emoji).font(.largeTitle)
                            VStack(alignment: .leading) {
                                Text(goal.title).font(.headline).foregroundStyle(theme.current.text)
                                Text("\(money(goal.saved)) из \(money(goal.target))")
                                    .font(.caption).foregroundStyle(theme.current.secondary)
                            }
                            Spacer()
                        }
                        ProgressView(value: min(goal.saved, goal.target), total: max(goal.target, 1))
                            .tint(theme.current.accent)
                        Button("Положить деньги") { depositGoal = goal }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            Button { showNew = true } label: {
                Label("Новая цель", systemImage: "plus.circle.fill")
            }
        }
        .sheet(item: $depositGoal) { goal in
            AmountSheet(title: "В копилку «\(goal.title)»", placeholder: "Комментарий") { _, amount in
                store.deposit(amount, to: goal)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showNew) {
            NewGoalSheet { store.goals.append($0) }
                .presentationDetents([.medium])
        }
    }
}

struct NewGoalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onDone: (Goal) -> Void
    @State private var title = ""
    @State private var emoji = "🎯"
    @State private var target = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Эмодзи", text: $emoji)
                TextField("На что копим", text: $title)
                TextField("Сумма цели", text: $target).keyboardType(.numberPad)
            }
            .navigationTitle("Новая цель")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Создать") {
                        onDone(Goal(title: title, emoji: String(emoji.prefix(2)), target: Double(target) ?? 0))
                        dismiss()
                    }
                    .disabled(title.isEmpty || (Double(target) ?? 0) <= 0)
                }
            }
        }
    }
}

// MARK: - Настройки дизайна

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeManager

    var body: some View {
        Screen(title: "Дизайн") {
            ForEach(AppTheme.all) { t in
                Button {
                    withAnimation { theme.current = t }
                } label: {
                    HStack(spacing: 14) {
                        LinearGradient(colors: t.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        Text(t.name).font(.headline).foregroundStyle(theme.current.text)
                        Spacer()
                        if theme.current == t {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.current.accent)
                        }
                    }
                    .padding()
                    .background(theme.current.card)
                    .clipShape(RoundedRectangle(cornerRadius: theme.corner, style: .continuous))
                }
            }

            CardBox {
                VStack(alignment: .leading) {
                    Text("Скругление углов: \(Int(theme.corner))")
                        .foregroundStyle(theme.current.text)
                    Slider(value: $theme.corner, in: 4...36, step: 1)
                }
            }
        }
    }
}
