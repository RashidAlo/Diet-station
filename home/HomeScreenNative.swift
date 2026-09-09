//
//  HomeScreenNative.swift
//  DietStationLab — native SwiftUI pilot of the Home widget screen
//
//  Authored by the Prototype Flows session (2026-09-08) against
//  Figma 16828-83399 + Design System plan themes (4786-18146) and
//  days-left shapes (4798-19569). The web twin lives at
//  https://rashidalo.github.io/Diet-station/home/ — THIS native view is
//  the design standard (Rashid, 2026-09-08); the web twin replicates
//  settled native rounds, with fallbacks only for iOS-only materials.
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
import CoreText
import WebKit

// MARK: - Palette / constants (mirror home/index.html)

@available(iOS 26.0, *)
/// Rashid's licensed Avenir Next World files (Arabic coverage) ride
/// gh-pages like every lab asset: downloaded once into Caches, registered
/// with CoreText at runtime — no bundle/Info.plist plumbing needed, and a
/// font update ships like any deploy.
@available(iOS 26.0, *)
enum DSFontLoader {
    static let files = ["AvenirNextWorld-Medium.otf",
                        "AvenirNextWorld-Demi.otf",
                        "AvenirNextWorld-Bold.otf"]

    static var cacheDir: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DSFonts", isDirectory: true)
    }

    /// warm launches: everything already cached registers before first render
    static let registerCached: Void = {
        for f in files {
            let local = cacheDir.appendingPathComponent(f)
            if FileManager.default.fileExists(atPath: local.path) {
                CTFontManagerRegisterFontsForURL(local as CFURL, .process, nil)
            }
        }
    }()

    /// cold first launch: fetch the missing ones, register, report if any landed
    static func downloadMissing() async -> Bool {
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        var landed = false
        for f in files {
            let local = cacheDir.appendingPathComponent(f)
            // a face that's already registered (e.g. bundled by the shell)
            // needs no download — file name minus extension == PostScript name
            guard UIFont(name: String(f.dropLast(4)), size: 12) == nil,
                  !FileManager.default.fileExists(atPath: local.path),
                  let url = URL(string: DS.assets + "fonts/" + f),
                  let (tmp, _) = try? await URLSession.shared.download(from: url) else { continue }
            try? FileManager.default.moveItem(at: tmp, to: local)
            CTFontManagerRegisterFontsForURL(local as CFURL, .process, nil)
            landed = true
        }
        return landed
    }
}

