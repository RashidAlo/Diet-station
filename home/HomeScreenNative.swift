//
//  HomeScreenNative.swift
//  DietStationLab — native SwiftUI pilot of the Home widget screen
//
//  Authored by the Prototype Flows session (2026-09-08) against
//  Figma 16828-83399 + Design System plan themes (4786-18146) and
//  days-left shapes (4798-19569). The web twin lives at
//  https://rashidalo.github.io/Diet-station/home/ — web is the design
//  source of truth; keep constants in sync with home/index.html.
//
//  Integration (Shell session):
//  1. Add this file to the DietStationLab target.
//  2. Bundle fonts + register in Info.plist (UIAppFonts):
//     UrbaneRounded-Light.ttf, UrbaneRounded-Medium.ttf,
//     UrbaneRounded-DemiBold.ttf, proxima-regular.otf
//     (copies live in the source repo /Fonts and in gh-pages /meal-select).
//  3. Route to HomeScreenNative() from wherever fits your chrome
//     (suggestion: an entry on the admin tab, or long-press the DS logo
//     on HomeGlassTabBar while on /home/).
//  Meal photos + avatar stream from the live gh-pages folder, so this
//  screen needs no image assets.
//
//  Everything below is iOS 26-only (Liquid Glass APIs).
//

import SwiftUI

// MARK: - Palette / constants (mirror home/index.html)

@available(iOS 26.0, *)
private enum DS {
    static let red = Color(red: 237/255, green: 28/255, blue: 36/255)
    static let onColor = Color(red: 249/255, green: 249/255, blue: 249/255)
    static let ink = Color(red: 11/255, green: 14/255, blue: 18/255)
    static let caption = Color(red: 94/255, green: 94/255, blue: 94/255)
    static let assets = "https://rashidalo.github.io/Diet-station/home/"

    static func urbane(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        // Urbane Rounded ships as separate faces; fall back to rounded system
        let name: String
        switch weight {
        case .light: name = "UrbaneRounded-Light"
        case .semibold, .bold: name = "UrbaneRounded-DemiBold"
        default: name = "UrbaneRounded-Medium"
        }
        return .custom(name, size: size)
    }
    static func proxima(_ size: CGFloat) -> Font {
        .custom("ProximaNova-Regular", size: size)
    }
}

// MARK: - State

@available(iOS 26.0, *)
@Observable final class HomeState {
    enum Plan: String, CaseIterable, Identifiable {
        case lifestyle, diet, body, kids
        var id: String { rawValue }
        var words: (String, String) {
            switch self {
            case .lifestyle: return ("Life", "Style")
            case .diet: return ("The", "Diet")
            case .body: return ("BODY", "Building")
            case .kids: return ("Kids", "")
            }
        }
        var label: String {
            switch self {
            case .lifestyle: return "LifeStyle"
            case .diet: return "The Diet"
            case .body: return "BODYBuilding"
            case .kids: return "Kids"
            }
        }
        // gradients mirrored from the web THEMES (reordered stops)
        var gradient: LinearGradient {
            func g(_ stops: [Gradient.Stop]) -> LinearGradient {
                LinearGradient(gradient: Gradient(stops: stops),
                               startPoint: .topTrailing, endPoint: .bottomLeading)
            }
            switch self {
            case .lifestyle:
                return g([.init(color: DS.red.opacity(0.558), location: 0.11),
                          .init(color: Color(red: 1, green: 5/255, blue: 5/255).opacity(0.333), location: 0.30),
                          .init(color: Color(red: 1, green: 150/255, blue: 62/255).opacity(0.9), location: 1.0)])
            case .diet:
                return g([.init(color: DS.red.opacity(0.006), location: 0.36),
                          .init(color: Color(red: 172/255, green: 51/255, blue: 224/255).opacity(0.6), location: 0.96),
                          .init(color: Color(red: 155/255, green: 105/255, blue: 255/255).opacity(0.6), location: 1.0)])
            case .body:
                return g([.init(color: DS.red.opacity(0.003), location: 0.18),
                          .init(color: Color(red: 196/255, green: 0, blue: 3/255).opacity(0.34), location: 0.62),
                          .init(color: Color(red: 63/255, green: 36/255, blue: 116/255).opacity(0.4), location: 1.0)])
            case .kids:
                return g([.init(color: DS.red.opacity(0.003), location: 0.18),
                          .init(color: Color(red: 1, green: 63/255, blue: 63/255).opacity(0.34), location: 0.62),
                          .init(color: Color(red: 1, green: 50/255, blue: 135/255).opacity(0.42), location: 1.0)])
            }
        }
    }