private enum DS {
    static let red = Color(red: 237/255, green: 28/255, blue: 36/255)
    /// THE CRADLE LAW (Rashid 2026-09-09, v3 — supersedes the CC capsules):
    /// a container's corner derives from the pill it holds — R = pill radius
    /// + the pill's inset from the edge — so the two curves run concentric
    /// and "cradle each other" at every size. The subscription card is the
    /// reference (Change pill r20.5 + 20 inset ~= its 40.5 corner).
    static func cradle(pill: CGFloat, inset: CGFloat) -> CGFloat { pill + inset }
    /// the big-card radius — the subscription card's cradle value; every
    /// platter-class card shares it so large surfaces cohere
    static var platter: CGFloat { cradle(pill: 20.5, inset: 20) }
    /// PADDING FOLLOWS CURVATURE (Rashid's rule): the rounder a container,
    /// the deeper its content inset, so text never crowds the corner arcs.
    /// The subscription card validates the ratio (r40.5 -> insets ~20).
    static func inset(for radius: CGFloat) -> CGFloat { max(14, (radius * 0.5).rounded()) }
    /// Pill-less tiles (star/bell docks, discounts, consult) are VERY
    /// rounded squares — 36% of the minor side, capped, never capsules
    /// (the Figma dock feel: 68pt dock -> 24, 60pt tile -> 22).
    static func tile(_ minSide: CGFloat) -> CGFloat {
        min(26, (0.36 * minSide).rounded())
    }
    /// One gap everywhere in the red zone — grid gutters, column stacks,
    /// action-bar-to-banner, banner-to-grid (Rashid: cohesive spacing).
    static let gap: CGFloat = 16
    static let onColor = Color(red: 249/255, green: 249/255, blue: 249/255)
    static let ink = Color(red: 11/255, green: 14/255, blue: 18/255)
    static let caption = Color(red: 94/255, green: 94/255, blue: 94/255)
    static let assets = "https://rashidalo.github.io/Diet-station/home/"
    /// Arabic text wears Avenir Next World (Rashid); name cascade because
    /// custom-font misses fall back silently
    static func avenirWorld(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        for name in ["AvenirNextWorld-Medium", "Avenir Next World", "AvenirNextLTW05-Medium"] {
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        return .system(size: size, weight: weight)
    }

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
    var consultBooked = false       // Figma 16367:78807 "Booked" state
    var discountsEmpty = false      // no coupons: bare "Coupons" tile
    /// lab override for the days widget's arrangement (Figma 4798:19569
    /// defines four shapes; auto derives from the column height as usual)
    enum DaysShapeChoice: String, CaseIterable, Identifiable {
        case auto, tall, wide, compact, slim
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }
    var daysShapeChoice: DaysShapeChoice = .auto
    var stripDay = 1                // index into days — boots on Today
    var labOpen = false
    var couponsOpen = false         // rewards web flow over this screen
    var calendarOpen = false        // meal-select web flow over this screen

    /* the carousel spans Yesterday .. Today+4; past Tomorrow the word slot
       carries the weekday name and the date line carries the date */
    struct DayInfo { let off: Int; let kcal: Int; let c: Int; let p: Int; let f: Int }
    let days: [DayInfo] = [.init(off: -1, kcal: 1185, c: 52, p: 84, f: 22),
                           .init(off: 0,  kcal: 1200, c: 55, p: 87, f: 23),
                           .init(off: 1,  kcal: 1140, c: 61, p: 78, f: 20),
                           .init(off: 2,  kcal: 1225, c: 58, p: 90, f: 24),
                           .init(off: 3,  kcal: 1090, c: 49, p: 75, f: 19),
                           .init(off: 4,  kcal: 1175, c: 54, p: 82, f: 21)]
    func dayWord(_ ix: Int) -> String {
        switch days[ix].off {
        case -1: return "Yesterday"
        case 0:  return "Today"
        case 1:  return "Tomorrow"
        default:
            let d = Calendar.current.date(byAdding: .day, value: days[ix].off, to: .now) ?? .now
            return d.formatted(.dateTime.weekday(.wide))
        }
    }
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
    /* entrance choreography: widgets arrive staggered, then the days dial
       sweeps to its value while the number counts down from 30 */
    @State private var arrived = false
    @State private var dialNumber = 30
    @State private var dialFrac: Double = 1.0

    /// Figma 16828:83478 — at three days left (and once EXPIRED, per Rashid)
    /// the days widget MERGES into an urgent offer banner on top and the grid
    /// reflows around its absence; expired swaps in hotter messaging
    private var urgent: Bool { state.daysLeft == 3 || state.daysLeft == 0 }

    var body: some View {
        ZStack(alignment: .bottom) {
            DS.red.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: DS.gap) {
                    arrival(topRow, 0)
                    if urgent { arrival(urgentBanner, 1) }
                    else if state.showPromo { arrival(promoBanner, 1) }
                    widgetGrid
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
                arrival(mealSheet, 4)
            }
            .ignoresSafeArea(edges: .bottom)
            arrival(tabBar, 5)
                .padding(.bottom, 16)
        }
        /* THE lab house gesture (Rashid 2026-09-09, clarified): THREE-FINGER
           single tap-and-hold. The single-finger triple-tap-hold stays as a
           Debug/simulator fallback only — a Mac mouse cannot produce three
           simultaneous touches. */
        .gesture(ThreeFingerHoldGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            state.labOpen = true
        })
        #if DEBUG
        .gesture(TripleTapHoldGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            state.labOpen = true
        })
        // sim ergonomics: Option+click-hold makes a real two-touch pair —
        // the ONLY multi-touch a Mac trackpad can hand the Simulator
        .gesture(TwoFingerHoldGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            state.labOpen = true
        })
        #endif
        .sheet(isPresented: $state.labOpen) { labSheet.presentationDetents([.medium]) }
        /* web flows summoned over the native screen, transparent — they run
           their own sheet choreography and post ds-close when done */
        /* NOTE: no .ignoresSafeArea() on the cover content — FlowOverlay's
           webview/glass layers ignore it internally, but its DS bar must get
           safe-area placement (bottom = inset + 12, the Rashid-endorsed rule
           every DS bar shares; a whole-cover ignore pushed the bar to the
           raw screen edge). */
        .fullScreenCover(isPresented: $state.couponsOpen) {
            // fully native per Rashid — real lensing everywhere, no web glass
            RewardsScreenNative { instant { state.couponsOpen = false } }
                .presentationBackground(Color.black.opacity(0.42))
        }
        .fullScreenCover(isPresented: $state.calendarOpen) {
            FlowOverlay(path: "meal-select") {
                instant { state.calendarOpen = false }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { tabSel = .home }
            }
            .presentationBackground(Color.black.opacity(0.42))
        }
        .animation(.spring(duration: 0.45), value: state.showPromo)
        .animation(.spring(duration: 0.45), value: state.showDiscounts)
        .animation(.spring(duration: 0.45), value: state.showConsult)
        .animation(.spring(duration: 0.4), value: state.plan)
        .animation(.spring(duration: 0.35), value: state.consultBooked)
        .animation(.spring(duration: 0.35), value: state.daysShapeChoice)
        .animation(.spring(duration: 0.45), value: state.daysLeft == 3)
        .animation(.spring(duration: 0.35), value: state.discountsEmpty)
        .sensoryFeedback(.impact(weight: .medium), trigger: state.stripDay)
        .sensoryFeedback(.impact(weight: .light), trigger: state.macrosOpen)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.4), trigger: dialNumber)
        .task {
            _ = DSFontLoader.registerCached
            if await DSFontLoader.downloadMissing() { fontTick += 1 }
            #if DEBUG
            NSLog("DSFONTS world: %@", UIFont.fontNames(forFamilyName: "Avenir Next World"))
            #endif
        }
        .task { await runIntro() }
        #if DEBUG
        // Headless QA: SIMCTL_CHILD_DSLAB_OVERLAY=meal-select|rewards summons
        // the flow overlay without a tap (overlay paths are untappable in
        // scripted sim runs)
        .task {
            if let p = ProcessInfo.processInfo.environment["DSLAB_OVERLAY"] {
                try? await Task.sleep(for: .seconds(2))
                instant {
                    if p == "meal-select" { state.calendarOpen = true }
                    if p == "rewards" { state.couponsOpen = true }
                }
            }
            #if DEBUG
            NSLog("DSFONTS families: %@",
                  UIFont.familyNames.filter { $0.localizedCaseInsensitiveContains("avenir") })
            for fam in UIFont.familyNames where fam.localizedCaseInsensitiveContains("avenir") {
                NSLog("DSFONTS %@ -> %@", fam, UIFont.fontNames(forFamilyName: fam))
            }
            #endif
            // SIMCTL_CHILD_DSLAB_LABMENU=1 opens the lab controls on launch —
            // scripted sim taps can't hit the triple-tap-hold's 550ms window
            if ProcessInfo.processInfo.environment["DSLAB_LABMENU"] != nil {
                try? await Task.sleep(for: .seconds(1.5))
                state.labOpen = true
            }
        }
        #endif
        .onChange(of: state.daysLeft) {   /* lab changes bypass the intro */
            dialNumber = state.daysLeft
            withAnimation(.spring(duration: 0.35)) {
                dialFrac = Double(state.daysLeft) / 30
            }
        }
    }

    private func arrival<V: View>(_ v: V, _ index: Double) -> some View {
        v.opacity(arrived ? 1 : 0)
            .scaleEffect(arrived ? 1 : 0.94, anchor: .center)
            .animation(.spring(duration: 0.55).delay(0.07 * index), value: arrived)
    }

    private func runIntro() async {
        try? await Task.sleep(for: .milliseconds(60))
        arrived = true
        /* warm the summonable flows while the intro plays — a Discounts or
           calendar tap then presents an already-loaded page instantly */
        FlowPreloader.shared.warm(["rewards", "meal-select"])
        try? await Task.sleep(for: .milliseconds(500))
        withAnimation(.easeOut(duration: 0.9)) { dialFrac = Double(state.daysLeft) / 30 }
        while dialNumber > state.daysLeft {
            try? await Task.sleep(for: .milliseconds(75))
            withAnimation(.linear(duration: 0.07)) { dialNumber -= 1 }
        }
    }

    // MARK: top row — stories strip + glass docks

    private var topRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                AsyncImage(url: URL(string: DS.assets + "avatar.png")) { $0.resizable() }
                    placeholder: { Circle().fill(.white.opacity(0.2)) }
                    .frame(width: 48, height: 48).clipShape(Circle())
                VStack(alignment: .leading, spacing: 1) {
                    (Text("☀️ ").font(.system(size: 11))
                     + Text("صبحك الله بالخير").font(DS.avenirWorld(12)))
                        .foregroundStyle(DS.onColor)
                        .id("greeting-\(fontTick)")
                    Text("Abdulrahman").font(DS.urbane(14)).foregroundStyle(.white)
                }
            }
            Spacer()
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    dock { DSStarIcon().fill(.white.opacity(0.7)).frame(width: 32, height: 32) }
                    dock {
                        DSBellIcon().fill(.white.opacity(0.7)).frame(width: 32, height: 32)
                            .overlay(alignment: .topTrailing) {
                                Circle().fill(.yellow).frame(width: 6, height: 6).offset(x: -2, y: 2)
                            }
                    }
                }
            }
        }
        .frame(height: 68)
    }

    // MARK: DS tab bar — Figma structure on Apple's real Liquid Glass capsule
    // (home selected / calendar / account; regular glass, NOT .interactive —
    // the interactive layer eats tab taps, per the shell's build-7 lesson)

    /// State change with the fullScreenCover's own slide suppressed — the web
    /// flow plays its own sheet choreography; the cover must not double it.
    private func instant(_ change: () -> Void) {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t, change)
    }

    @State private var tabSel: DSTabId = .home

    private var tabBar: some View {
        DSTabBar(selected: tabSel) { tab in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { tabSel = tab }
            if tab == .calendar {
                // Apple's beat: the pill lands first, then the page presents
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) {
                    instant { state.calendarOpen = true }
                }
            }
        }
    }

    private func dock<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .foregroundStyle(.white)
            .frame(width: 69, height: 68)
            .glassEffect(.clear.tint(DS.red.opacity(0.15)).interactive(), in: .rect(cornerRadius: DS.tile(68)))
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
        .glassEffect(.clear.tint(DS.red.opacity(0.15)), in: .rect(cornerRadius: DS.cradle(pill: 18, inset: 16)))   // Renew pill r18 + its 16 inset
        .glassEffectID("promo", in: glassNS)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    // near-transparent glass capsule (Rashid: stock .glass was too bright —
    // ~20% white tint reads right over the red); prominent white when urgent
    private func pill(_ label: String, urgent: Bool = false) -> some View {
        Group {
            if urgent {
                Button(label) { }
                    .buttonStyle(.glassProminent)
                    .tint(DS.onColor)
                    .foregroundStyle(DS.ink)
                    .font(DS.urbane(12))
            } else {
                Button { } label: {
                    Text(label).font(DS.urbane(12)).foregroundStyle(DS.onColor)
                        .padding(.horizontal, 17).frame(height: 36)
                }
                .glassEffect(.clear.tint(.white.opacity(0.2)).interactive(), in: .capsule)
            }
        }
    }

    // MARK: urgent renewal banner (Figma 16828:83478) — the days widget
    // relocated to the top with the offer; countdown chip ticks live

    @State private var urgentT0 = Date()
    @State private var fontTick = 0   // bumps when remote fonts land (cold launch)

    private var urgentBanner: some View {
        let expired = state.daysLeft == 0
        return HStack(spacing: 14) {
            ZStack {
                Circle().stroke(.white.opacity(0.25), lineWidth: 3.5)
                Circle().trim(from: 0, to: expired ? 0 : 0.12)
                    .stroke(.white, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .scaleEffect(x: -1)
                VStack(spacing: 0) {
                    Text(verbatim: "\(state.daysLeft)")
                        .font(DS.urbane(22, .semibold)).foregroundStyle(.white)
                    Text(expired ? "Expired" : "Days left")
                        .font(DS.proxima(9)).foregroundStyle(DS.onColor)
                }
            }
            .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 2) {
                Text(expired ? "Expired! Last chance to Save 🚨"
                             : "Renew early & Save 😱")
                    .font(DS.urbane(15, .semibold)).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.85)
                Group {
                    if expired {
                        (Text("your ").font(DS.proxima(10))
                         + Text("KD").font(DS.proxima(7)) + Text("99").font(DS.proxima(10))
                         + Text(" offer ends with the timer").font(DS.proxima(10)))
                    } else {
                        (Text("starting price will change to ").font(DS.proxima(10))
                         + Text("KD").font(DS.proxima(7)) + Text("109").font(DS.proxima(10)))
                    }
                }
                .foregroundStyle(DS.onColor.opacity(0.85))
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Before").font(DS.proxima(8)).foregroundStyle(DS.onColor.opacity(0.7))
                        Text("KD139").font(DS.urbane(11)).strikethrough()
                            .foregroundStyle(DS.onColor.opacity(0.7))
                    }
                    (Text("KD").font(DS.urbane(10, .semibold))
                     + Text("99").font(DS.urbane(18, .semibold)))
                        .foregroundStyle(.white)
                    Spacer(minLength: 8)
                    // expired = the prominent white pill, same treatment as
                    // the days widget's expired Renew
                    pill("Renew", urgent: expired)
                }
                .padding(.top, 3)
            }
        }
        // breathing room, top and trailing especially (Rashid) — the grid
        // below gives back a little height to keep the page rhythm
        .padding(EdgeInsets(top: 20, leading: 16, bottom: 16, trailing: 22))
        .glassEffect(.clear.tint(DS.red.opacity(0.15)), in: .rect(cornerRadius: DS.cradle(pill: 18, inset: 16)))
        .glassEffectID("days", in: glassNS)
        .overlay(alignment: .topLeading) {
            // yellow countdown chip riding the banner's top edge, ticking live
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let left = max(0, 1211 - Int(ctx.date.timeIntervalSince(urgentT0)))
                Text(verbatim: String(format: "Expires in %02d:%02d:%02d",
                                      left / 3600, (left / 60) % 60, left % 60))
                    .font(DS.urbane(10, .semibold)).foregroundStyle(DS.ink)
                    .padding(.horizontal, 10).frame(height: 20)
                    .background(Color(red: 1, green: 197/255, blue: 46/255), in: Capsule())
            }
            .offset(x: 16, y: -10)
        }
        .padding(.top, 10)   // room for the chip overhang in the stack rhythm
        .transition(.scale(scale: 0.94).combined(with: .opacity))
    }

    /// Coupons grown into the days widget's vacated space: big bag on top,
    /// voucher copy at the bottom (Figma 16828:83478)
    /// grown coupons sits BETWEEN classes: tile read sharp, full platter too
    /// round — it carries the banner-family 34, with its inset following the
    /// curvature rule
    private static let expandedCouponsRadius: CGFloat = 34

    private var expandedCouponsWidget: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Spacer(); DSBagIcon().frame(width: 46, height: 43) }
            Spacer(minLength: 8)
            (Text("KD 32 ").font(DS.urbane(17, .semibold)).foregroundStyle(DS.onColor)
             + Text("OFF").font(DS.urbane(10, .semibold)).foregroundStyle(DS.onColor.opacity(0.8)))
            Text("5 Vouchers available").font(DS.proxima(11))
                .foregroundStyle(DS.onColor.opacity(0.8))
        }
        .padding(DS.inset(for: Self.expandedCouponsRadius))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .glassEffect(.clear.tint(DS.red.opacity(0.15)).interactive(),
                     in: .rect(cornerRadius: Self.expandedCouponsRadius))
        .glassEffectID("disc", in: glassNS)
        .contentShape(RoundedRectangle(cornerRadius: Self.expandedCouponsRadius))
        .onTapGesture { instant { state.couponsOpen = true } }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: widget grid — the modular system

    private var widgetGrid: some View {
        GlassEffectContainer(spacing: DS.gap) {
            // 362pt content width = 193 + DS.gap + 153 — columns absorb the
            // gutter change so every gap in the zone is the same 16
            HStack(alignment: .top, spacing: DS.gap) {
                planWidget.frame(width: 193)
                VStack(spacing: DS.gap) {
                    if urgent {
                        // days lives in the top banner now; coupons expands
                        // into the vacated space (Figma 16828:83478)
                        if state.showDiscounts { expandedCouponsWidget }
                        if state.showConsult { consultWidget }
                    } else {
                        daysWidget
                        if state.showDiscounts { discountsWidget }
                        if state.showConsult { consultWidget }
                    }
                }
                .frame(width: 153)
            }
            /* fixed height: removing the promo banner shifts everything UP —
               it must never elongate the widgets (Rashid); the urgent banner's
               extra padding is paid for here */
            .frame(height: urgent ? 274 : 288)
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
                }
                .glassEffect(.clear.tint(.white.opacity(0.2)).interactive(), in: .capsule)
                .padding(.top, 4)   // title sits close to Change (Rashid)
            }
            .padding(EdgeInsets(top: 28, leading: 20, bottom: 22, trailing: 20))
        }
        .frame(maxHeight: .infinity)
        // clip the CONTENT (gradient) before the glass so it can never bleed
        // past the rounded bottom edges; both shapes are the same fixed 26
        .clipShape(RoundedRectangle(cornerRadius: DS.platter, style: .continuous))
        .glassEffect(.clear.tint(DS.red.opacity(0.15)), in: .rect(cornerRadius: DS.platter))
        .glassEffectID("plan", in: glassNS)
    }

    /// the height the column composition hands the days widget — drives
    /// its shape, its radius, and its responsive insets
    private var daysHeight: CGFloat {
        var h: CGFloat = 288
        if state.showDiscounts { h -= 60 + DS.gap }
        if state.showConsult { h -= (state.showDiscounts ? 60 : 110) + DS.gap }
        return h
    }

    // days-left: re-shapes with the height it is given (tall / wide / slim),
    // or renders the lab-forced shape (Figma 4798:19569 has four)
    private var daysWidget: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let auto: DaysShape = h >= 168 ? .tall : (h < 82 ? .slim : .wide)
            let shape: DaysShape = switch state.daysShapeChoice {
            case .auto: auto
            case .tall: .tall
            case .wide: .wide
            case .compact: .compact
            case .slim: .slim
            }
            DaysContent(state: state, shape: shape, number: dialNumber, frac: dialFrac,
                        height: h)
        }
        .frame(maxHeight: .infinity)
        .glassEffect(.clear.tint(DS.red.opacity(0.15)),
                     in: .rect(cornerRadius: DS.cradle(pill: 18,
                                    inset: min(20, max(12, daysHeight * 0.11)))))
        .glassEffectID("days", in: glassNS)
        .layoutPriority(1.6)
    }

    private var discountsWidget: some View {
        HStack(spacing: 12) {
            if state.discountsEmpty {
                // no coupons: keep the bag, drop the currency — slightly
                // smaller type so the whole title shows (Rashid)
                // fixedSize: the row's stacked gaps were scale-shrinking it
                // to ~10pt (Rashid: match the Booked title size)
                Text("Coupons").font(DS.urbane(13, .semibold)).foregroundStyle(DS.onColor)
                    .fixedSize()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("KD 32").font(DS.urbane(14, .semibold)).foregroundStyle(DS.onColor)
                    Text("Discounts").font(DS.proxima(12)).foregroundStyle(DS.onColor.opacity(0.8))
                }
                // scale, never wrap — the bag glyph leaves ~67pt for the text column
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            DSBagIcon().frame(width: 34, height: 31.8)
        }
        .padding(.horizontal, 19)
        .frame(maxWidth: .infinity)
        .frame(height: 60)   // twin of consult — slimmer so days-left breathes
        .glassEffect(.clear.tint(DS.red.opacity(0.15)).interactive(),
                     in: .rect(cornerRadius: DS.tile(60)))
        .glassEffectID("disc", in: glassNS)
        .contentShape(RoundedRectangle(cornerRadius: DS.tile(60)))
        .onTapGesture { instant { state.couponsOpen = true } }   // summon the coupons flow
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    private var consultWidget: some View {
        HStack(spacing: 12) {
            consultIcon
            if state.consultBooked {
                // Figma 16367:78807: "Booked ✓" + the slot, on one tile
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Booked").font(DS.urbane(13, .semibold)).foregroundStyle(.white)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.red, .white)
                    }
                    Text("12th Nov 8 AM").font(DS.proxima(11))
                        .foregroundStyle(DS.onColor.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Book Consultation").font(DS.urbane(12)).foregroundStyle(DS.onColor)
                    .lineLimit(2).minimumScaleFactor(0.9)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)   // fill the 151pt column exactly — no bleed
        // when Discounts is away, Consultation grows +50 so the sparse column
        // doesn't gape between it and the days widget (Rashid)
        .frame(height: state.showDiscounts ? 60 : 110)
        .glassEffect(.clear.tint(DS.red.opacity(0.15)).interactive(),
                     in: .rect(cornerRadius: DS.tile(state.showDiscounts ? 60 : 110)))
        .glassEffectID("consult", in: glassNS)
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    /// The Figma consultation calendar is MULTILAYERED (mirrors the web
    /// `.calico` composite): translucent plate, traced subtract body, and
    /// two binding posts poking above the plate.
    /// Rashid's SVG verbatim (Figma Frame 1321315918, 28-grid): translucent
    /// plate, calendar body with six window cells punched out, two binding
    /// posts poking above the plate.
    private var consultIcon: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4.685)
                .fill(.white.opacity(0.25))
                .shadow(color: .black.opacity(0.07), radius: 2, y: 1.9)
                .frame(width: 23.425, height: 22.488)
                .offset(x: 2.333, y: 2.404)
            DSConsultCalShape()
                .fill(.white.opacity(0.6), style: FillStyle(eoFill: true))
                .frame(width: 28, height: 28)
            Capsule().fill(.white.opacity(0.4)).frame(width: 1.874, height: 4.685)
                .offset(x: 8.892, y: 0)
            Capsule().fill(.white.opacity(0.4)).frame(width: 1.874, height: 4.685)
                .offset(x: 17.325, y: 0)
        }
        .frame(width: 28, height: 28)
    }

    // MARK: meal sheet

    private var mealSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            sheetHeader.padding(.top, 30).padding(.horizontal, 24)
            ScrollViewReader { stripProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 29) {
                        ForEach(0..<state.days.count, id: \.self) { i in
                            if i > 0 {
                                Rectangle().fill(Color(white: 0.925)).frame(width: 1, height: 135)
                            }
                            dayGroup(i)
                        }
                    }
                    .padding(.bottom, 8)
                }
                // margins (not HStack padding) so scrollTo(.leading) lands
                // day groups exactly at the standard 24pt inset
                .contentMargins(.horizontal, 24, for: .scrollContent)
                .coordinateSpace(name: "strip")
                .onAppear {
                    stripProxy.scrollTo("day1", anchor: .leading)
                    // seen once in the sim: the first scrollTo can race layout
                    // and strand the strip on a far day — re-fire next runloop
                    DispatchQueue.main.async {
                        stripProxy.scrollTo("day1", anchor: .leading)
                    }
                }
            }
            Spacer(minLength: 140)
        }
        .frame(maxWidth: .infinity, minHeight: 520, alignment: .top)
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38))
        // bottom-overscroll rubber band must show white, never the red page
        .background(alignment: .bottom) {
            Color.white.frame(height: 600).offset(y: 600)
        }
    }

    private let stripMeals = [("meal1.jpg", "Chicken Machbous", 245),
                              ("meal2.jpg", "Egg Sandwich", 343),
                              ("meal3.jpg", "Biryani with tomato sauce and Veggies", 554)]

    private func dayGroup(_ i: Int) -> some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { k in
                // rotate per day; Today (i=1) keeps the original order
                let m = stripMeals[(k + i + 2) % 3]
                mealCard(m.0, m.1, m.2)
            }
        }
        .id("day\(i)")
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named("strip"))
        } action: { r in
            /* the group under the 45% anchor is the active day; ±15pt bands
               leave a dead zone across each divider gap = hysteresis */
            let ax = UIScreen.main.bounds.width * 0.45
            if r.minX - 15 <= ax, ax < r.maxX + 15, state.stripDay != i {
                withAnimation(.spring(duration: 0.35)) { state.stripDay = i }
            }
        }
    }

    private var sheetHeader: some View {
        let info = state.days[state.stripDay]
        /* the whole strip is sized so the macro expansion has real room:
           smaller tile + fonts, the pill keeps its intrinsic width and the
           day/date column scales down before anything collides */
        return HStack(spacing: 12) {
            Image(systemName: "fork.knife").font(.system(size: 18)).foregroundStyle(DS.red)
                .frame(width: 44, height: 44)
                .background(.white, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.08), radius: 6.65)
            VStack(alignment: .leading, spacing: 1) {
                Text(state.dayWord(state.stripDay)).font(DS.urbane(15, .semibold)).foregroundStyle(DS.ink)
                    .contentTransition(.numericText())
                Text(state.dateString(state.days[state.stripDay].off)).font(DS.proxima(11)).foregroundStyle(DS.caption)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            Spacer(minLength: 8)
            Button { withAnimation(.spring(duration: 0.4, bounce: 0.12)) { state.macrosOpen.toggle() } } label: {
                HStack(spacing: 3) {
                    // verbatim: interpolated Ints localize ("1,200") — web shows "1200"
                    Text(verbatim: "\(info.kcal)").font(DS.urbane(15, .semibold)).foregroundStyle(DS.ink)
                        .contentTransition(.numericText())
                    Text("Kcal").font(DS.urbane(9, .light)).foregroundStyle(Color(white: 0.6))
                    if state.macrosOpen {
                        HStack(spacing: 6) {
                            macro(info.c, "C"); macro(info.p, "P"); macro(info.f, "F")
                        }
                        .padding(.leading, 6)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 12).frame(height: 44)
                .clipped()   // clips the macro slide only — BEFORE the background,
                             // so the shadow is never cropped (same finish as the tile)
                // the macros calculator is REAL Liquid Glass (Rashid 2026-09-09)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.08), radius: 6.65)
            }
            .fixedSize()
        }
        .frame(height: 48)
    }

    private func macro(_ v: Int, _ u: String) -> some View {
        HStack(spacing: 2) {
            Text(verbatim: "\(v)").font(DS.urbane(12)).foregroundStyle(DS.ink)
                .contentTransition(.numericText())
            Text(u).font(DS.proxima(8)).foregroundStyle(DS.ink)
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
                        Text("19").tag(19); Text("5").tag(5)
                        Text("3 (urgent)").tag(3); Text("Expired").tag(0)
                    }
                    .pickerStyle(.segmented)
                    Picker("Shape", selection: $state.daysShapeChoice) {
                        ForEach(HomeState.DaysShapeChoice.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Widgets on screen") {
                    Toggle("Promo banner", isOn: $state.showPromo)
                    Toggle("Discounts", isOn: $state.showDiscounts)
                    Toggle("Consultation", isOn: $state.showConsult)
                }
                if state.showDiscounts {
                    Section("Discounts state") {
                        Picker("Coupons", selection: $state.discountsEmpty) {
                            Text("KD 32").tag(false); Text("No coupons").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                if state.showConsult {
                    Section("Consultation state") {
                        Picker("Consultation", selection: $state.consultBooked) {
                            Text("Book").tag(false); Text("Booked").tag(true)
                        }
                        .pickerStyle(.segmented)
                    }
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

/// Calendar body from Rashid's SVG (Frame 1321315918): outer rounded rect
/// with a 2x3 grid of rounded window cells punched out (even-odd fill).
@available(iOS 26.0, *)
private struct DSConsultCalShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 28
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 2.333 * s, y: 6.449 * s,
                                    width: 23.425 * s, height: 21.551 * s),
                         cornerSize: CGSize(width: 4.685 * s, height: 4.685 * s))
        for x: CGFloat in [7.018, 12.640, 18.262] {
            for y: CGFloat in [12.711, 18.333] {
                p.addRoundedRect(in: CGRect(x: x * s, y: y * s,
                                            width: 2.812 * s, height: 2.812 * s),
                                 cornerSize: CGSize(width: 0.937 * s, height: 0.937 * s))
            }
        }
        return p
    }
}

// MARK: - Days-left widget content (the documented shapes)

@available(iOS 26.0, *)
private enum DaysShape { case slim, wide, tall, compact }

@available(iOS 26.0, *)
private struct DaysContent: View {
    let state: HomeState
    let shape: DaysShape
    var number: Int          /* display value — the intro counts 30 down to daysLeft */
    var frac: Double
    var height: CGFloat = 136

    var expired: Bool { state.daysLeft == 0 }

    private var ringSize: CGFloat { shape == .slim ? 40 : (shape == .tall ? 60 : 50) }   // wide & compact share 50

    var ring: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.25), lineWidth: 3)
            Circle().trim(from: 0, to: min(1, frac))
                .stroke(.white, style: .init(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: -1)   // mirrored: the intro depletes CLOCKWISE,
                                      // eating down the right side (Rashid)
            Text(verbatim: "\(number)")
                .font(DS.urbane(shape == .slim ? 16 : (shape == .tall ? 24 : 20), .semibold))
                .foregroundStyle(.white)
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(width: ringSize, height: ringSize)   // tall: +20% dial (Rashid)
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

    // near-transparent glass capsule (~20% tint); prominent white when expired
    var renew: some View {
        Group {
            if expired {
                Button { } label: {
                    Text("Renew").frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(DS.onColor)
                .foregroundStyle(DS.ink)
            } else {
                Button { } label: {
                    Text("Renew").foregroundStyle(DS.onColor)
                        .frame(maxWidth: .infinity).frame(height: 36)
                }
                .glassEffect(.clear.tint(.white.opacity(0.2)).interactive(), in: .capsule)
            }
        }
        .font(DS.urbane(12, expired ? .semibold : .medium))
    }

    /// responsive inset: scales with the widget's given height, identical on
    /// every side (Rashid: Renew was drifting off the bottom — the old
    /// insets were 18/16 top vs 14 bottom AND unfilled height pooled there)
    private var pad: CGFloat { min(20, max(12, height * 0.11)) }

    var body: some View {
        Group {
            switch shape {
            case .slim:
                HStack(spacing: 8) { ring; texts; Spacer(minLength: 0) }
            case .wide:
                VStack(spacing: 8) {
                    HStack(spacing: 8) { ring; texts; Spacer(minLength: 0) }
                    Spacer(minLength: 6)
                    renew
                }
            case .compact:
                // Figma: ring left, Renew pill hugging right, texts below
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ring
                        // flexible: a fixed pill overflowed the 153pt column
                        renew
                    }
                    Spacer(minLength: 4)
                    texts
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(EdgeInsets(top: pad, leading: pad, bottom: pad, trailing: pad))
        .animation(.spring(duration: 0.35), value: state.daysLeft)
    }
}

// MARK: - Rewards, fully native (Rashid 2026-09-09: the web overlay's glass
// button can't do real lensing — the whole flow becomes a SwiftUI screen).
// v1 scaffold: red sheet, glass close, three vouchers with the perforated
// pull-stub and a working rip drag; levels/sounds/confetti follow.

@available(iOS 26.0, *)
struct RewardsScreenNative: View {
    var onClose: () -> Void
    @State private var arrived = false

    fileprivate struct Voucher: Identifiable {
        let id: Int
        let big: String
        let mid: String
        let tail: String
        let sub: String
        let code: String
    }
    private let vouchers: [Voucher] = [
        .init(id: 0, big: "25", mid: "%", tail: " OFF",
              sub: "Upto KD 80 OFF on any of our subscriptions", code: "DS-GOLD25"),
        .init(id: 1, big: "GYM", mid: "", tail: " Subscription",
              sub: "Upto KD 80 OFF on any of our subscriptions", code: "GYM-GOLD"),
        .init(id: 2, big: "KIDS ", mid: "subscription", tail: "",
              sub: "Upto KD 80 OFF on any of our subscriptions", code: "KIDS-GOLD"),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            DS.red.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                Text("Renew and Save on your subscriptions")
                    .font(DS.urbane(28, .semibold)).foregroundStyle(.white)
                    .padding(.top, 74).padding(.horizontal, 24)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        ForEach(vouchers) { v in
                            VoucherCard(voucher: v)
                                .opacity(arrived ? 1 : 0)
                                .offset(y: arrived ? 0 : 26)
                                .animation(.spring(duration: 0.5)
                                    .delay(Double(v.id) * 0.07), value: arrived)
                        }
                    }
                    .padding(.top, 26)
                    .padding(.bottom, 60)
                }
            }
            // real glass close — the reason this screen went native
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DS.ink)
                    .frame(width: 44, height: 44)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .padding(.leading, 24)
            .padding(.top, 18)
        }
        .onAppear { arrived = true }
    }
}

/// One voucher: white card, perforated pull-stub at x=243 (368-grid), rip
/// drag v1 — the stub follows the finger, tears past the threshold.
@available(iOS 26.0, *)
private struct VoucherCard: View {
    fileprivate let voucher: RewardsScreenNative.Voucher

    @State private var drag: CGFloat = 0
    @State private var ripped = false

    private let W: CGFloat = 368
    private let H: CGFloat = 125
    private let stubX: CGFloat = 243

    var body: some View {
        ZStack(alignment: .topLeading) {
            // body piece (left of the perforation)
            VoucherBodyShape(stubX: stubX)
                .fill(.white)
                .shadow(color: Color(red: 56/255, green: 64/255, blue: 74/255).opacity(0.12),
                        radius: 12)
            VStack(alignment: .leading, spacing: 3) {
                Text("Expires in 1 Day").font(DS.proxima(12))
                    .foregroundStyle(Color(white: 0.45))
                (Text(voucher.big).font(DS.urbane(26, .semibold))
                 + Text(voucher.mid).font(DS.urbane(17, .semibold))
                 + Text(voucher.tail).font(DS.urbane(16, .semibold)).foregroundStyle(DS.red))
                    .foregroundStyle(DS.ink)
                Text(voucher.sub).font(DS.proxima(11))
                    .foregroundStyle(Color(white: 0.5))
                    .frame(width: 200, alignment: .leading)
            }
            .padding(.leading, 25).padding(.top, 26)

            // the rippable stub
            stub
                .offset(x: stubX + drag * 0.92, y: 0)
                .rotationEffect(.degrees(Double(min(14, drag * 0.09))),
                                anchor: .bottomTrailing)
                .opacity(ripped ? 0 : 1)
            if ripped {
                VStack(spacing: 2) {
                    Text("CODE").font(DS.proxima(9)).foregroundStyle(Color(white: 0.55))
                    Text(voucher.code).font(DS.urbane(13, .semibold)).foregroundStyle(DS.ink)
                }
                .frame(width: W - stubX, height: H)
                .offset(x: stubX)
                .transition(.opacity)
            }
        }
        .frame(width: W, height: H)
    }