    var plan: Plan = .lifestyle
    var daysLeft: Int = 19          // 19 / 5 / 0 (expired)
    var showPromo = true
    var showDiscounts = true
    var showConsult = true
    var macrosOpen = false
    var stripDay = 0                // 0 today / 1 tomorrow
    var labOpen = false

    struct DayInfo { let word: String; let kcal: Int; let c: Int; let p: Int; let f: Int }
    let days: [DayInfo] = [.init(word: "Today", kcal: 1200, c: 55, p: 87, f: 23),
                           .init(word: "Tomorrow", kcal: 1140, c: 61, p: 78, f: 20)]
    func dateString(_ offset: Int) -> String {
        let d = Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
        return d.formatted(.dateTime.day().month(.abbreviated))
    }
    var endDateString: String {
        let d = Calendar.current.date(byAdding: .day, value: daysLeft, to: .now) ?? .now
        return "Ends " + d.formatted(.dateTime.day().month(.abbreviated))
    }
}

// MARK: - Screen

@available(iOS 26.0, *)
struct HomeScreenNative: View {
    @State private var state = HomeState()
    @Namespace private var glassNS
    var onClose: (() -> Void)? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            DS.red.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    topRow
                    if state.showPromo { promoBanner }
                    widgetGrid
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
                mealSheet
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onLongPressGesture(minimumDuration: 0.6) { state.labOpen = true }
        .sheet(isPresented: $state.labOpen) { labSheet.presentationDetents([.medium]) }
        .animation(.spring(duration: 0.45), value: state.showPromo)
        .animation(.spring(duration: 0.45), value: state.showDiscounts)
        .animation(.spring(duration: 0.45), value: state.showConsult)
        .animation(.spring(duration: 0.4), value: state.plan)
    }

    // MARK: top row — stories strip + glass docks

    private var topRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: DS.assets + "avatar.png")) { $0.resizable() }
                    placeholder: { Circle().fill(.white.opacity(0.2)) }
                    .frame(width: 48, height: 48).clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("☀︎ صبحك الله بالخير").font(DS.proxima(12)).foregroundStyle(DS.onColor)
                    Text("Abdulrahman").font(DS.urbane(14)).foregroundStyle(.white)
                }
            }
            Spacer()
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    dock { Image(systemName: "star.fill").font(.system(size: 24)) }
                    dock {
                        Image(systemName: "bell.fill").font(.system(size: 24))
                            .overlay(alignment: .topTrailing) {
                                Circle().fill(.yellow).frame(width: 6, height: 6).offset(x: 4, y: -2)
                            }
                    }
                }
            }
        }
        .frame(height: 68)
    }

    private func dock<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .foregroundStyle(.white)
            .frame(width: 69, height: 68)
            .glassEffect(.regular.tint(DS.red.opacity(0.3)).interactive(),
                         in: .rect(cornerRadius: 23))
    }

    // MARK: promo banner

    private var promoBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                (Text("KD").font(DS.proxima(9)) + Text("109 Discount Expiring").font(DS.urbane(14, .semibold)))
                    .foregroundStyle(DS.onColor)
                Text("Rewnew before you lose the benefit")
                    .font(DS.urbane(12, .light)).foregroundStyle(DS.onColor)
            }
            Spacer()
            pill("Renew")
        }
        .padding(.horizontal, 16)
        .frame(height: 72)
        .glassEffect(.regular.tint(DS.red.opacity(0.3)), in: .rect(cornerRadius: 23))
        .glassEffectID("promo", in: glassNS)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    private func pill(_ label: String, urgent: Bool = false) -> some View {
        Text(label)
            .font(DS.urbane(12))
            .foregroundStyle(urgent ? DS.ink : DS.onColor)
            .frame(maxWidth: .infinity).frame(height: 36)
            .background(urgent ? AnyShapeStyle(DS.onColor) : AnyShapeStyle(.white.opacity(0.16)),
                        in: Capsule())
            .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: widget grid — the modular system

    private var widgetGrid: some View {
        GlassEffectContainer(spacing: 16) {
            HStack(alignment: .top, spacing: 20) {
                planWidget.frame(width: 191)
                VStack(spacing: 16) {
                    daysWidget
                    if state.showDiscounts { discountsWidget }
                    if state.showConsult { consultWidget }
                }
                .frame(width: 151)
            }
            .frame(height: state.showPromo ? 288 : 372)
        }
    }

    private var planWidget: some View {
        ZStack {
            state.plan.gradient
            if state.plan == .kids {
                Image(systemName: "star.fill").foregroundStyle(.yellow)
                    .font(.system(size: 26)).rotationEffect(.degrees(-20))
                    .position(x: 24, y: 128)
                Image(systemName: "star.fill").foregroundStyle(.yellow)
                    .font(.system(size: 16)).rotationEffect(.degrees(15))
                    .position(x: 10, y: 160)
            }
            VStack(alignment: .leading) {
                Text("My Subscription").font(DS.proxima(12)).foregroundStyle(DS.onColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                let words = state.plan.words
                (Text(words.0).font(DS.urbane(19.6, state.plan == .kids ? .semibold : .light))
                    .foregroundStyle(.white.opacity(state.plan == .kids ? 1 : 0.6))
                 + Text(words.1).font(DS.urbane(19.6, .semibold)).foregroundStyle(.white))
                    .shadow(color: .black.opacity(0.1), radius: 5.6, y: 1.4)
                Button { } label: {
                    Text("Change").font(DS.urbane(14)).foregroundStyle(DS.onColor)
                        .frame(maxWidth: .infinity).frame(height: 41)
                        .background(.white.opacity(0.16), in: Capsule())
                }
                .padding(.top, 10)
            }
            .padding(EdgeInsets(top: 28, leading: 20, bottom: 22, trailing: 20))
        }
        .frame(maxHeight: .infinity)
        .glassEffect(.regular.tint(DS.red.opacity(0.3)), in: .rect(cornerRadius: 30))
        .glassEffectID("plan", in: glassNS)
        .clipShape(RoundedRectangle(cornerRadius: 30))
    }

    // days-left: re-shapes with the height it is given (tall / wide / slim)
    private var daysWidget: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let shape: DaysShape = h >= 168 ? .tall : (h < 82 ? .slim : .wide)
            DaysContent(state: state, shape: shape)
        }
        .frame(maxHeight: .infinity)
        .glassEffect(.regular.tint(DS.red.opacity(0.3)), in: .rect(cornerRadius: 27))
        .glassEffectID("days", in: glassNS)
        .layoutPriority(1.6)
    }

    private var discountsWidget: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("KD 32").font(DS.urbane(12, .semibold)).foregroundStyle(DS.onColor)
                Text("Discounts").font(DS.proxima(12)).foregroundStyle(DS.onColor.opacity(0.8))
            }
            Spacer()
            Image(systemName: "bag.fill").font(.system(size: 22)).foregroundStyle(.white)
        }
        .padding(.horizontal, 19)
        .frame(height: 60)
        .glassEffect(.regular.tint(DS.red.opacity(0.3)).interactive(), in: .rect(cornerRadius: 20))
        .glassEffectID("disc", in: glassNS)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private var consultWidget: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar").font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.85))
            Text("Book Consultation").font(DS.urbane(12)).foregroundStyle(DS.onColor)
                .frame(width: 84, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 84, maxHeight: .infinity)   // days' layoutPriority must not crush it
        .glassEffect(.regular.tint(DS.red.opacity(0.3)).interactive(), in: .rect(cornerRadius: 20))
        .glassEffectID("consult", in: glassNS)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: meal sheet

    private var mealSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            sheetHeader.padding(.top, 30).padding(.horizontal, 24)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 29) {
                    HStack(spacing: 12) {
                        mealCard("meal1.jpg", "Chicken Machbous", 245)
                        mealCard("meal2.jpg", "Egg Sandwich", 343)
                        mealCard("meal3.jpg", "Biryani with tomato sauce and Veggies", 554)
                    }
                    Rectangle().fill(Color(white: 0.925)).frame(width: 1, height: 135)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.frame(in: .named("strip")).minX
                        } action: { x in
                            // the divider is the day boundary (hysteresis 38% / 52%)
                            let w = UIScreen.main.bounds.width
                            if x < w * 0.38, state.stripDay == 0 {
                                withAnimation(.spring(duration: 0.35)) { state.stripDay = 1 }
                            } else if x > w * 0.52, state.stripDay == 1 {
                                withAnimation(.spring(duration: 0.35)) { state.stripDay = 0 }
                            }
                        }
                    HStack(spacing: 12) {
                        mealCard("meal1.jpg", "Chicken Machbous", 245)
                        mealCard("meal2.jpg", "Egg Sandwich", 343)
                        mealCard("meal3.jpg", "Biryani with tomato sauce and Veggies", 554)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
            .coordinateSpace(name: "strip")
            Spacer(minLength: 140)
        }
        .frame(maxWidth: .infinity, minHeight: 520, alignment: .top)
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38))
    }

    private var sheetHeader: some View {
        let info = state.days[state.stripDay]
        return HStack(spacing: 14) {
            Image(systemName: "fork.knife").font(.system(size: 20)).foregroundStyle(DS.red)
                .frame(width: 48, height: 48)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.08), radius: 6.65)
            VStack(alignment: .leading, spacing: 1) {
                Text(info.word).font(DS.urbane(16, .semibold)).foregroundStyle(DS.ink)
                    .contentTransition(.numericText())
                Text(state.dateString(state.stripDay)).font(DS.proxima(12)).foregroundStyle(DS.caption)
            }
            Spacer()
            Button { withAnimation(.spring(duration: 0.45)) { state.macrosOpen.toggle() } } label: {
                HStack(spacing: 3) {
                    // verbatim: interpolated Ints localize ("1,200") — web shows "1200"
                    Text(verbatim: "\(info.kcal)").font(DS.urbane(16, .semibold)).foregroundStyle(DS.ink)
                        .contentTransition(.numericText())
                    Text("Kcal").font(DS.urbane(10, .light)).foregroundStyle(Color(white: 0.6))
                    if state.macrosOpen {
                        HStack(spacing: 8) {
                            macro(info.c, "C"); macro(info.p, "P"); macro(info.f, "F")
                        }
                        .padding(.leading, 8)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 16).frame(height: 48)
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.08), radius: 6.65)
            }
        }
        .frame(height: 51)
    }

    private func macro(_ v: Int, _ u: String) -> some View {
        HStack(spacing: 2) {
            Text("\(v)").font(DS.urbane(13)).foregroundStyle(DS.ink)
                .contentTransition(.numericText())
            Text(u).font(DS.proxima(9)).foregroundStyle(DS.ink)
        }
    }

    private func mealCard(_ image: String, _ name: String, _ kcal: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: DS.assets + image)) { $0.resizable().scaledToFill() }
                placeholder: { Color(white: 0.92) }
                .frame(width: 166.9, height: 236).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.41), .black.opacity(0.81)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 139.6)
            VStack(alignment: .leading, spacing: 6) {
                Text(name).font(DS.urbane(15.4, .semibold)).foregroundStyle(DS.onColor)
                    .lineLimit(2).multilineTextAlignment(.leading)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(kcal)").font(DS.urbane(16.5, .semibold))
                    Text("Kcal").font(DS.proxima(11))
                }
                .foregroundStyle(DS.onColor)
                .shadow(color: .black.opacity(0.49), radius: 2.1, y: 1)
            }
            .padding(EdgeInsets(top: 0, leading: 12.6, bottom: 16.8, trailing: 12.6))
        }
        .frame(width: 166.9, height: 236)
        .clipShape(RoundedRectangle(cornerRadius: 25.2))
    }

    // MARK: native lab sheet (long-press)

    private var labSheet: some View {
        NavigationStack {
            Form {
                Section("Subscription plan") {
                    Picker("Plan", selection: $state.plan) {
                        ForEach(HomeState.Plan.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Days left") {
                    Picker("Days", selection: $state.daysLeft) {
                        Text("19 days").tag(19); Text("5 days").tag(5); Text("Expired").tag(0)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Widgets on screen") {
                    Toggle("Promo banner", isOn: $state.showPromo)
                    Toggle("Discounts", isOn: $state.showDiscounts)
                    Toggle("Consultation", isOn: $state.showConsult)
                }
                if let onClose {
                    Section { Button("Exit native pilot", role: .destructive) { onClose() } }
                }
            }
            .navigationTitle("Native Home — Lab")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Days-left widget content (the documented shapes)

@available(iOS 26.0, *)
private enum DaysShape { case slim, wide, tall }

@available(iOS 26.0, *)
private struct DaysContent: View {
    let state: HomeState
    let shape: DaysShape

    var expired: Bool { state.daysLeft == 0 }

    var ring: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.25), lineWidth: 3)
            Circle().trim(from: 0, to: min(1, Double(state.daysLeft) / 30))
                .stroke(.white, style: .init(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(state.daysLeft)")
                .font(DS.urbane(shape == .slim ? 16 : 20, .semibold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .frame(width: shape == .slim ? 40 : 50, height: shape == .slim ? 40 : 50)
    }

    var texts: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Days Left").font(DS.urbane(12)).foregroundStyle(DS.onColor)
            Text(expired ? "Expired" : state.endDateString)
                .font(DS.proxima(10)).foregroundStyle(DS.onColor.opacity(0.65))
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)   // wide shape leaves ~63pt beside the ring
    }

    var renew: some View {
        Text("Renew").font(DS.urbane(12, expired ? .semibold : .medium))
            .foregroundStyle(expired ? DS.ink : DS.onColor)
            .frame(maxWidth: .infinity).frame(height: 36)
            .background(expired ? AnyShapeStyle(DS.onColor) : AnyShapeStyle(.white.opacity(0.16)),
                        in: Capsule())
    }

    var body: some View {
        Group {
            switch shape {
            case .slim:
                HStack(spacing: 8) { ring; texts; Spacer(minLength: 0) }
            case .wide:
                VStack(spacing: 8) {
                    HStack(spacing: 8) { ring; texts; Spacer(minLength: 0) }
                    renew
                }
            case .tall:
                VStack(alignment: .leading, spacing: 0) {
                    ring
                    Spacer()
                    texts
                    Spacer()
                    renew
                }
            }
        }
        .padding(EdgeInsets(top: shape == .tall ? 16 : 12, leading: 16, bottom: 12, trailing: 14))
        .animation(.spring(duration: 0.35), value: state.daysLeft)
    }
}

@available(iOS 26.0, *)
#Preview {
    HomeScreenNative()
}