    private var stub: some View {
        VoucherStubShape(stubX: stubX)
            .fill(.white)
            .shadow(color: .black.opacity(drag > 4 ? 0.16 : 0.06),
                    radius: drag > 4 ? 10 : 4, y: 2)
            .overlay {
                VStack(spacing: 0) {
                    Text("Pull").font(DS.urbane(14, .semibold)).foregroundStyle(DS.ink)
                    Text("to Redeem").font(DS.urbane(12)).foregroundStyle(DS.red)
                }
                .offset(x: (stubX + (W - stubX) / 2) - W / 2)   // stub center
            }
            .frame(width: W, height: H, alignment: .leading)
            .offset(x: -stubX)
        .contentShape(Rectangle().path(in: CGRect(x: stubX, y: 0, width: W - stubX, height: H)))
        .gesture(
            DragGesture()
                .onChanged { g in
                    drag = max(0, g.translation.width)
                    if drag > 2, Int(drag) % 14 == 0 {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
                    }
                }
                .onEnded { g in
                    if g.translation.width > 70 {
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        withAnimation(.easeIn(duration: 0.32)) { drag = 420 }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                            withAnimation(.spring(duration: 0.35)) { ripped = true }
                        }
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { drag = 0 }
                    }
                }
        )
    }
}

/// left piece: rounded card ending at the perforation with two bite notches
@available(iOS 26.0, *)
private struct VoucherBodyShape: Shape {
    var stubX: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: 0, y: 0, width: stubX, height: rect.height),
                         cornerSize: CGSize(width: 14, height: 14))
        var holes = Path()
        holes.addEllipse(in: CGRect(x: stubX - 7, y: -7, width: 14, height: 14))
        holes.addEllipse(in: CGRect(x: stubX - 7, y: rect.height - 7, width: 14, height: 14))
        return p.subtracting(holes)
    }
}

/// right piece: the pull-stub with matching notches on its left edge
@available(iOS 26.0, *)
private struct VoucherStubShape: Shape {
    var stubX: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: stubX, y: 0, width: rect.width - stubX, height: rect.height),
                         cornerSize: CGSize(width: 14, height: 14))
        var holes = Path()
        holes.addEllipse(in: CGRect(x: stubX - 7, y: -7, width: 14, height: 14))
        holes.addEllipse(in: CGRect(x: stubX - 7, y: rect.height - 7, width: 14, height: 14))
        return p.subtracting(holes)
    }
}

// MARK: - THE DS tab bar — one component for every prototype surface
// (Rashid: unified placement, interaction, motion). Apple-style: the white
// pill slides on a spring between tabs, the ACTIVE icon is brand red,
// resting icons neutral ink; hosts place it at bottom = safeArea + 12.

enum DSTabId { case home, calendar, person }

@available(iOS 26.0, *)
struct DSTabBar: View {
    var selected: DSTabId
    var onSelect: (DSTabId) -> Void
    /// optional: a held tab (0.5s) fires this instead of a select — the
    /// wordmark long-press pilot entry rides here
    var onLongPress: ((DSTabId) -> Void)? = nil
    @Namespace private var pillNS

    var body: some View {
        HStack(spacing: 0) {
            item(.home) { sel in
                DSLogoMark()
                    .fill(sel ? DS.red : Color(white: 0.12).opacity(0.85))
                    .frame(width: 26, height: 20)
            }
            item(.calendar) { sel in
                DSTabCalendarIcon()
                    .fill(sel ? DS.red : Color(white: 0.12).opacity(0.85))
                    .frame(width: 24, height: 24)
            }
            item(.person) { sel in
                DSTabPersonIcon()
                    .fill(sel ? DS.red : Color(white: 0.12).opacity(0.85))
                    .frame(width: 24, height: 24)
            }
        }
        .padding(4)
        .frame(width: 314, height: 58)
        .glassEffect(.regular, in: .capsule)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: selected)
    }

    private func item<C: View>(_ tab: DSTabId,
                               @ViewBuilder _ content: @escaping (Bool) -> C) -> some View {
        content(selected == tab)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if selected == tab {
                    Capsule().fill(.white.opacity(0.85))
                        .shadow(color: .black.opacity(0.1), radius: 6, y: 2)
                        .matchedGeometryEffect(id: "pill", in: pillNS)
                }
            }
            .contentShape(Capsule())
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onSelect(tab)
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                if let lp = onLongPress {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    lp(tab)
                }
            }
    }
}

/// Self-stated wrapper for hosts without their own selection state (e.g.
/// the calendar overlay): the pill animates locally, taps bubble out.
@available(iOS 26.0, *)
struct DSTabBarHost: View {
    var initial: DSTabId
    var onSelect: (DSTabId) -> Void
    @State private var sel: DSTabId = .home

    var body: some View {
        DSTabBar(selected: sel) { tab in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { sel = tab }
            onSelect(tab)
        }
        .onAppear { sel = initial }
    }
}

// MARK: - Web flow overlays, preloaded (summoning coupons felt slow — the
// webviews are now built and loaded warm while the intro plays, so a tap
// presents an already-rendered flow instantly)

@available(iOS 26.0, *)
@MainActor
final class FlowPreloader {
    static let shared = FlowPreloader()

    /// One handler for both channels: ds-close relays, the shell's haptics
    /// bridge, and the glasschrome protocol forwarded into a per-overlay
    /// chrome state — flows summoned here get chrome identical to the hub path.
    final class Relay: NSObject, WKScriptMessageHandler {
        var onClose: (() -> Void)?
        let chrome = OverlayChrome()

        private let impact: [String: UIImpactFeedbackGenerator] = [
            "light": UIImpactFeedbackGenerator(style: .light),
            "medium": UIImpactFeedbackGenerator(style: .medium),
            "heavy": UIImpactFeedbackGenerator(style: .heavy),
            "soft": UIImpactFeedbackGenerator(style: .soft),
            "rigid": UIImpactFeedbackGenerator(style: .rigid),
        ]
        private let notify = UINotificationFeedbackGenerator()
        private let select = UISelectionFeedbackGenerator()

        func userContentController(_ c: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            if message.name == "dsflow" {
                onClose?()
                DispatchQueue.main.async { self.chrome.clear() }
                return
            }
            guard message.name == "ds",
                  let body = message.body as? [String: Any],
                  let t = body["t"] as? String else { return }
            if t == "glasschrome" {
                // same parse + reply as the main webview's Coordinator —
                // empty els + no bar means clear everything for this overlay
                var els: [GlassChromeEl] = []
                for e in body["els"] as? [[String: Any]] ?? [] {
                    guard let id = e["id"] as? String else { continue }
                    func n(_ k: String) -> CGFloat {
                        CGFloat((e[k] as? NSNumber)?.doubleValue ?? 0)
                    }
                    els.append(GlassChromeEl(id: id, x: n("x"), y: n("y"),
                                             w: n("w"), h: n("h"), r: n("r"),
                                             on: (e["on"] as? Bool) ?? false))
                }
                let bar = body["bar"] as? String
                let flow = body["flow"] as? String
                let surface = body["surface"] as? String
                let mode = body["mode"] as? String
                let frame = message.frameInfo
                DispatchQueue.main.async {
                    self.chrome.frame = frame
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.chrome.els = els
                        self.chrome.bar = bar
                        self.chrome.flow = flow
                        self.chrome.surface = surface
                        self.chrome.mode = mode
                    }
                    if !els.isEmpty, let wv = self.chrome.webView {
                        let ids = els.map { "'\($0.id)'" }.joined(separator: ",")
                        wv.evaluateJavaScript(
                            "window.DSNativeChrome && DSNativeChrome([\(ids)])",
                            in: frame, in: .page, completionHandler: nil)
                    }
                }
                return
            }
            if t == "macrogauge" {
                // the selector's macros gauge: a persistent Liquid Glass twin
                // (static-state furniture per the motion-state doctrine); the
                // page hides its web bar only after DSNativeGauge confirms
                let frame = message.frameInfo
                if body["clear"] as? Bool == true {
                    DispatchQueue.main.async {
                        withAnimation(.easeOut(duration: 0.2)) { self.chrome.gauge = nil }
                    }
                    return
                }
                func num(_ k: String) -> Double {
                    (body[k] as? NSNumber)?.doubleValue ?? 0
                }
                var rect = CGRect.zero
                if let r = body["rect"] as? [String: Any] {
                    func rn(_ k: String) -> CGFloat {
                        CGFloat((r[k] as? NSNumber)?.doubleValue ?? 0)
                    }
                    rect = CGRect(x: rn("x"), y: rn("y"), width: rn("w"), height: rn("h"))
                }
                let model = DSGaugeModel(rect: rect, fill: num("fill"),
                                         kcal: Int(num("kcal")), goal: Int(num("goal")),
                                         p: Int(num("p")), c: Int(num("c")), f: Int(num("f")),
                                         next: (body["next"] as? Bool) ?? false)
                DispatchQueue.main.async {
                    self.chrome.frame = frame
                    withAnimation(.spring(response: 0.55, dampingFraction: 1)) {
                        self.chrome.gauge = model
                    }
                    if let wv = self.chrome.webView {
                        wv.evaluateJavaScript("window.DSNativeGauge && DSNativeGauge(true)",
                                              in: frame, in: .page, completionHandler: nil)
                    }
                }
                return
            }
            guard t == "haptic" else { return }
            let kind = body["kind"] as? String ?? "impact"
            let style = body["style"] as? String ?? "light"
            DispatchQueue.main.async { [self] in
                switch kind {
                case "notification":
                    let map: [String: UINotificationFeedbackGenerator.FeedbackType] = [
                        "success": .success, "warning": .warning, "error": .error,
                    ]
                    notify.notificationOccurred(map[style] ?? .success)
                case "selection":
                    select.selectionChanged()
                default:
                    (impact[style] ?? impact["light"]!).impactOccurred()
                }
            }
        }
    }

    private var entries: [String: (web: WKWebView, relay: Relay)] = [:]

    func warm(_ paths: [String]) { for p in paths { _ = entry(p) } }

    func entry(_ path: String) -> (web: WKWebView, relay: Relay) {
        if let e = entries[path] { return e }
        let relay = Relay()
        let cfg = WKWebViewConfiguration()
        let closeRelay = """
        window.addEventListener('message', function (e) {
          /* only SELF-posted ds-close closes the overlay (top-level flows
             like rewards post to themselves). A child frame's ds-close is
             addressed to its parent page — e.g. the selector's, which the
             calendar's closeOverlay handles — never to the shell. */
          if (e.data && e.data.t === 'ds-close' && e.source === window) {
            try { webkit.messageHandlers.dsflow.postMessage('close'); } catch (_) {}
          }
        });
        """
        cfg.userContentController.addUserScript(
            WKUserScript(source: closeRelay, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        cfg.userContentController.add(relay, name: "dsflow")
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []   // flow sound autoplay
        // Same haptics bridge as the main shell webview — the rewards rip's
        // navigator.vibrate must feel identical here
        cfg.userContentController.addUserScript(
            WKUserScript(source: LabWebView.Coordinator.bridgeJS,
                         injectionTime: .atDocumentStart, forMainFrameOnly: false))
        cfg.userContentController.add(relay, name: "ds")
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        // Flow pages detect the shell by the UA token (embed styling, haptics)
        wv.customUserAgent = (WKWebView().value(forKey: "userAgent") as? String ?? "Mozilla/5.0")
            + " DietStationLab/2"
        relay.chrome.webView = wv
        entries[path] = (wv, relay)
        reload(path)
        return entries[path]!
    }

    /// Fresh load — used to warm initially and to re-arm after a visit
    /// (the page's sheet has slid away once ds-close fires).
    func reload(_ path: String) {
        guard let e = entries[path] else { return }
        let stamp = Int(Date().timeIntervalSince1970)
        if let url = URL(string: "https://rashidalo.github.io/Diet-station/\(path)/?embed=1&v=\(stamp)") {
            e.web.load(URLRequest(url: url))
        }
    }
}

// MARK: - The lab house gesture (standard scaffold for every native pilot)

/// Triple-tap-and-hold, matching lab-shell's tripleTapHold() state machine:
/// taps counted on touch-DOWN with ≤550ms between downs; the 3rd contact must
/// be HELD ≥380ms (release earlier = no fire); ≤16pt drift allowed during the
/// hold; a second simultaneous finger cancels. Stays in .possible until it
/// fires, so normal taps/scrolls are never delayed.
final class TripleTapHoldRecognizer: UIGestureRecognizer {
    private var tapCount = 0
    private var lastDown: TimeInterval = 0
    private var holdOrigin: CGPoint = .zero
    private var holdTimer: Timer?

    private func cancelSequence() {
        holdTimer?.invalidate()
        holdTimer = nil
        tapCount = 0
    }

    override func reset() {
        super.reset()
        cancelSequence()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if (event.allTouches?.count ?? 1) > 1 {   // second finger cancels
            cancelSequence()
            return
        }
        guard let t = touches.first else { return }
        let now = t.timestamp
        if now - lastDown > 0.55 { tapCount = 0 }
        lastDown = now
        tapCount += 1
        if tapCount >= 3 {
            holdOrigin = t.location(in: view)
            holdTimer = Timer.scheduledTimer(withTimeInterval: 0.38, repeats: false) { [weak self] _ in
                guard let self, self.tapCount >= 3 else { return }
                self.state = .recognized
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard tapCount >= 3, holdTimer != nil, let t = touches.first else { return }
        let p = t.location(in: view)
        if hypot(p.x - holdOrigin.x, p.y - holdOrigin.y) > 16 {
            cancelSequence()   // drifted — this became a scroll/drag
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        if holdTimer != nil { cancelSequence() }   // released before 380ms
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        cancelSequence()
    }
}

#if DEBUG
/// Simulator alias (Debug only): Option+click-hold = the sim's synthetic
/// two-touch pair, held. Mac trackpads cannot produce three touches.
@available(iOS 26.0, *)
struct TwoFingerHoldGesture: UIGestureRecognizerRepresentable {
    let onFire: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let r = UILongPressGestureRecognizer()
        r.numberOfTouchesRequired = 2
        r.minimumPressDuration = 0.4
        r.allowableMovement = 24
        r.cancelsTouchesInView = false
        r.delegate = context.coordinator
        return r
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        if recognizer.state == .began { onFire() }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
#endif

/// THE lab gesture: three fingers, one tap, held ~0.4s. Plain UIKit
/// long-press with numberOfTouchesRequired = 3 — nothing custom needed.
@available(iOS 26.0, *)
struct ThreeFingerHoldGesture: UIGestureRecognizerRepresentable {
    let onFire: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let r = UILongPressGestureRecognizer()
        r.numberOfTouchesRequired = 3
        r.minimumPressDuration = 0.4
        r.allowableMovement = 24
        r.cancelsTouchesInView = false
        r.delegate = context.coordinator
        return r
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        if recognizer.state == .began { onFire() }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

/// SwiftUI bridge — attach with `.gesture(TripleTapHoldGesture { … })`.
@available(iOS 26.0, *)
struct TripleTapHoldGesture: UIGestureRecognizerRepresentable {
    let onFire: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> TripleTapHoldRecognizer {
        let r = TripleTapHoldRecognizer()
        r.delegate = context.coordinator
        return r
    }

    func handleUIGestureRecognizerAction(_ recognizer: TripleTapHoldRecognizer, context: Context) {
        if recognizer.state == .ended { onFire() }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        // never block the pilot's own taps, scrolls, or other gestures
        func gestureRecognizer(_ g: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

// MARK: - Macros gauge: real Liquid Glass twin of the selector's navigator
//
// The web navigator (358x69 capsule, Figma "Meal Selection Navigator 2.0")
// stays the choreographer for warn/celebrate; this twin owns the resting
// selection states — REAL glassEffect base refracting the meal cards, the
// tri-tone fill gliding with each pick, counters ticking natively.

struct DSGaugeModel: Equatable {
    var rect: CGRect
    var fill: Double            // 0..1 of bar width (web's GAUGE_BASE applied)
    var kcal: Int
    var goal: Int
    var p: Int
    var c: Int
    var f: Int
    var next: Bool
}

@available(iOS 26.0, *)
struct DSGaugeGlassView: View {
    let model: DSGaugeModel
    var onNext: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            fillBar
            content
        }
        .overlay(alignment: .trailing) {
            if model.next {
                // web dock parity: 53pt capsule, 8pt off the bar's top/bottom/
                // right (.glass buttonStyle padded past the 53 frame — build
                // the glass capsule explicitly so the margins hold)
                Button(action: onNext) {
                    HStack(spacing: 7) {
                        Text("Next").font(DS.urbane(14, .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 53)
                    // the house glass pill (same recipe as Renew/Change):
                    // visibly liquid over the gold fill (Rashid)
                    .glassEffect(.clear.tint(.white.opacity(0.2)).interactive(), in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .glassEffect(.regular, in: .capsule)
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
    }

    private var fillBar: some View {
        GeometryReader { geo in
            let w = geo.size.width * model.fill
            // the web painter's tri-tone warmth with a feathered leading edge
            LinearGradient(stops: [
                .init(color: Color(red: 238/255, green: 32/255, blue: 35/255).opacity(0.94), location: 0),
                .init(color: Color(red: 245/255, green: 120/255, blue: 19/255).opacity(0.94), location: 0.62),
                .init(color: Color(red: 253/255, green: 215/255, blue: 2/255).opacity(0.94), location: 0.96),
                .init(color: Color(red: 253/255, green: 222/255, blue: 60/255).opacity(0.94), location: 1),
            ], startPoint: .leading, endPoint: .trailing)
            .frame(width: max(8, w))
            .mask(alignment: .leading) {
                // feather compresses toward the cap, matching the web glide
                let soft = max(2, min(48, (1 - model.fill) / 0.12 * 48))
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: max(0, (w - soft) / max(w, 1))),
                    .init(color: .black.opacity(0), location: 1),
                ], startPoint: .leading, endPoint: .trailing)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .clipShape(Capsule())
        .animation(.spring(response: 0.65, dampingFraction: 1), value: model.fill)
    }

    private var content: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Kcal").font(DS.urbane(9, .medium))
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(verbatim: "\(model.kcal)").font(DS.urbane(19, .semibold))
                        .contentTransition(.numericText(value: Double(model.kcal)))
                    Text(verbatim: "/\(model.goal)").font(DS.urbane(10, .medium))
                        .opacity(0.46)
                }
            }
            // min-width fits four digits ("2025/1860") without breaking the row
            .frame(minWidth: 96, alignment: .leading)
            HStack(spacing: 10) {
                pair("Protein", model.p, minW: 38)
                pair("Carbs", model.c, minW: 32)
                pair("Fat", model.f, minW: 28)
            }
            .padding(.bottom, 4)
            Spacer(minLength: 0)
        }
        .padding(.leading, 22)
        .padding(.trailing, 74)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        .animation(.spring(duration: 0.5), value: model.kcal)
    }

    private func pair(_ label: String, _ v: Int, minW: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(DS.urbane(9, .medium))
            HStack(alignment: .lastTextBaseline, spacing: 1) {
                Text(verbatim: "\(v)").font(DS.urbane(14, .semibold))
                    .contentTransition(.numericText(value: Double(v)))
                Text("g").font(DS.proxima(10))
            }
        }
        .frame(minWidth: minW, alignment: .leading)
    }
}

/// Chrome state for one preloaded overlay webview — the glasschrome protocol
/// mirrored, so flows summoned from the native pilot get chrome identical to
/// the hub path (twins, bar, and the calendar's clear/restore dance).
@available(iOS 26.0, *)
final class OverlayChrome: ObservableObject {
    @Published var els: [GlassChromeEl] = []
    @Published var bar: String?
    @Published var flow: String?
    @Published var surface: String?
    @Published var mode: String?
    @Published var gauge: DSGaugeModel?
    weak var webView: WKWebView?
    var frame: WKFrameInfo?

    func chromeTap(_ id: String) {
        webView?.evaluateJavaScript("window.DSChromeTap && DSChromeTap('\(id)')",
                                    in: frame, in: .page, completionHandler: nil)
    }
    func clear() {
        els = []
        bar = nil
        flow = nil
        surface = nil
        mode = nil
        gauge = nil
        frame = nil
    }
}

/// Presents a (preloaded) lab web flow over the native screen with its native
/// glass chrome mounted inside the cover. The page runs its own sheet
/// choreography and posts ds-close when done; after dismissal the webview
/// re-arms in the background for the next summon.
@available(iOS 26.0, *)
struct FlowOverlay: View {
    let path: String
    let onClose: () -> Void
    @ObservedObject private var chrome: OverlayChrome

    @MainActor
    init(path: String, onClose: @escaping () -> Void) {
        self.path = path
        self.onClose = onClose
        _chrome = ObservedObject(wrappedValue: FlowPreloader.shared.entry(path).relay.chrome)
    }

    var body: some View {
        // The ZStack respects safe areas so the DS bar lands on the shared
        // placement rule (bottom = safeArea.bottom + 12, same as home);
        // webview + glass twins individually span the full screen.
        ZStack(alignment: .bottom) {
            FlowWebView(path: path, onClose: onClose)
                .ignoresSafeArea()
            GlassChromeLayer(els: chrome.els, flow: chrome.flow,
                             surface: chrome.surface,
                             mode: chrome.mode) { chrome.chromeTap($0) }
                .ignoresSafeArea()
            if let g = chrome.gauge {
                // its own full-screen space: .position() must resolve in raw
                // screen coords, not this ZStack's safe-area-inset space
                GeometryReader { _ in
                    DSGaugeGlassView(model: g) { chrome.chromeTap("gauge-next") }
                        .frame(width: g.rect.width, height: g.rect.height)
                        .position(x: g.rect.midX, y: g.rect.midY)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
            if chrome.bar == "calendar" {
                // THE unified DS tab bar; home tap animates the pill, then
                // returns to the pilot (Apple's beat)
                DSTabBarHost(initial: .calendar) { tab in
                    if tab == .home {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.26) { onClose() }
                    }
                }
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}

@available(iOS 26.0, *)
private struct FlowWebView: UIViewRepresentable {
    let path: String
    let onClose: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let e = FlowPreloader.shared.entry(path)
        e.relay.onClose = {
            onClose()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                FlowPreloader.shared.reload(path)
            }
        }
        return e.web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Figma icon shapes (traced from the home flow's SVG exports)

/// Figma export: home/cal-tabcal.svg
struct DSTabCalendarIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 19.000, y: 4.000))
        p.addLine(to: CGPoint(x: 18.000, y: 4.000))
        p.addLine(to: CGPoint(x: 18.000, y: 2.000))
        p.addLine(to: CGPoint(x: 16.000, y: 2.000))
        p.addLine(to: CGPoint(x: 16.000, y: 4.000))
        p.addLine(to: CGPoint(x: 8.000, y: 4.000))
        p.addLine(to: CGPoint(x: 8.000, y: 2.000))
        p.addLine(to: CGPoint(x: 6.000, y: 2.000))
        p.addLine(to: CGPoint(x: 6.000, y: 4.000))
        p.addLine(to: CGPoint(x: 5.000, y: 4.000))
        p.addCurve(to: CGPoint(x: 3.010, y: 6.000), control1: CGPoint(x: 3.890, y: 4.000), control2: CGPoint(x: 3.010, y: 4.900))
        p.addLine(to: CGPoint(x: 3.000, y: 20.000))
        p.addCurve(to: CGPoint(x: 5.000, y: 22.000), control1: CGPoint(x: 3.000, y: 21.100), control2: CGPoint(x: 3.890, y: 22.000))
        p.addLine(to: CGPoint(x: 19.000, y: 22.000))
        p.addCurve(to: CGPoint(x: 21.000, y: 20.000), control1: CGPoint(x: 20.100, y: 22.000), control2: CGPoint(x: 21.000, y: 21.100))
        p.addLine(to: CGPoint(x: 21.000, y: 6.000))
        p.addCurve(to: CGPoint(x: 19.000, y: 4.000), control1: CGPoint(x: 21.000, y: 4.900), control2: CGPoint(x: 20.100, y: 4.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 19.000, y: 20.000))
        p.addLine(to: CGPoint(x: 5.000, y: 20.000))
        p.addLine(to: CGPoint(x: 5.000, y: 10.000))
        p.addLine(to: CGPoint(x: 19.000, y: 10.000))
        p.addLine(to: CGPoint(x: 19.000, y: 20.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 19.000, y: 8.000))
        p.addLine(to: CGPoint(x: 5.000, y: 8.000))
        p.addLine(to: CGPoint(x: 5.000, y: 6.000))
        p.addLine(to: CGPoint(x: 19.000, y: 6.000))
        p.addLine(to: CGPoint(x: 19.000, y: 8.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 9.000, y: 14.000))
        p.addLine(to: CGPoint(x: 7.000, y: 14.000))
        p.addLine(to: CGPoint(x: 7.000, y: 12.000))
        p.addLine(to: CGPoint(x: 9.000, y: 12.000))
        p.addLine(to: CGPoint(x: 9.000, y: 14.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 13.000, y: 14.000))
        p.addLine(to: CGPoint(x: 11.000, y: 14.000))
        p.addLine(to: CGPoint(x: 11.000, y: 12.000))
        p.addLine(to: CGPoint(x: 13.000, y: 12.000))
        p.addLine(to: CGPoint(x: 13.000, y: 14.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 17.000, y: 14.000))
        p.addLine(to: CGPoint(x: 15.000, y: 14.000))
        p.addLine(to: CGPoint(x: 15.000, y: 12.000))
        p.addLine(to: CGPoint(x: 17.000, y: 12.000))
        p.addLine(to: CGPoint(x: 17.000, y: 14.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 9.000, y: 18.000))
        p.addLine(to: CGPoint(x: 7.000, y: 18.000))
        p.addLine(to: CGPoint(x: 7.000, y: 16.000))
        p.addLine(to: CGPoint(x: 9.000, y: 16.000))
        p.addLine(to: CGPoint(x: 9.000, y: 18.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 13.000, y: 18.000))
        p.addLine(to: CGPoint(x: 11.000, y: 18.000))
        p.addLine(to: CGPoint(x: 11.000, y: 16.000))
        p.addLine(to: CGPoint(x: 13.000, y: 16.000))
        p.addLine(to: CGPoint(x: 13.000, y: 18.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 17.000, y: 18.000))
        p.addLine(to: CGPoint(x: 15.000, y: 18.000))
        p.addLine(to: CGPoint(x: 15.000, y: 16.000))
        p.addLine(to: CGPoint(x: 17.000, y: 16.000))
        p.addLine(to: CGPoint(x: 17.000, y: 18.000))
        p.closeSubpath()
        let s = min(rect.width / 24, rect.height / 24)
        let t = CGAffineTransform(translationX: rect.midX - 24 * s / 2,
                                  y: rect.midY - 24 * s / 2)
            .scaledBy(x: s, y: s)
        return p.applying(t)
    }
}

/// Figma export: home/cal-tabperson.svg
struct DSTabPersonIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 12.000, y: 12.000))
        p.addCurve(to: CGPoint(x: 16.000, y: 8.000), control1: CGPoint(x: 14.210, y: 12.000), control2: CGPoint(x: 16.000, y: 10.210))
        p.addCurve(to: CGPoint(x: 12.000, y: 4.000), control1: CGPoint(x: 16.000, y: 5.790), control2: CGPoint(x: 14.210, y: 4.000))
        p.addCurve(to: CGPoint(x: 8.000, y: 8.000), control1: CGPoint(x: 9.790, y: 4.000), control2: CGPoint(x: 8.000, y: 5.790))
        p.addCurve(to: CGPoint(x: 12.000, y: 12.000), control1: CGPoint(x: 8.000, y: 10.210), control2: CGPoint(x: 9.790, y: 12.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 12.000, y: 14.000))
        p.addCurve(to: CGPoint(x: 4.000, y: 18.000), control1: CGPoint(x: 9.330, y: 14.000), control2: CGPoint(x: 4.000, y: 15.340))
        p.addLine(to: CGPoint(x: 4.000, y: 19.000))
        p.addCurve(to: CGPoint(x: 5.000, y: 20.000), control1: CGPoint(x: 4.000, y: 19.550), control2: CGPoint(x: 4.450, y: 20.000))
        p.addLine(to: CGPoint(x: 19.000, y: 20.000))
        p.addCurve(to: CGPoint(x: 20.000, y: 19.000), control1: CGPoint(x: 19.550, y: 20.000), control2: CGPoint(x: 20.000, y: 19.550))
        p.addLine(to: CGPoint(x: 20.000, y: 18.000))
        p.addCurve(to: CGPoint(x: 12.000, y: 14.000), control1: CGPoint(x: 20.000, y: 15.340), control2: CGPoint(x: 14.670, y: 14.000))
        p.closeSubpath()
        let s = min(rect.width / 24, rect.height / 24)
        let t = CGAffineTransform(translationX: rect.midX - 24 * s / 2,
                                  y: rect.midY - 24 * s / 2)
            .scaledBy(x: s, y: s)
        return p.applying(t)
    }
}

/// Figma export: home/ic-bag.svg — layered price tags (faint back, solid front
/// with a punched string hole)
struct DSBagIcon: View {
    var body: some View {
        ZStack {
            DSBagBackShape().fill(.white.opacity(0.19))
            DSBagFrontShape().fill(.white.opacity(0.65))
        }
    }
}

struct DSBagBackShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 23.503, y: 4.296))
        p.addCurve(to: CGPoint(x: 21.524, y: 3.519), control1: CGPoint(x: 22.980, y: 3.773), control2: CGPoint(x: 22.263, y: 3.491))
        p.addLine(to: CGPoint(x: 13.127, y: 3.833))
        p.addCurve(to: CGPoint(x: 10.569, y: 6.391), control1: CGPoint(x: 11.736, y: 3.885), control2: CGPoint(x: 10.621, y: 5.001))
        p.addLine(to: CGPoint(x: 10.255, y: 14.788))
        p.addCurve(to: CGPoint(x: 11.032, y: 16.768), control1: CGPoint(x: 10.227, y: 15.527), control2: CGPoint(x: 10.508, y: 16.244))
        p.addLine(to: CGPoint(x: 20.803, y: 26.539))
        p.addCurve(to: CGPoint(x: 24.563, y: 26.539), control1: CGPoint(x: 21.841, y: 27.577), control2: CGPoint(x: 23.525, y: 27.577))
        p.addLine(to: CGPoint(x: 33.275, y: 17.827))
        p.addCurve(to: CGPoint(x: 33.275, y: 14.067), control1: CGPoint(x: 34.313, y: 16.789), control2: CGPoint(x: 34.313, y: 15.105))
        p.addLine(to: CGPoint(x: 23.503, y: 4.296))
        p.closeSubpath()
        let s = min(rect.width / 37.9973, rect.height / 35.4995)
        let t = CGAffineTransform(translationX: rect.midX - 37.9973 * s / 2,
                                  y: rect.midY - 35.4995 * s / 2)
            .scaledBy(x: s, y: s)
        return p.applying(t)
    }
}

struct DSBagFrontShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 10.955, y: 5.536))
        p.addCurve(to: CGPoint(x: 14.572, y: 5.536), control1: CGPoint(x: 11.975, y: 4.590), control2: CGPoint(x: 13.552, y: 4.590))
        p.addCurve(to: CGPoint(x: 20.731, y: 11.251), control1: CGPoint(x: 16.970, y: 7.761), control2: CGPoint(x: 20.709, y: 11.230))
        p.addCurve(to: CGPoint(x: 21.581, y: 13.200), control1: CGPoint(x: 21.273, y: 11.754), control2: CGPoint(x: 21.581, y: 12.460))
        p.addLine(to: CGPoint(x: 21.581, y: 27.018))
        p.addCurve(to: CGPoint(x: 18.922, y: 29.678), control1: CGPoint(x: 21.581, y: 28.487), control2: CGPoint(x: 20.391, y: 29.678))
        p.addLine(to: CGPoint(x: 6.603, y: 29.678))
        p.addCurve(to: CGPoint(x: 3.944, y: 27.018), control1: CGPoint(x: 5.134, y: 29.678), control2: CGPoint(x: 3.944, y: 28.487))
        p.addLine(to: CGPoint(x: 3.944, y: 13.200))
        p.addCurve(to: CGPoint(x: 4.794, y: 11.251), control1: CGPoint(x: 3.944, y: 12.460), control2: CGPoint(x: 4.252, y: 11.754))
        p.addCurve(to: CGPoint(x: 10.955, y: 5.536), control1: CGPoint(x: 4.794, y: 11.251), control2: CGPoint(x: 8.549, y: 7.768))
        p.closeSubpath()
        p.move(to: CGPoint(x: 12.767, y: 6.911))
        p.addCurve(to: CGPoint(x: 10.889, y: 8.789), control1: CGPoint(x: 11.730, y: 6.911), control2: CGPoint(x: 10.889, y: 7.752))
        p.addCurve(to: CGPoint(x: 12.767, y: 10.667), control1: CGPoint(x: 10.889, y: 9.826), control2: CGPoint(x: 11.730, y: 10.667))
        p.addCurve(to: CGPoint(x: 14.645, y: 8.789), control1: CGPoint(x: 13.804, y: 10.667), control2: CGPoint(x: 14.645, y: 9.826))
        p.addCurve(to: CGPoint(x: 12.767, y: 6.911), control1: CGPoint(x: 14.645, y: 7.752), control2: CGPoint(x: 13.804, y: 6.911))
        p.closeSubpath()
        let s = min(rect.width / 37.9973, rect.height / 35.4995)
        let t = CGAffineTransform(translationX: rect.midX - 37.9973 * s / 2,
                                  y: rect.midY - 35.4995 * s / 2)
            .scaledBy(x: s, y: s)
        return p.applying(t)
    }
}

/// Figma export: home/ic-star.svg
struct DSStarIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 16.000, y: 23.360))
        p.addLine(to: CGPoint(x: 21.533, y: 26.706))
        p.addCurve(to: CGPoint(x: 23.520, y: 25.266), control1: CGPoint(x: 22.547, y: 27.320), control2: CGPoint(x: 23.787, y: 26.413))
        p.addLine(to: CGPoint(x: 22.053, y: 18.973))
        p.addLine(to: CGPoint(x: 26.947, y: 14.733))
        p.addCurve(to: CGPoint(x: 26.187, y: 12.399), control1: CGPoint(x: 27.840, y: 13.960), control2: CGPoint(x: 27.360, y: 12.493))
        p.addLine(to: CGPoint(x: 19.747, y: 11.853))
        p.addLine(to: CGPoint(x: 17.227, y: 5.906))
        p.addCurve(to: CGPoint(x: 14.773, y: 5.906), control1: CGPoint(x: 16.773, y: 4.826), control2: CGPoint(x: 15.227, y: 4.826))
        p.addLine(to: CGPoint(x: 12.253, y: 11.839))
        p.addLine(to: CGPoint(x: 5.813, y: 12.386))
        p.addCurve(to: CGPoint(x: 5.053, y: 14.720), control1: CGPoint(x: 4.640, y: 12.479), control2: CGPoint(x: 4.160, y: 13.946))
        p.addLine(to: CGPoint(x: 9.947, y: 18.959))
        p.addLine(to: CGPoint(x: 8.480, y: 25.253))
        p.addCurve(to: CGPoint(x: 10.467, y: 26.693), control1: CGPoint(x: 8.213, y: 26.399), control2: CGPoint(x: 9.453, y: 27.306))
        p.addLine(to: CGPoint(x: 16.000, y: 23.360))
        p.closeSubpath()
        let s = min(rect.width / 32, rect.height / 32)
        let t = CGAffineTransform(translationX: rect.midX - 32 * s / 2,
                                  y: rect.midY - 32 * s / 2)
            .scaledBy(x: s, y: s)
        return p.applying(t)
    }
}

/// Figma export: home/ic-bell.svg
struct DSBellIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 16.002, y: 29.000))
        p.addCurve(to: CGPoint(x: 18.668, y: 26.333), control1: CGPoint(x: 17.468, y: 29.000), control2: CGPoint(x: 18.668, y: 27.800))
        p.addLine(to: CGPoint(x: 13.335, y: 26.333))
        p.addCurve(to: CGPoint(x: 16.002, y: 29.000), control1: CGPoint(x: 13.335, y: 27.800), control2: CGPoint(x: 14.522, y: 29.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 24.002, y: 21.000))
        p.addLine(to: CGPoint(x: 24.002, y: 14.333))
        p.addCurve(to: CGPoint(x: 18.002, y: 5.907), control1: CGPoint(x: 24.002, y: 10.240), control2: CGPoint(x: 21.815, y: 6.813))
        p.addLine(to: CGPoint(x: 18.002, y: 5.000))
        p.addCurve(to: CGPoint(x: 16.002, y: 3.000), control1: CGPoint(x: 18.002, y: 3.893), control2: CGPoint(x: 17.108, y: 3.000))
        p.addCurve(to: CGPoint(x: 14.002, y: 5.000), control1: CGPoint(x: 14.895, y: 3.000), control2: CGPoint(x: 14.002, y: 3.893))
        p.addLine(to: CGPoint(x: 14.002, y: 5.907))
        p.addCurve(to: CGPoint(x: 8.002, y: 14.333), control1: CGPoint(x: 10.175, y: 6.813), control2: CGPoint(x: 8.002, y: 10.227))
        p.addLine(to: CGPoint(x: 8.002, y: 21.000))
        p.addLine(to: CGPoint(x: 6.282, y: 22.720))
        p.addCurve(to: CGPoint(x: 7.215, y: 25.000), control1: CGPoint(x: 5.442, y: 23.560), control2: CGPoint(x: 6.028, y: 25.000))
        p.addLine(to: CGPoint(x: 24.775, y: 25.000))
        p.addCurve(to: CGPoint(x: 25.722, y: 22.720), control1: CGPoint(x: 25.962, y: 25.000), control2: CGPoint(x: 26.562, y: 23.560))
        p.addLine(to: CGPoint(x: 24.002, y: 21.000))
        p.closeSubpath()
        let s = min(rect.width / 32, rect.height / 32)
        let t = CGAffineTransform(translationX: rect.midX - 32 * s / 2,
                                  y: rect.midY - 32 * s / 2)
            .scaledBy(x: s, y: s)
        return p.applying(t)
    }
}

/// Figma export: home/ic-calbody.svg — white body, dot holes let the red through
struct DSCalendarIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 19.258, y: 0.271))
        p.addCurve(to: CGPoint(x: 23.942, y: 4.955), control1: CGPoint(x: 21.845, y: 0.271), control2: CGPoint(x: 23.942, y: 2.368))
        p.addLine(to: CGPoint(x: 23.942, y: 17.136))
        p.addCurve(to: CGPoint(x: 19.258, y: 21.822), control1: CGPoint(x: 23.942, y: 19.724), control2: CGPoint(x: 21.845, y: 21.822))
        p.addLine(to: CGPoint(x: 5.202, y: 21.822))
        p.addCurve(to: CGPoint(x: 0.517, y: 17.136), control1: CGPoint(x: 2.615, y: 21.822), control2: CGPoint(x: 0.517, y: 19.724))
        p.addLine(to: CGPoint(x: 0.517, y: 4.955))
        p.addCurve(to: CGPoint(x: 5.202, y: 0.271), control1: CGPoint(x: 0.517, y: 2.368), control2: CGPoint(x: 2.615, y: 0.271))
        p.addLine(to: CGPoint(x: 19.258, y: 0.271))
        p.closeSubpath()
        p.move(to: CGPoint(x: 6.139, y: 12.155))
        p.addCurve(to: CGPoint(x: 5.202, y: 13.092), control1: CGPoint(x: 5.622, y: 12.155), control2: CGPoint(x: 5.202, y: 12.575))
        p.addLine(to: CGPoint(x: 5.202, y: 14.029))
        p.addCurve(to: CGPoint(x: 6.139, y: 14.966), control1: CGPoint(x: 5.202, y: 14.546), control2: CGPoint(x: 5.622, y: 14.966))
        p.addLine(to: CGPoint(x: 7.076, y: 14.966))
        p.addCurve(to: CGPoint(x: 8.013, y: 14.029), control1: CGPoint(x: 7.593, y: 14.966), control2: CGPoint(x: 8.013, y: 14.546))
        p.addLine(to: CGPoint(x: 8.013, y: 13.092))
        p.addCurve(to: CGPoint(x: 7.076, y: 12.155), control1: CGPoint(x: 8.013, y: 12.575), control2: CGPoint(x: 7.593, y: 12.155))
        p.addLine(to: CGPoint(x: 6.139, y: 12.155))
        p.closeSubpath()
        p.move(to: CGPoint(x: 11.761, y: 12.155))
        p.addCurve(to: CGPoint(x: 10.824, y: 13.092), control1: CGPoint(x: 11.244, y: 12.155), control2: CGPoint(x: 10.824, y: 12.575))
        p.addLine(to: CGPoint(x: 10.824, y: 14.029))
        p.addCurve(to: CGPoint(x: 11.761, y: 14.966), control1: CGPoint(x: 10.824, y: 14.546), control2: CGPoint(x: 11.244, y: 14.966))
        p.addLine(to: CGPoint(x: 12.698, y: 14.966))
        p.addCurve(to: CGPoint(x: 13.635, y: 14.029), control1: CGPoint(x: 13.215, y: 14.966), control2: CGPoint(x: 13.635, y: 14.546))
        p.addLine(to: CGPoint(x: 13.635, y: 13.092))
        p.addCurve(to: CGPoint(x: 12.698, y: 12.155), control1: CGPoint(x: 13.635, y: 12.575), control2: CGPoint(x: 13.215, y: 12.155))
        p.addLine(to: CGPoint(x: 11.761, y: 12.155))
        p.closeSubpath()
        p.move(to: CGPoint(x: 17.383, y: 12.155))
        p.addCurve(to: CGPoint(x: 16.446, y: 13.092), control1: CGPoint(x: 16.866, y: 12.155), control2: CGPoint(x: 16.446, y: 12.575))
        p.addLine(to: CGPoint(x: 16.446, y: 14.029))
        p.addCurve(to: CGPoint(x: 17.383, y: 14.966), control1: CGPoint(x: 16.446, y: 14.546), control2: CGPoint(x: 16.866, y: 14.966))
        p.addLine(to: CGPoint(x: 18.320, y: 14.966))
        p.addCurve(to: CGPoint(x: 19.258, y: 14.029), control1: CGPoint(x: 18.837, y: 14.966), control2: CGPoint(x: 19.258, y: 14.546))
        p.addLine(to: CGPoint(x: 19.258, y: 13.092))
        p.addCurve(to: CGPoint(x: 18.320, y: 12.155), control1: CGPoint(x: 19.258, y: 12.575), control2: CGPoint(x: 18.837, y: 12.155))
        p.addLine(to: CGPoint(x: 17.383, y: 12.155))
        p.closeSubpath()
        p.move(to: CGPoint(x: 6.139, y: 6.533))
        p.addCurve(to: CGPoint(x: 5.202, y: 7.470), control1: CGPoint(x: 5.622, y: 6.533), control2: CGPoint(x: 5.202, y: 6.953))
        p.addLine(to: CGPoint(x: 5.202, y: 8.407))
        p.addCurve(to: CGPoint(x: 6.139, y: 9.344), control1: CGPoint(x: 5.202, y: 8.924), control2: CGPoint(x: 5.622, y: 9.344))
        p.addLine(to: CGPoint(x: 7.076, y: 9.344))
        p.addCurve(to: CGPoint(x: 8.013, y: 8.407), control1: CGPoint(x: 7.593, y: 9.344), control2: CGPoint(x: 8.013, y: 8.924))
        p.addLine(to: CGPoint(x: 8.013, y: 7.470))
        p.addCurve(to: CGPoint(x: 7.076, y: 6.533), control1: CGPoint(x: 8.013, y: 6.953), control2: CGPoint(x: 7.593, y: 6.533))
        p.addLine(to: CGPoint(x: 6.139, y: 6.533))
        p.closeSubpath()
        p.move(to: CGPoint(x: 11.761, y: 6.533))
        p.addCurve(to: CGPoint(x: 10.824, y: 7.470), control1: CGPoint(x: 11.244, y: 6.533), control2: CGPoint(x: 10.824, y: 6.953))
        p.addLine(to: CGPoint(x: 10.824, y: 8.407))
        p.addCurve(to: CGPoint(x: 11.761, y: 9.344), control1: CGPoint(x: 10.824, y: 8.924), control2: CGPoint(x: 11.244, y: 9.344))
        p.addLine(to: CGPoint(x: 12.698, y: 9.344))
        p.addCurve(to: CGPoint(x: 13.635, y: 8.407), control1: CGPoint(x: 13.215, y: 9.344), control2: CGPoint(x: 13.635, y: 8.924))
        p.addLine(to: CGPoint(x: 13.635, y: 7.470))
        p.addCurve(to: CGPoint(x: 12.698, y: 6.533), control1: CGPoint(x: 13.635, y: 6.953), control2: CGPoint(x: 13.215, y: 6.533))
        p.addLine(to: CGPoint(x: 11.761, y: 6.533))
        p.closeSubpath()
        p.move(to: CGPoint(x: 17.383, y: 6.533))
        p.addCurve(to: CGPoint(x: 16.446, y: 7.470), control1: CGPoint(x: 16.866, y: 6.533), control2: CGPoint(x: 16.446, y: 6.953))
        p.addLine(to: CGPoint(x: 16.446, y: 8.407))
        p.addCurve(to: CGPoint(x: 17.383, y: 9.344), control1: CGPoint(x: 16.446, y: 8.924), control2: CGPoint(x: 16.866, y: 9.344))
        p.addLine(to: CGPoint(x: 18.320, y: 9.344))
        p.addCurve(to: CGPoint(x: 19.258, y: 8.407), control1: CGPoint(x: 18.837, y: 9.344), control2: CGPoint(x: 19.258, y: 8.924))
        p.addLine(to: CGPoint(x: 19.258, y: 7.470))
        p.addCurve(to: CGPoint(x: 18.320, y: 6.533), control1: CGPoint(x: 19.258, y: 6.953), control2: CGPoint(x: 18.837, y: 6.533))
        p.addLine(to: CGPoint(x: 17.383, y: 6.533))
        p.closeSubpath()
        let s = min(rect.width / 24.4592, rect.height / 22.5852)
        let t = CGAffineTransform(translationX: rect.midX - 24.4592 * s / 2,
                                  y: rect.midY - 22.5852 * s / 2)
            .scaledBy(x: s, y: s)
        return p.applying(t)
    }
}

@available(iOS 26.0, *)
#Preview {
    HomeScreenNative()
}
