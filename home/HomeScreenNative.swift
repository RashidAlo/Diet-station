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
    /// THE bar placement rule v2 (Rashid 2026-09-09): match Apple Music /
    /// App Store — the floating bar hugs the home indicator, bottom =
    /// safeArea + 4 (was +12, read too high on device)
    static let barBottom: CGFloat = 4
    static let onColor = Color(red: 249/255, green: 249/255, blue: 249/255)
    static let ink = Color(red: 11/255, green: 14/255, blue: 18/255)
    static let caption = Color(red: 94/255, green: 94/255, blue: 94/255)
    static let assets = "https://rashidalo.github.io/Diet-station/home/"
    /// the selector's meal-details page, standalone — home summons THE
    /// design, no recreated screens (Rashid)
    static let soloDetails = "meal-select/select.html?solo=1"
    /// the auth flow self-presenting over the live home (scrim dissolves
    /// in place, sheet springs — THE OVERLAY RULE)
    static let authSolo = "auth/?solo=1"
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

/// Ink cap top above the baseline, from the glyphs' own bounding rects —
/// measured once per font, size and sample, then cached.
enum DSInkTop {
    private static var cache: [String: CGFloat] = [:]
    static func top(_ name: String, _ size: CGFloat, _ sample: String) -> CGFloat {
        let key = "\(name)|\(size)|\(sample)"
        if let v = cache[key] { return v }
        let font = CTFontCreateWithName(name as CFString, size, nil)
        let chars = Array(sample.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        CTFontGetGlyphsForCharacters(font, chars, &glyphs, chars.count)
        let r = CTFontGetBoundingRectsForGlyphs(font, .horizontal, glyphs, nil, glyphs.count)
        cache[key] = r.maxY
        return r.maxY
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
    /// Figma 16360-78205 "Not logged in": Sign-in greeting, Book/Guide
    /// widgets, and the plans list on the sheet (lab Account toggle)
    var loggedOut = false
    /// ONE presentation slot for every summoned flow. FOUR stacked
    /// .fullScreenCover modifiers on one view silently break all but the
    /// last-attached (the phantom-close hunt's actual culprit: the coupons
    /// cover presented its scrim and was dismissed by SwiftUI within ~0.5s,
    /// no page code ever ran — while auth, last in the chain, worked).
    enum Summon: Identifiable, Equatable {
        case coupons, guide, auth
        case meal(DSStripMeal)
        var id: String {
            switch self {
            case .coupons: return "coupons"
            case .guide: return "guide"
            case .auth: return "auth"
            case .meal(let m): return "meal-\(m.id)"
            }
        }
    }
    var summon: Summon?
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
    /// Apple-Music-style modular bar — the calorie counter lives IN the
    /// tab bar row and disconnects into its own glass macros row on
    /// scroll. PROMOTED TO DEFAULT (Rashid 2026-09-09 late); the classic
    /// three-tab bar stays as the lab's secondary option.
    var tabBarDynamic = true
    var labOpen = false
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

/// A strip meal with everything its details page shows — the home pilot's
/// mirror of the selector's dish records (lab sample data).
struct DSStripMeal: Identifiable, Equatable {
    let img: String
    let name: String
    let kcal: Int, p: Int, c: Int, f: Int
    let rating: Double
    let hot: Bool           // hot mains get the microwave chip pair
    let ing: [String]
    var id: String { name }
}

// MARK: - Screen

@available(iOS 26.0, *)
struct HomeScreenNative: View {
    @State private var state = HomeState()
    @Namespace private var glassNS
    var onClose: (() -> Void)? = nil
    /* entrance choreography: widgets arrive staggered, then the days dial
       sweeps to its value while the number counts down from 30 */
    /// chrome layers: true while the calendar's meal selector owns the whole
    /// screen — the persistent bar slides away for it (topmost surface only)
    @State private var selectorUp = false
    /// the calendar's layer set is non-empty (platform.html `layer`): some
    /// web surface — a lab menu, the selector — owns the screen
    @State private var layersUp = false
    /// dynamic-bar experiment: past this scroll depth the inline kcal module
    /// disconnects into its own glass macros row (Music's accessory beat)
    @State private var homeScrolled = false
    /// the ScrollView's RESTING offset is not 0 (safe-area adjusted) — the
    /// scroll trigger measures depth relative to this first-report baseline,
    /// else the accessory latches open at boot
    @State private var scrollBase: CGFloat?
    /// adaptive bar (Rashid: Apple's way — the bar reads the content behind
    /// it): live global frames of the DARK bands (red page, photo strip) and
    /// of the bar itself; overlap drives the bar's colorScheme
    @State private var stripFrame: CGRect = .zero
    @State private var sheetFrame: CGRect = .zero
    @State private var barFrame: CGRect = .zero
    @Namespace private var modNS

    /// true while dark content (the red page or the meal photos) sits under
    /// the bar — the bar's environment flips to .dark and the Liquid Glass
    /// + glyphs adapt, exactly like the system tab bar over dark content
    private var barIsOverDark: Bool {
        guard tabSel == .home, !state.calendarOpen, barFrame.height > 0 else { return false }
        // signed-out home has no photo strip; a stale strip rect must not
        // darken the bar — only the red page above the plans sheet counts
        if state.loggedOut { return sheetFrame.minY > barFrame.midY }
        if sheetFrame.minY > barFrame.midY { return true }   // white sheet not here yet: red page
        return barFrame.intersection(stripFrame).height > barFrame.height * 0.5
    }
    /// Reduce Motion is a requirement, not a preference (system/motion.html
    /// HIG section): counters land instantly and the strip's day switch
    /// stops animating for those users
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false
    @State private var contentIn = true   // re-toggled for return intros;
                                          // the persistent bar never blinks
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
                    if state.loggedOut {
                        arrival(loggedOutTopRow, 0)
                        arrival(optionsRow, 1)
                    } else {
                        arrival(topRow, 0)
                        if urgent { arrival(urgentBanner, 1) }
                        else if state.showPromo { arrival(promoBanner, 1) }
                        widgetGrid
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
                // STRUCTURE IS STATIC (Rashid): the white sheet container
                // renders instantly on every entrance and tab return — only
                // the CONTENT inside it staggers in (wrapped within)
                if state.loggedOut { plansSheet }
                else { mealSheet }
            }
            .ignoresSafeArea(edges: .bottom)
            .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, y in
                guard state.tabBarDynamic else { return }
                if scrollBase == nil { scrollBase = y }
                let deep = y > (scrollBase ?? 0) + 60
                guard deep != homeScrolled else { return }
                // one clean morph (Rashid: no slide, no beats): the pill
                // rises from its slot and WIDENS — right edges pinned by
                // the trailing-aligned stack, so nothing travels sideways
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    homeScrolled = deep
                }
            }
            if state.calendarOpen {
                // the calendar lives UNDER the persistent bar — no cover, no
                // second bar, no position shift; the web sheet spring is the
                // only transition (Rashid: same bar, same place, seamless)
                FlowOverlay(path: "meal-select", ownsTabBar: false,
                            // NOTHING NATIVE ANIMATES HERE. Measured by the
                            // Calendar lane: the ~620ms travel they saw is
                            // their own page's first paint and layout settle
                            // (its body IS brand red, so the pilot is never
                            // uncovered and there is nothing for a cover to
                            // reveal). Publishing a presentation duration on
                            // this path would be a wrong number in the worst
                            // direction — a page delaying its entry for an
                            // animation that never runs.
                            presentSettle: 0,
                            onSelector: { selectorUp = $0 },
                            onLayers: { layersUp = $0 }) {
                    state.calendarOpen = false
                    selectorUp = false
                    layersUp = false
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { tabSel = .home }
                    replayHomeIntro()
                }
                .zIndex(2)
                .onAppear {
                    // warm webviews played their entrance offscreen — replay
                    // it now that the page is actually on stage
                    FlowPreloader.shared.entry("meal-select").web
                        .evaluateJavaScript("window.DSReplayIntro && DSReplayIntro()",
                                            completionHandler: nil)
                }
            }
            arrival(bottomBar, 5)
                .padding(.bottom, DS.barBottom)   // THE placement rule v2 (Music)
                // adaptive bar (Apple's way): dark content behind flips the
                // subtree's colorScheme — the Liquid Glass renders its dark
                // variant and the glyphs adapt with it
                .environment(\.colorScheme, barIsOverDark ? .dark : .light)
                .animation(.easeInOut(duration: 0.25), value: barIsOverDark)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { r in
                    barFrame = r
                }
                // chrome layers: while any web layer (the meal selector, a lab
                // menu) owns the screen the ONE bar yields — slides out under
                // the rising sheet and returns as it departs; it never
                // unmounts, so no reflow
                .opacity(barYields ? 0 : 1)
                .offset(y: barYields ? 90 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.85), value: barYields)
                .zIndex(3)
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
        // strip meal tap → THE meal-details page from the selection flow,
        // summoned solo (Rashid: same design, no recreated screens). THE
        // RULE: within 72 hours the meal is already in prep — ingredient
        // switches DISABLE; far days stay editable.
        /* web flows summoned over the native screen — ONE item-driven cover
           for all of them (stacked cover modifiers on one view silently
           break all but the last). Each flow runs its own sheet
           choreography and posts ds-close when done. */
        /* NOTE: no .ignoresSafeArea() on the cover content — FlowOverlay's
           webview/glass layers ignore it internally, but its DS bar must get
           safe-area placement (the Rashid-endorsed rule every DS bar
           shares; a whole-cover ignore pushed the bar to the raw edge). */
        .fullScreenCover(item: $state.summon) { summon in
            switch summon {
            case .meal(let meal):
                // strip meal tap → THE meal-details page from the selection
                // flow, summoned solo (Rashid: same design, no recreated
                // screens). THE RULE: within 72 hours the meal is in prep —
                // ingredient switches DISABLE; far days stay editable.
                FlowOverlay(path: DS.soloDetails) { instant { state.summon = nil } }
                    .presentationBackground(Color.black.opacity(0.42))
                    .onAppear {
                        let locked = state.days[state.stripDay].off < 3
                        let ing = meal.ing.map { "'\($0)'" }.joined(separator: ",")
                        let js = """
                        window.DSSoloOpen && DSSoloOpen({ cat: '\(state.dayWord(state.stripDay))', \
                        n: '\(meal.name)', img: '\(DS.assets + meal.img)', \
                        kcal: \(meal.kcal), p: \(meal.p), c: \(meal.c), f: \(meal.f), \
                        r: '\(meal.rating)', hot: \(meal.hot), ing: [\(ing)] }, \(locked))
                        """
                        FlowPreloader.shared.entry(DS.soloDetails).web
                            .evaluateJavaScript(js, completionHandler: nil)
                    }
            case .coupons:
                // REVERTED (Rashid): the web coupon experience is the design —
                // rip physics, levels, sounds. Native's job here is ONLY the
                // glasschrome X twin the overlay already renders.
                FlowOverlay(path: "rewards") { instant { state.summon = nil } }
                    .presentationBackground(Color.black.opacity(0.42))
            case .guide:
                // signed-out Guide me = the Guide Me experience (plan-quiz)
                FlowOverlay(path: "plan-quiz") { instant { state.summon = nil } }
                    .presentationBackground(Color.black.opacity(0.42))
            case .auth:
                // Sign in = the auth lane's flow. THE OVERLAY RULE (Rashid):
                // scrims never travel — the cover is TRANSPARENT with the
                // system slide suppressed; auth's ?solo=1 page dissolves its
                // own scrim in place, only its sheet rides the house spring
                FlowOverlay(path: DS.authSolo) { instant { state.summon = nil } }
                    .presentationBackground(.clear)
            }
        }
        // warm the auth webview whenever the signed-out state arrives, so
        // the Sign in tap presents instantly like every other summon
        .onChange(of: state.loggedOut) {
            if state.loggedOut { FlowPreloader.shared.warm([DS.authSolo]) }
        }

        .animation(.spring(duration: 0.45), value: state.loggedOut)
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
                    if p == "rewards" { state.summon = .coupons }
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
            // SIMCTL_CHILD_DSLAB_DYNBAR=1 arms the dynamic-bar experiment —
            // sheet toggles resist scripted taps, so QA flips it here
            if ProcessInfo.processInfo.environment["DSLAB_DYNBAR"] != nil {
                state.tabBarDynamic = true
            }
            // SIMCTL_CHILD_DSLAB_LOGGEDOUT=1 boots the signed-out home for
            // the headless sim loop
            if ProcessInfo.processInfo.environment["DSLAB_LOGGEDOUT"] != nil {
                state.loggedOut = true
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
        let on = arrived && (index >= 5 || contentIn)   // bar (5) rides arrived only
        return v.opacity(on ? 1 : 0)
            .scaleEffect(on ? 1 : 0.94, anchor: .center)
            .offset(y: on ? 0 : 10)
            .animation(.spring(duration: 0.55).delay(0.07 * index), value: on)
    }

    /// brief page intro when home comes back into view (Rashid: no static
    /// switches) — the content restaggers, the bar stays put
    private func replayHomeIntro() {
        contentIn = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { contentIn = true }
    }

    private func runIntro() async {
        try? await Task.sleep(for: .milliseconds(60))
        arrived = true
        /* warm the summonable flows while the intro plays — a Discounts or
           calendar tap then presents an already-loaded page instantly */
        FlowPreloader.shared.warm(["rewards", "meal-select", DS.soloDetails])
        if state.loggedOut { FlowPreloader.shared.warm(["auth"]) }
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

    private func tabHandler(_ tab: DSTabId) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { tabSel = tab }
        // Apple's beat, TIGHTENED (Rashid: quicker tab transitions) — the
        // pill starts landing, the page swaps under it almost immediately;
        // structure shows statically, only content staggers in
        if tab == .calendar, !state.calendarOpen, !state.loggedOut {
            selectorUp = false   // stale layer state never hides the bar
            layersUp = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                state.calendarOpen = true
            }
        } else if tab == .home, state.calendarOpen {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                state.calendarOpen = false
                replayHomeIntro()
            }
        }
    }

    private var barYields: Bool { state.calendarOpen && (selectorUp || layersUp) }

    private var tabBar: some View {
        DSTabBar(selected: tabSel, onSelect: tabHandler, forkMiddle: state.loggedOut)
    }

    /// Music-style modular bar (lab experiment, Rashid 2026-09-09): at rest
    /// the kcal module rides IN the bar row; scrolling disconnects it into
    /// its own glass macros row above — one matched-geometry morph.
    private var dynamicOn: Bool {
        // signed-out home has no calorie data — the bar absorbs the full 370
        state.tabBarDynamic && tabSel == .home && !state.calendarOpen && !state.loggedOut
    }

    @ViewBuilder private var bottomBar: some View {
        if state.tabBarDynamic {
            // trailing-aligned: the pill and the accessory SHARE a right
            // edge, so the morph reads as a pure rise-and-widen (Rashid:
            // no slide) — the left edge does all the growing.
            // WIDTH RULE v3 (Rashid 2026-09-10, supersedes 370-on-every-tab):
            // the full 370 footprint belongs ONLY to the dynamic module —
            // wherever the bar is three plain links (signed-out home, the
            // calendar page, any other tab) it shrinks to 256 and centers
            VStack(alignment: .trailing, spacing: 10) {
                if dynamicOn && homeScrolled { kcalCapsule }
                HStack(spacing: 10) {
                    DSTabBar(selected: tabSel, onSelect: tabHandler,
                             width: dynamicOn && homeScrolled ? 370 : 256,
                             forkMiddle: state.loggedOut)
                    if dynamicOn && !homeScrolled {
                        kcalCapsule.transition(.opacity)
                    }
                }
            }
        } else {
            tabBar
        }
    }

    /// ONE capsule for both states (Rashid: "expand, not dissolve" — the
    /// pill hops in and ELONGATES as if it contained all the extra data):
    /// the kcal group is constant; the macros tail lives inside and is
    /// revealed by the stretch. Both matched instances render this same
    /// tree, so the geometry morph reads as a single object growing.
    private var kcalCapsule: some View {
        let d = state.days[state.stripDay]
        return HStack(spacing: 0) {
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(verbatim: "\(d.kcal)").font(DS.urbane(17, .semibold))
                    .monospacedDigit()   // rolling digits never nudge layout
                    .contentTransition(.numericText(value: Double(d.kcal)))
                Text("kcal").font(DS.urbane(10, .medium)).opacity(0.55)
            }
            .fixedSize()
            if homeScrolled {
                Group {
                    Spacer(minLength: 14)
                    thinPair(d.p, "Protein").fixedSize()
                    Spacer(minLength: 14)
                    thinPair(d.c, "Carbs").fixedSize()
                    Spacer(minLength: 14)
                    thinPair(d.f, "Fat").fixedSize()
                }
                .transition(.opacity)
            }
        }
        .foregroundStyle(barIsOverDark ? .white : DS.ink)
        .padding(.horizontal, homeScrolled ? 22 : 16)
        .frame(width: homeScrolled ? 370 : 104, height: homeScrolled ? 46 : 58)
        // same material as the tab bar it belongs to (Rashid)
        .glassEffect(.regular.interactive(), in: .capsule)
        .matchedGeometryEffect(id: "kcalmod", in: modNS)
        // the strip's day switch rolls the digits (Rashid: counting, not
        // snapping, as the meals scroll between days)
        .animation(reduceMotion ? nil : .spring(duration: 0.55), value: state.stripDay)
    }

    private func thinPair(_ v: Int, _ label: String) -> some View {
        let ink: Color = barIsOverDark ? .white : DS.ink
        return HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text(label).font(DS.urbane(10, .medium)).foregroundStyle(ink.opacity(0.5))
            Text(verbatim: "\(v)").font(DS.urbane(15, .semibold)).foregroundStyle(ink)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(v)))
            Text("g").font(DS.proxima(9)).foregroundStyle(ink.opacity(0.5))
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
                        Text("KD139").font(DS.urbane(11))
                            .foregroundStyle(DS.onColor.opacity(0.7))
                            // one strike, the diagonal (DS ruling): 1pt at
                            // −9.87°, painted for the red ground
                            .overlay {
                                Capsule().fill(DS.onColor.opacity(0.7)).frame(height: 1)
                                    .rotationEffect(.degrees(-9.87))
                                    .padding(.horizontal, -1)
                            }
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
            HStack { Spacer(); DSCouponIcon().frame(width: 46, height: 40.6) }
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
        .onTapGesture { instant { state.summon = .coupons } }
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
            DSCouponIcon().frame(width: 34, height: 30)
        }
        .padding(.horizontal, 19)
        .frame(maxWidth: .infinity)
        .frame(height: 60)   // twin of consult — slimmer so days-left breathes
        .glassEffect(.clear.tint(DS.red.opacity(0.15)).interactive(),
                     in: .rect(cornerRadius: DS.tile(60)))
        .glassEffectID("disc", in: glassNS)
        .contentShape(RoundedRectangle(cornerRadius: DS.tile(60)))
        .onTapGesture { instant { state.summon = .coupons } }   // summon the coupons flow
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

    // MARK: signed-out home (Figma 16360-78205 "Not logged in")

    /// DS ring greeting + Sign in, one phone dock on the right; the whole
    /// greeting is the door into the auth flow (the auth lane's contract)
    private var loggedOutTopRow: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                // no system slide — auth's solo page runs the presentation
                instant { state.summon = .auth }
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.9), lineWidth: 1.6)
                        DSLogoMark().fill(.white).frame(width: 26, height: 20)
                    }
                    .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 1) {
                        (Text("☀️ ").font(.system(size: 11))
                         + Text("صبحك الله بالخير").font(DS.avenirWorld(12)))
                            .foregroundStyle(DS.onColor)
                            .id("lo-greeting-\(fontTick)")
                        (Text("Got an account? ").font(DS.urbane(14, .light))
                         + Text("Sign in").font(DS.urbane(14, .semibold)))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.leading, 8)   // Figma: the ring sits at the deeper 28
            }
            .buttonStyle(.plain)
            Spacer()
            dock {
                Image(systemName: "phone.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .frame(height: 68)
    }

    /// Book Consultation + Guide me — the widget grid's own 193/153 columns
    private var optionsRow: some View {
        HStack(spacing: DS.gap) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                HStack(spacing: 12) {
                    consultIcon
                    Text("Book\nConsultation")
                        .font(DS.urbane(14, .semibold)).foregroundStyle(DS.onColor)
                        .multilineTextAlignment(.leading).lineSpacing(2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(width: 193, height: 64)
            }
            .buttonStyle(.plain)
            .glassEffect(.clear.tint(DS.red.opacity(0.15)).interactive(),
                         in: .rect(cornerRadius: DS.tile(64)))
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                state.summon = .guide
            } label: {
                (Text("Guide ").font(DS.urbane(16, .light))
                 + Text("me").font(DS.urbane(16, .semibold)))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topLeading) {
                        sparkle(9, .white.opacity(0.85)).offset(x: 24, y: 10)
                    }
                    .overlay(alignment: .bottomLeading) {
                        sparkle(6, .white.opacity(0.7)).offset(x: 37, y: -13)
                    }
                    .overlay(alignment: .topTrailing) {
                        sparkle(13, Color(red: 1, green: 197/255, blue: 46/255))
                            .offset(x: -32, y: 7)
                    }
                    .overlay(alignment: .trailing) { guideWand.offset(x: -12, y: 12) }
                    .frame(height: 64)
            }
            .buttonStyle(.plain)
            .glassEffect(.clear.tint(DS.red.opacity(0.15)).interactive(),
                         in: .rect(cornerRadius: DS.tile(64)))
        }
    }

    private func sparkle(_ size: CGFloat, _ color: Color) -> some View {
        DSSparkle().fill(color).frame(width: size, height: size)
    }

    private var guideWand: some View {
        VStack(spacing: 1.5) {
            Capsule().fill(Color(red: 1, green: 227/255, blue: 224/255))
                .frame(width: 5, height: 8)
            Capsule().fill(.white).frame(width: 5, height: 24)
        }
        .rotationEffect(.degrees(-40))
    }

    // MARK: signed-out plans sheet

    private let planCards: [(HomeState.Plan, Int)] =
        [(.diet, 99), (.lifestyle, 109), (.body, 149), (.kids, 99)]

    private var plansSheet: some View {
        VStack(spacing: 0) {
            // structure static, content in: the white sheet is instant; the
            // platter, divider and cards cascade onto it
            arrival(summerOffer, 2).padding(.horizontal, 20).padding(.top, 28)
            arrival(orDivider, 2.5).padding(.horizontal, 20).padding(.vertical, 28)
            VStack(spacing: 24) {
                ForEach(0..<planCards.count, id: \.self) { i in
                    // stay under index 5 — that's the bar's replay carve-out
                    arrival(planCard(planCards[i].0, planCards[i].1),
                            3 + Double(i) * 0.5)
                }
            }
            .padding(.horizontal, 20)
            Spacer(minLength: 110)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { r in
            sheetFrame = r   // the adaptive bar reads the white here too
        }
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38))
        .background(alignment: .bottom) {
            Color.white.frame(height: 600).offset(y: 600)
        }
    }

    private var summerOffer: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            HStack(spacing: 16) {
                DSSummerMark().frame(width: 46, height: 46)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Summer Offer").font(DS.urbane(17, .semibold)).foregroundStyle(DS.ink)
                    Text("عروض الصيــــف").font(DS.avenirWorld(15)).foregroundStyle(DS.ink)
                        .id("lo-summer-\(fontTick)")
                }
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 23/255, green: 23/255, blue: 27/255))
                    .frame(width: 44, height: 44)
                    .background(.white, in: Circle())
                    .shadow(color: Color(red: 56/255, green: 64/255, blue: 74/255).opacity(0.28),
                            radius: 9, y: 4)
            }
            .padding(.leading, 28).padding(.trailing, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 100)
            .background(.white, in: RoundedRectangle(cornerRadius: 30))
            .shadow(color: Color(red: 56/255, green: 64/255, blue: 74/255).opacity(0.16),
                    radius: 15, y: 7)
        }
        .buttonStyle(.plain)
    }

    /// straight ~95pt hairlines flanking the label (Figma — the curved
    /// flanks were an invention, retired on Rashid's call)
    private var orDivider: some View {
        HStack(spacing: 12) {
            Capsule().fill(Color(white: 0.86)).frame(width: 95, height: 1)
            Text("Or try a different plan").font(DS.proxima(12))
                .foregroundStyle(Color(red: 142/255, green: 142/255, blue: 147/255))
                .fixedSize()
            Capsule().fill(Color(white: 0.86)).frame(width: 95, height: 1)
        }
        .frame(maxWidth: .infinity)
    }

    /// DS component 4539-10208 VARIANT A, verbatim: the r32 "Liquid Glass
    /// Regular Medium" platter (hairline dbdbdb ring, 0 8 37 shadow) with
    /// 18pt circle badges, hairline chips, gradient price + the r28
    /// gradient plan pill (Rashid: the card is glass, the pill is glass)
    private func planCard(_ plan: HomeState.Plan, _ price: Int) -> some View {
        // both columns FIXED to the component's widths (173 / 137) — the card
        // can never outgrow its proposal, whatever the fonts measure
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 7.5) {
                planRow("1", "Breakfast")
                planRow("2", "Lunch & Dinner")
                planRow("5", "Salad & Soup")
                planRow("1", "Snack")
                Spacer(minLength: 4)
                HStack(spacing: 4) {
                    Text("~1200 kcal").font(DS.proxima(12)).fontWeight(.bold)
                    Text("|").font(DS.proxima(12)).foregroundStyle(Color(white: 0.75))
                    (Text("100g").font(DS.proxima(12)).fontWeight(.bold)
                     + Text(" macros").font(DS.proxima(12)))
                }
                .foregroundStyle(DS.ink)
                .lineLimit(1).fixedSize()
                .padding(.horizontal, 10).frame(height: 20)
                .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
            }
            .frame(width: 173, height: 122, alignment: .topLeading)
            .lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 0) {
                // CAP-TOP PRICE LAW (DS ruling 2026-09-14): satellites share
                // the numeral's baseline, then rise so their INK cap tops meet
                // the numeral's. Ink bounds, never UIFont.capHeight (Urbane's
                // OS/2 capHeight is 0.354em, half the real cap).
                let numTop = DSInkTop.top("UrbaneRounded-DemiBold", 30, "139")
                let kdTop = DSInkTop.top("ProximaNova-Bold", 15, "KD")
                let moTop = DSInkTop.top("ProximaNova-Regular", 15, "H")
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text("KD139").font(.custom("ProximaNova-Bold", size: 15))
                        .foregroundStyle(Color(red: 153/255, green: 153/255, blue: 153/255))
                        // ONE strike, the red diagonal (Rashid, via DS price v2):
                        // Figma Line 79, 1pt at 170.13° − 180 = −9.87°
                        .overlay {
                            Capsule().fill(DS.red).frame(height: 1)
                                .rotationEffect(.degrees(-9.87))
                                .padding(.horizontal, -1)
                        }
                        .offset(y: kdTop - numTop)
                        .padding(.trailing, 4)
                    Text("KD").font(.custom("ProximaNova-Bold", size: 15))
                        .foregroundStyle(plan.solidGradient)
                        .offset(y: kdTop - numTop)
                    Text(verbatim: "\(price)").font(DS.urbane(30, .semibold))
                        .foregroundStyle(plan.solidGradient)
                    Text("/mo").font(DS.proxima(15)).fontWeight(.medium)
                        .foregroundStyle(Color(red: 153/255, green: 153/255, blue: 153/255))
                        .offset(y: moTop - numTop)
                }
                .lineLimit(1).fixedSize()
                Spacer(minLength: 6)
                dealChip(plan)
                Spacer(minLength: 8)
                planPill(plan)
            }
            // FIXED column per the component (137): the fixedSize price/chip
            // overflow LEFT into the middle gap instead of widening the card —
            // an intrinsic-width column here once dragged the whole scroll
            // column to ~390pt and collapsed every page margin to 6
            .frame(width: 137, height: 122, alignment: .trailing)
        }
        // THE UNIFORM-PADDING LAW (Rashid): cards like these wear ONE padding
        // on all four sides — nothing may sit closer to one edge than another
        .padding(20)
        .frame(maxWidth: .infinity)
        // real material on white: the card IS glass, not a painted white box
        .glassEffect(.regular, in: .rect(cornerRadius: 32))
        .overlay(RoundedRectangle(cornerRadius: 32)
            .stroke(Color(red: 219/255, green: 219/255, blue: 219/255), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.08), radius: 18.5, y: 8)
        .onTapGesture { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    }

    private func planRow(_ n: String, _ label: String) -> some View {
        HStack(spacing: 6) {
            Text(n).font(DS.proxima(12)).fontWeight(.semibold)
                .foregroundStyle(DS.ink)
                .frame(width: 18, height: 18)
                .background(Color(red: 244/255, green: 244/255, blue: 244/255).opacity(0.6),
                            in: Circle())
            Text(label).font(DS.urbane(12)).foregroundStyle(DS.ink)
        }
        .frame(height: 18, alignment: .center)
    }

    /// hairline transparent chip, theme-GRADIENT text — the fire emoji keeps
    /// its own colors outside the gradient fill
    private func dealChip(_ plan: HomeState.Plan) -> some View {
        HStack(spacing: 3) {
            Text("خصم KD 40").font(DS.avenirWorld(12, .semibold))
                .foregroundStyle(plan.solidGradient)
            Text("🔥").font(.system(size: 11))
            Text("اشترك الحين").font(DS.avenirWorld(12, .semibold))
                .foregroundStyle(plan.solidGradient)
        }
        .environment(\.layoutDirection, .rightToLeft)
        .lineLimit(1).fixedSize()
        .padding(.horizontal, 10).frame(height: 24)
        .overlay(Capsule().stroke(Color.black.opacity(0.06), lineWidth: 1))
        .id("lo-deal-\(fontTick)")
    }

    /// glass pill over the plan's theme gradient — gradient clipped BEFORE
    /// the glass (the house bleed rule); hairline e3e3e3 ring per variant A
    private func planPill(_ plan: HomeState.Plan) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            // the title always gets its full room (Rashid: comfortable text,
            // never broken) — the pill overflows the fixed column leftward
            // into the middle gap rather than squeezing its label
            planPillLabel(plan)
                .lineLimit(1).fixedSize()
                .padding(.horizontal, 20).frame(height: 40)
                .background(plan.solidGradient)
                .clipShape(Capsule())
                .glassEffect(.clear, in: .capsule)
                .overlay(Capsule().stroke(Color(red: 227/255, green: 227/255, blue: 227/255),
                                          lineWidth: 1))
                .shadow(color: DS.ink.opacity(0.22), radius: 9, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func planPillLabel(_ plan: HomeState.Plan) -> some View {
        Group {
            switch plan {
            case .body:
                Text("BODY").font(DS.urbane(16, .semibold)).foregroundColor(.white)
                + Text("Building").font(DS.urbane(16, .semibold))
                    .foregroundColor(Color(red: 242/255, green: 84/255, blue: 61/255))
            case .kids:
                Text("Kids").font(DS.urbane(16, .semibold)).foregroundColor(.white)
            default:
                let (a, b) = plan.words
                Text(a).font(DS.urbane(16, .light)).foregroundColor(.white.opacity(0.6))
                + Text(b).font(DS.urbane(16, .semibold)).foregroundColor(.white)
            }
        }
        .shadow(color: .black.opacity(0.1), radius: 4, y: 1)
    }

    // MARK: meal sheet

    private var mealSheet: some View {
        VStack(alignment: .leading, spacing: 20) {
            arrival(sheetHeader, 2).padding(.top, 30).padding(.horizontal, 24)
            arrival(stripCarousel, 3)
            Spacer(minLength: 140)
        }
        .frame(maxWidth: .infinity, minHeight: 520, alignment: .top)
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { r in
            sheetFrame = r   // where the white begins; red page above it
        }
        .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 38, topTrailingRadius: 38))
        // bottom-overscroll rubber band must show white, never the red page
        .background(alignment: .bottom) {
            Color.white.frame(height: 600).offset(y: 600)
        }
    }

    /// the meal carousel, extracted so the entrance can stagger it as
    /// CONTENT while the sheet structure stays static
    private var stripCarousel: some View {
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
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { r in
                stripFrame = r   // the dark photo band, tracked live
            }
            .onAppear {
                stripProxy.scrollTo("day1", anchor: .leading)
                // seen once in the sim: the first scrollTo can race layout
                // and strand the strip on a far day — re-fire next runloop
                DispatchQueue.main.async {
                    stripProxy.scrollTo("day1", anchor: .leading)
                }
            }
        }
    }

    private let stripMeals = [
        DSStripMeal(img: "meal1.jpg", name: "Chicken Machbous",
                    kcal: 245, p: 30, c: 22, f: 12, rating: 4.3, hot: true,
                    ing: ["Chicken thigh", "Basmati rice", "Machbous spices",
                          "Crispy onions", "Tomato sauce", "Fresh coriander"]),
        DSStripMeal(img: "meal2.jpg", name: "Egg Sandwich",
                    kcal: 343, p: 18, c: 30, f: 15, rating: 4.3, hot: false,
                    ing: ["Free-range eggs", "Brioche bun", "Cheddar",
                          "Rocca leaves", "Light mayo"]),
        DSStripMeal(img: "meal3.jpg", name: "Biryani with tomato sauce and Veggies",
                    kcal: 554, p: 21, c: 74, f: 18, rating: 4.3, hot: true,
                    ing: ["Basmati rice", "Biryani masala", "Seasonal veggie mix",
                          "Tomato sauce", "Fried onions", "Mint yogurt"]),
    ]

    private func dayGroup(_ i: Int) -> some View {
        HStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { k in
                // rotate per day; Today (i=1) keeps the original order
                let m = stripMeals[(k + i + 2) % 3]
                mealCard(m)
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
                if reduceMotion { state.stripDay = i }
                else { withAnimation(.spring(duration: 0.35)) { state.stripDay = i } }
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
            // dynamic-bar mode: the bar's own kcal module IS the calorie
            // surface — the strip pill would be a duplicate (Rashid)
            if !state.tabBarDynamic {
            Button { withAnimation(.spring(duration: 0.4, bounce: 0.12)) { state.macrosOpen.toggle() } } label: {
                HStack(spacing: 3) {
                    // verbatim: interpolated Ints localize ("1,200") — web shows "1200"
                    Text(verbatim: "\(info.kcal)").font(DS.urbane(15, .semibold)).foregroundStyle(DS.ink)
                        .monospacedDigit()
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
        }
        .frame(height: 48)
    }

    private func macro(_ v: Int, _ u: String) -> some View {
        HStack(spacing: 2) {
            Text(verbatim: "\(v)").font(DS.urbane(12)).foregroundStyle(DS.ink)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(u).font(DS.proxima(8)).foregroundStyle(DS.ink)
        }
    }

    private func mealCard(_ m: DSStripMeal) -> some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: DS.assets + m.img)) { $0.resizable().scaledToFill() }
                placeholder: { Color(white: 0.92) }
                .frame(width: 166.9, height: 236).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.41), .black.opacity(0.81)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 139.6)
            VStack(alignment: .leading, spacing: 6) {
                Text(m.name).font(DS.urbane(15.4, .semibold)).foregroundStyle(DS.onColor)
                    .lineLimit(2).multilineTextAlignment(.leading)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(m.kcal)").font(DS.urbane(16.5, .semibold))
                    Text("Kcal").font(DS.proxima(11))
                }
                .foregroundStyle(DS.onColor)
                .shadow(color: .black.opacity(0.49), radius: 2.1, y: 1)
            }
            .padding(EdgeInsets(top: 0, leading: 12.6, bottom: 16.8, trailing: 12.6))
        }
        .frame(width: 166.9, height: 236)
        .clipShape(RoundedRectangle(cornerRadius: 25.2))
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            state.summon = .meal(m)
        }
    }

    // MARK: native lab sheet (long-press)

    private var labSheet: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Picker("Account", selection: $state.loggedOut) {
                        Text("Logged in").tag(false)
                        Text("Logged out").tag(true)
                    }
                    .pickerStyle(.segmented)
                }
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
                    Toggle("Dynamic tab bar", isOn: $state.tabBarDynamic)
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
                if state.calendarOpen {
                    // the calendar's own lab controls, reached from this ONE
                    // menu — its page binds no gesture under the pilot
                    Section {
                        Button("Meal selection controls…") {
                            state.labOpen = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                FlowPreloader.shared.entry("meal-select").web
                                    .evaluateJavaScript("window.DSLabMenu && DSLabMenu.open()",
                                                        completionHandler: nil)
                            }
                        }
                    }
                }
                if let onClose {
                    Section { Button("Exit prototype", role: .destructive) { onClose() } }
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

// MARK: - Signed-out plans: theme colors + small shapes

@available(iOS 26.0, *)
extension HomeState.Plan {
    /// the big price figure wears the plan's identity color
    var priceColor: Color {
        switch self {
        case .diet: return Color(red: 108/255, green: 58/255, blue: 205/255)
        case .lifestyle: return DS.red
        case .body: return Color(red: 29/255, green: 29/255, blue: 58/255)
        case .kids: return Color(red: 1, green: 63/255, blue: 85/255)
        }
    }
    /// DS component 4539-10208 variant A gradients (~116deg): TheDiet +
    /// LifeStyle are TOKEN-EXACT from get_design_context; Body + Kids are
    /// traced from their instances — swap when their tokens are readable
    var solidGradient: LinearGradient {
        func g(_ c1: Color, _ c2: Color) -> LinearGradient {
            LinearGradient(colors: [c1, c2], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        switch self {
        case .diet:
            return g(Color(red: 130/255, green: 69/255, blue: 156/255),
                     Color(red: 85/255, green: 37/255, blue: 181/255))
        case .lifestyle:
            return g(Color(red: 1, green: 150/255, blue: 62/255),
                     Color(red: 1, green: 5/255, blue: 5/255))
        case .body:
            return g(Color(red: 42/255, green: 42/255, blue: 82/255),
                     Color(red: 21/255, green: 21/255, blue: 46/255))
        case .kids:
            return g(Color(red: 1, green: 106/255, blue: 84/255),
                     Color(red: 1, green: 50/255, blue: 135/255))
        }
    }
}

/// Four-point sparkle (the Guide me stars — web's 16-grid path)
@available(iOS 26.0, *)
private struct DSSparkle: Shape {
    func path(in r: CGRect) -> Path {
        let w = r.width, h = r.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: w * 0.6125, y: h * 0.3875))
        p.addLine(to: CGPoint(x: w, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.6125, y: h * 0.6125))
        p.addLine(to: CGPoint(x: w * 0.5, y: h))
        p.addLine(to: CGPoint(x: w * 0.3875, y: h * 0.6125))
        p.addLine(to: CGPoint(x: 0, y: h * 0.5))
        p.addLine(to: CGPoint(x: w * 0.3875, y: h * 0.3875))
        p.closeSubpath()
        return p
    }
}

/// The Summer Offer mark — the exported asset (checkout/assets/summer-logo.svg,
/// 48-grid): a dark body with the % counters and slash knocked out in white
@available(iOS 26.0, *)
private struct DSSummerMark: View {
    var body: some View {
        ZStack {
            Mark().fill(Color(red: 26/255, green: 25/255, blue: 25/255))
            Knockouts().fill(.white)
        }
    }

    private struct Mark: Shape {
        func path(in rect: CGRect) -> Path {
            let s = rect.width / 48
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            var p = Path()
            p.move(to: pt(40.1299, 4))
            p.addCurve(to: pt(43.6094, 9.9746), control1: pt(43.196, 4), control2: pt(45.1228, 7.308))
            p.addLine(to: pt(34.8916, 25.333))
            p.addCurve(to: pt(37.0957, 25), control1: pt(35.6388, 25.134), control2: pt(36.4166, 25))
            p.addCurve(to: pt(46, 33.9473), control1: pt(42.0134, 25.0003), control2: pt(45.9999, 29.006))
            p.addCurve(to: pt(41, 42), control1: pt(46, 37.3641), control2: pt(44, 40.5))
            p.addLine(to: pt(37, 44))
            p.addCurve(to: pt(33, 45), control1: pt(35.8808, 44.5096), control2: pt(34.3087, 45))
            p.addCurve(to: pt(25.5908, 41.1113), control1: pt(29.9507, 45), control2: pt(27.2236, 43.4595))
            p.addCurve(to: pt(24.9111, 41.5449), control1: pt(25.3799, 41.2769), control2: pt(25.1533, 41.4238))
            p.addLine(to: pt(18.8447, 44.5781))
            p.addCurve(to: pt(17.0557, 45), control1: pt(18.2893, 44.8558), control2: pt(17.6766, 45))
            p.addLine(to: pt(8.0322, 45))
            p.addCurve(to: pt(4.5938, 38.9561), control1: pt(4.9303, 45), control2: pt(3.0087, 41.6223))
            p.addLine(to: pt(13.8027, 23.4668))
            p.addCurve(to: pt(11, 24), control1: pt(12.896, 23.7711), control2: pt(11.8879, 24))
            p.addCurve(to: pt(2, 15.0527), control1: pt(6.0821, 24), control2: pt(2.0001, 19.9942))
            p.addCurve(to: pt(6.7178, 7.1553), control1: pt(2, 11.6322), control2: pt(3.9106, 8.6606))
            p.addLine(to: pt(11, 5))
            p.addCurve(to: pt(11.6133, 4.7441), control1: pt(11.1919, 4.9128), control2: pt(11.3981, 4.828))
            p.addCurve(to: pt(14.7246, 4.0068), control1: pt(12.6059, 4.304), control2: pt(13.6625, 4.0454))
            p.addCurve(to: pt(15, 4), control1: pt(14.8175, 4.0023), control2: pt(14.9094, 4))
            p.addCurve(to: pt(15.6846, 4.0283), control1: pt(15.2304, 4), control2: pt(15.4585, 4.0113))
            p.addCurve(to: pt(15.916, 4.0459), control1: pt(15.7619, 4.0342), control2: pt(15.8392, 4.038))
            p.addCurve(to: pt(22.1016, 7.4736), control1: pt(18.4267, 4.2997), control2: pt(20.6311, 5.5867))
            p.addCurve(to: pt(22.7812, 8.4756), control1: pt(22.3503, 7.791), control2: pt(22.5764, 8.1264))
            p.addCurve(to: pt(24.0498, 7.4756), control1: pt(23.1305, 8.0613), control2: pt(23.5611, 7.7199))
            p.addLine(to: pt(30.1553, 4.4219))
            p.addCurve(to: pt(31.9443, 4), control1: pt(30.7107, 4.1442), control2: pt(31.3234, 4))
            p.addLine(to: pt(40.1299, 4))
            p.closeSubpath()
            return p
        }
    }

    private struct Knockouts: Shape {
        func path(in rect: CGRect) -> Path {
            let s = rect.width / 48
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            var p = Path()
            p.move(to: pt(37, 39))
            p.addCurve(to: pt(42, 34), control1: pt(39.7614, 39), control2: pt(42, 36.7614))
            p.addCurve(to: pt(37, 29), control1: pt(42, 31.2386), control2: pt(39.7614, 29))
            p.addCurve(to: pt(32, 34), control1: pt(34.2386, 29), control2: pt(32, 31.2386))
            p.addCurve(to: pt(37, 39), control1: pt(32, 36.7614), control2: pt(34.2386, 39))
            p.closeSubpath()
            p.move(to: pt(15, 18))
            p.addCurve(to: pt(20, 13), control1: pt(17.7614, 18), control2: pt(20, 15.7614))
            p.addCurve(to: pt(15, 8), control1: pt(20, 10.2386), control2: pt(17.7614, 8))
            p.addCurve(to: pt(10, 13), control1: pt(12.5742, 8), control2: pt(10, 10.3712))
            p.addCurve(to: pt(15, 18), control1: pt(10, 15.7614), control2: pt(12.2386, 18))
            p.closeSubpath()
            p.move(to: pt(22.6934, 38))
            p.addLine(to: pt(40.0625, 8))
            p.addLine(to: pt(33.3066, 8))
            p.addLine(to: pt(15.9375, 38))
            p.addLine(to: pt(22.6934, 38))
            p.closeSubpath()
            return p
        }
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
    /// WIDTH RULE v3 (Rashid): a bar of three plain links is the COMPACT
    /// 256, centered — hosts pass wider only while the dynamic module's
    /// full footprint is in play
    var width: CGFloat = 256
    /// signed-out home: the middle tab browses meals, not the calendar —
    /// SF placeholder for now (Shell to trace the Figma fork-knife)
    var forkMiddle = false
    /// adaptive bar: the host flips this subtree's colorScheme from the
    /// content behind the bar (Apple's way) — glyphs and pill follow
    @Environment(\.colorScheme) private var scheme

    private var resting: Color {
        scheme == .dark ? .white.opacity(0.92) : Color(white: 0.12).opacity(0.85)
    }

    // MARK: - Hold-and-drag lens (App Store / Music, iOS 26)
    //
    // Kept identical to GlassTabBar in DietStationLabApp.swift — Rashid asked
    // for this "in the prototypes at least", and two bars behaving differently
    // is worse than either behaviour. Read that one for the full reasoning;
    // the three things Apple does and the first attempt did not were: the
    // lens is GLASS (not a white capsule), it EXPANDS and MAGNIFIES what sits
    // under it, and it FOLLOWS THE FINGER with a rubber-band rather than
    // snapping tab to tab.
    //
    // ONE GESTURE OWNS THE BAR. The first version kept per-tab taps AND a
    // bar-level gesture; they fought and the taps lost — "when I tap on
    // calendar it doesn't take me there unless I do the new gesture."
    // Released without engaging = a tap on the tab under the finger; held or
    // travelled = the lens.
    //
    // NOTE FOR THE FOLD: this is canon, mirrored from the Home lane's
    // gh-pages copy. If that copy doesn't carry this, a fold reverts it.
    @State private var frames: [DSTabId: CGRect] = [:]
    @State private var dragging = false
    @State private var hover: DSTabId?
    @State private var fingerX: CGFloat = 0
    @State private var startTab: DSTabId?
    @State private var travelled = false
    @State private var holdTask: DispatchWorkItem?

    private var lensTab: DSTabId { dragging ? (hover ?? selected) : selected }

    private func nearest(_ x: CGFloat) -> DSTabId? {
        frames.min { abs($0.value.midX - x) < abs($1.value.midX - x) }?.key
    }

    private func engage() {
        guard !dragging else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) { dragging = true }
    }

    private func move(to x: CGFloat) {
        fingerX = x
        guard let target = nearest(x), target != hover else { return }
        travelled = true
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { hover = target }
    }

    private func commit() {
        holdTask?.cancel(); holdTask = nil
        let landed = hover ?? selected
        let wasDragging = dragging
        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { dragging = false }
        // a hold that never travelled is the long-press entry (the wordmark
        // pilot), which has no other affordance inside a flow
        if wasDragging, !travelled, landed == startTab, let lp = onLongPress {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            lp(landed)
            hover = nil
            return
        }
        if landed != selected || !wasDragging {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect(landed)
        }
        hover = nil
    }

    var body: some View {
        // NO GlassEffectContainer — see GlassTabBar: it composites the
        // glass inside it into one pass and lifted the lens above the icons,
        // refracting them. It is for merging sibling glass, not for stacking.
        HStack(spacing: 0) {
                item(.home) { sel in
                    DSLogoMark()
                        .fill(sel ? DS.red : resting)
                        .frame(width: 26, height: 20)
                }
                item(.calendar) { sel in
                    if forkMiddle {
                        DSForkKnifeIcon()
                            .fill(sel ? DS.red : resting)
                            .frame(width: 23, height: 23)
                    } else {
                        DSTabCalendarIcon()
                            .fill(sel ? DS.red : resting)
                            .frame(width: 24, height: 24)
                    }
                }
                item(.person) { sel in
                    DSTabPersonIcon()
                        .fill(sel ? DS.red : resting)
                        .frame(width: 24, height: 24)
                }
        }
        .padding(4)
        .background { lens }
        .frame(width: width, height: 58)
        .glassEffect(.regular, in: .capsule)
        .contentShape(Capsule())
        .coordinateSpace(.named("dsbar"))
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .named("dsbar"))
                .onChanged { v in
                    if startTab == nil {
                        startTab = nearest(v.startLocation.x) ?? selected
                        hover = startTab
                        fingerX = v.startLocation.x
                        travelled = false
                        let work = DispatchWorkItem { engage() }
                        holdTask = work
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: work)
                    }
                    if !dragging, abs(v.translation.width) > 8 {
                        holdTask?.cancel(); engage()
                    }
                    if dragging { move(to: v.location.x) }
                }
                .onEnded { _ in commit(); startTab = nil }
        )
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: selected)
    }

    /// The lens — glass while held, the bar's own pill at rest, rubber-banded
    /// toward the finger and magnifying what it sits over.
    @ViewBuilder private var lens: some View {
        if let r = frames[lensTab] {
            let lag = dragging ? (fingerX - r.midX) : 0
            let pull = max(-26, min(26, lag))
            let stretch = min(abs(pull) / 26 * 0.16, 0.16)
            // ONE LAYER, ALWAYS — see GlassTabBar for the full note. A white
            // fill UNDER a .glassEffect is two shapes with two edges, and the
            // shadow was a third; this is Rashid's "another layer of glass
            // under it." One element: plain fill at rest, Apple's material
            // while held, and no shadow while held because glass casts its own.
            Group {
                if dragging {
                    // .clear, NOT .regular: this lens sits ON the bar's own
                    // regular glass, and regular-on-regular stacks the frost —
                    // two ground-glass surfaces with two edges, which is the
                    // second layer Rashid saw even after the white fill went.
                    // A glass element over glass is clear and takes its
                    // brightness from a TINT, not from a shape beneath it
                    // (A GLASS PILL TINTS AGAINST ITS GROUND).
                    Color.clear.glassEffect(
                        .clear.tint(.white.opacity(0.22)).interactive(),
                        in: Capsule())
                } else {
                    Capsule().fill(.white.opacity(scheme == .dark ? 0.24 : 0.85))
                }
            }
            .frame(width: r.width + (dragging ? 10 : 0),
                   height: r.height + (dragging ? 8 : 0))
            .scaleEffect(x: 1 + stretch, y: dragging ? 1 - stretch * 0.4 : 1,
                         anchor: pull > 0 ? .leading : .trailing)
            .shadow(color: .black.opacity(dragging ? 0 : 0.1), radius: 6, y: 2)
            .position(x: r.midX + pull * 0.55, y: r.midY)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: lensTab)
            .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.7),
                       value: fingerX)
        }
    }

    private func item<C: View>(_ tab: DSTabId,
                               @ViewBuilder _ content: @escaping (Bool) -> C) -> some View {
        let lit = lensTab == tab
        let magnified = dragging && lit
        return content(lit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // THE MAGNIFIER: what the lens covers is enlarged and the rest
            // recedes. A lens that only moves has no magnifier read at all.
            .scaleEffect(magnified ? 1.12 : 1)
            .opacity(dragging && !lit ? 0.5 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: magnified)
            .animation(.easeOut(duration: 0.16), value: dragging)
            // the pill is drawn ONCE, by `lens`, from these rects — a
            // per-item background cannot slide between items
            .background {
                GeometryReader { g in
                    Color.clear.preference(key: DSTabFrames.self,
                                           value: [tab: g.frame(in: .named("dsbar"))])
                }
            }
            .onPreferenceChange(DSTabFrames.self) { frames.merge($0) { _, new in new } }
    }
}

/// Each tab's rect in the bar's own space — the lens is positioned from
/// these so one pill can slide between items.
private struct DSTabFrames: PreferenceKey {
    static let defaultValue: [DSTabId: CGRect] = [:]
    static func reduce(value: inout [DSTabId: CGRect], nextValue: () -> [DSTabId: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Self-stated wrapper for hosts without their own selection state (e.g.
/// the calendar overlay): the pill animates locally, taps bubble out.
@available(iOS 26.0, *)
struct DSTabBarHost: View {
    var initial: DSTabId
    var onSelect: (DSTabId) -> Void
    var onLongPress: ((DSTabId) -> Void)? = nil   // passthrough to DSTabBar
    @State private var sel: DSTabId = .home

    var body: some View {
        DSTabBar(selected: sel, onSelect: { tab in
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) { sel = tab }
            onSelect(tab)
        }, onLongPress: onLongPress)
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
    final class Relay: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var onClose: (() -> Void)?
        /// A warm view whose WebContent process iOS killed in the background
        /// stays dead forever unless we notice; the preloader reloads it.
        var onTerminate: (() -> Void)?
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            NSLog("DSRECOVER(pilot) warm flow WebContent terminated, reloading")
            clearOwnLayers()
            onTerminate?()
        }
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            clearOwnLayers()
        }
        /// a view that navigates or dies takes its layer ids with it
        func clearOwnLayers() {
            let host = role == .host
            let target: OverlayChrome? = host ? sheet?.owner : chrome
            DispatchQueue.main.async { target?.clearLayers(host: host) }
        }
        let chrome = OverlayChrome()

        /// Which side of a SHEET HOST this relay sits on
        /// (system/composition.html#spec-sheethost). `.calendar` may open a
        /// host and sends `ds-down`; `.host` is the selector's own web view and
        /// sends `ds-up`, `ds-ready`, `sheet-close`, and the `complete` post
        /// that releases the entry. Everything else is `.normal` and ignores
        /// the sheet vocabulary entirely.
        enum Role { case normal, calendar, host }
        var role: Role = .normal
        /// set on the HOST relay, pointing back at the host it lives in
        weak var sheet: SheetHost?
        #if DEBUG
        var capsProbed = false
        var subCapsProbed = false
        #endif

        /// generators are built FRESH per event: long-lived unprepared ones
        /// go silent on device when iOS parks the haptic engine (suspected
        /// cause of the build-27/28 "haptics are gone" report) — a fresh
        /// instance always spins the engine up
        private static let impactStyle: [String: UIImpactFeedbackGenerator.FeedbackStyle] = [
            "light": .light, "medium": .medium, "heavy": .heavy,
            "soft": .soft, "rigid": .rigid,
        ]

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
            if handleSheet(t, body, message) { return }
            #if DEBUG
            // ONE-SHOT GUARD PROOF for the sheet host's caps (Hub's finding):
            // DSNativeCaps must exist in this view's MAIN frame and NOT in any
            // subframe, or an embed=1 flow iframe would read itself as hosted.
            // Evaluated in the frame that actually sent this message.
            if role == .calendar, !capsProbed {
                capsProbed = true
                let js = "JSON.stringify({ top: window.parent === window, caps: window.DSNativeCaps || null })"
                chrome.webView?.evaluateJavaScript(js, in: nil, in: .page) { r in
                    NSLog("DSCAPS(pilot) main-frame %@", String(describing: (try? r.get()) ?? "err"))
                }
                if !message.frameInfo.isMainFrame {
                    chrome.webView?.evaluateJavaScript(js, in: message.frameInfo, in: .page) { r in
                        NSLog("DSCAPS(pilot) sub-frame %@", String(describing: (try? r.get()) ?? "err"))
                    }
                }
            }
            if role == .calendar, !message.frameInfo.isMainFrame, !subCapsProbed {
                subCapsProbed = true
                let js = "JSON.stringify({ top: window.parent === window, caps: window.DSNativeCaps || null })"
                chrome.webView?.evaluateJavaScript(js, in: message.frameInfo, in: .page) { r in
                    NSLog("DSCAPS(pilot) sub-frame %@", String(describing: (try? r.get()) ?? "err"))
                }
            }
            #endif
            #if DEBUG
            // Pages post {t:'dsdebug'} to put their own instrumentation into
            // the same log stream as ours, so one `log stream` run shows both
            // sides of a handshake in order instead of two clocks to reconcile.
            if t == "dsdebug" {
                // SHAPE-AGNOSTIC, and tagged (pilot) — mirrors the hub's
                // handler. This one used to demand tag/trusted/ts, so a
                // beacon posting any other keys logged "tag=? trusted=? ts=?"
                // and its payload went in the bin: the line existed, the
                // information didn't. Every page-side instrument the Calendar
                // lane built today — the window `error` beacon, the close
                // BAIL reason, the caps receipt — was therefore blind on the
                // PILOT, which is the surface Rashid actually uses. Same
                // two-relay trap as the tile's rows, third time today:
                // WHATEVER ONE RELAY LEARNS, TEACH THE OTHER IN THE SAME EDIT.
                let fields = body.filter { $0.key != "t" }
                    .sorted { $0.key < $1.key }
                    .map { "\($0.key)=\(String(describing: $0.value))" }
                    .joined(separator: " ")
                NSLog("DSDEBUG(pilot) %@", fields)
                return
            }
            #endif
            if t == "glasschrome" {
                // same parse + reply as the main webview's Coordinator —
                // empty els + no bar means clear everything for this overlay
                var els: [GlassChromeEl] = []
                for e in body["els"] as? [[String: Any]] ?? [] {
                    guard let id = e["id"] as? String else { continue }
                    func n(_ k: String) -> CGFloat {
                        CGFloat((e[k] as? NSNumber)?.doubleValue ?? 0)
                    }
                    var fromRect: CGRect?
                    if let f = e["from"] as? [String: Any] {
                        func fv(_ k: String) -> CGFloat {
                            CGFloat((f[k] as? NSNumber)?.doubleValue ?? 0)
                        }
                        fromRect = CGRect(x: fv("x"), y: fv("y"),
                                          width: fv("w"), height: fv("h"))
                    }
                    els.append(GlassChromeEl(id: id, x: n("x"), y: n("y"),
                                             w: n("w"), h: n("h"), r: n("r"),
                                             on: (e["on"] as? Bool) ?? false,
                                             mode: e["mode"] as? String,
                                             dates: e["dates"] as? [String],
                                             center: (e["center"] as? NSNumber)?.doubleValue,
                                             monthLabel: e["monthLabel"] as? String,
                                             dayName: e["dayName"] as? String,
                                             dayNames: e["dayNames"] as? [String],
                                             statuses: e["statuses"] as? [String],
                                             // THE TILE'S ROWS. Missing here
                                             // while present in LabWebView's
                                             // parse is why build 48 drew the
                                             // weekday and nothing else: on
                                             // THIS surface `date` and
                                             // `status` arrived and were
                                             // dropped, so the numeral and
                                             // chip rendered empty strings.
                                             // And this relay ANNOUNCES
                                             // tileRows, so it claimed a
                                             // capability its own parse could
                                             // not deliver — the exact rule
                                             // quoted a screen above about
                                             // never confirming from a path
                                             // whose renderer doesn't share
                                             // the confirm. Two parses of one
                                             // protocol: whatever one learns,
                                             // teach the other in the same
                                             // edit.
                                             slots: (e["slots"] as? NSNumber)?.intValue,
                                             date: e["date"] as? String,
                                             status: e["status"] as? String,
                                             badge: e["badge"] as? String,
                                             from: fromRect))
                }
                let bar = body["bar"] as? String
                let flow = body["flow"] as? String
                let surface = body["surface"] as? String
                let mode = body["mode"] as? String
                // instant:true — MATCH A FLAG, NOT A CURVE
                // (system/platform.html): whichever side owns a motion must
                // expose a synchronisation primitive; the far side never
                // times against it. THIS IS THAT PRIMITIVE — don't remove or
                // narrow it without reading the rule. Applies the post with
                // NO animation, so an omitted twin is torn down on THIS
                // frame instead of fading out on the 0.42 spring. Lets a
                // page own its own exit in CSS and guarantee exactly one
                // glass on screen per frame
                // (C&M: a capsule is a backdrop-filter, so any frame where
                // it overlaps the returned web label reads as double glass).
                // Scope is the WHOLE post — send it on a release/deflate
                // post, not one that also wants other twins to spring.
                let instant = body["instant"] as? Bool ?? false
                let frame = message.frameInfo
                DispatchQueue.main.async {
                    self.chrome.frame = frame
                    // chrome v2: twins persist and TRAVEL — a re-report after
                    // a dock flip springs the same glass to its new geometry.
                    // Seam killer (scrub phase 3): a re-arm whose rects are ALL
                    // unchanged is a pure MODEL swap (fresh dates/center at an
                    // integer crossing) — springing it would tween the ladder
                    // offset jump against the re-anchored content and wobble
                    // ...and the same transaction kills the REST-REPORT
                    // DRIFT: after a tracked gesture the rest post re-anchors
                    // the twin to the canonical top line, and springing a
                    // sub-10pt correction reads as a second motion once the
                    // finger has stopped (C&M measured ~9pt over ~0.5s — the
                    // 0.42s spring — and Rashid calls that "multistep").
                    // Anything within SNAP_EPS applies instantly; real
                    // re-anchoring (dock flips, sheet transitions) still springs.
                    let SNAP_EPS: CGFloat = 12
                    let sameRects = !els.isEmpty &&
                        els.count == self.chrome.els.count &&
                        els.allSatisfy { new in
                            self.chrome.els.first(where: { $0.id == new.id })
                                .map { abs($0.x - new.x) <= SNAP_EPS &&
                                       abs($0.y - new.y) <= SNAP_EPS &&
                                       abs($0.w - new.w) <= SNAP_EPS &&
                                       abs($0.h - new.h) <= SNAP_EPS &&
                                       // see LabWebView: a slot-count change
                                       // is not geometry, and treating it as
                                       // "unchanged" suppressed the collapse
                                       // animation
                                       $0.slots == new.slots } ?? false
                        }
                    let apply = {
                        self.chrome.els = els
                        self.chrome.bar = bar
                        self.chrome.flow = flow
                        self.chrome.surface = surface
                        self.chrome.mode = mode
                    }
                    if instant || sameRects {
                        var tx = Transaction()
                        tx.disablesAnimations = true
                        withTransaction(tx, apply)
                    } else {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.8),
                                      apply)
                    }
                    if let wv = self.chrome.webView {  // empty posts confirm too (caps-gated pages)
                        let ids = els.map { "'\($0.id)'" }.joined(separator: ",")
                        // CAPABILITY ANNOUNCEMENT, not an assumption. The
                        // web deploys continuously; this renderer ships
                        // discretely — so a page must never presume what the
                        // shell can do. scrubMotion says "this renderer drives
                        // the capsule from el.from with its own spring", which
                        // is what lets the page stop morphing its pill and
                        // send a DESTINATION instead of a path. A build
                        // without it keeps the web morph and still works.
                        #if DEBUG
                        // THE PILOT RELAY HAD NO ARMED LOG AT ALL — which is why
                        // three rounds of "verified" covered only the hub: the
                        // surface Rashid actually uses was the one with no
                        // instrument on it. Same names as the hub's, tagged
                        // (pilot) so a log line says WHICH surface it is from.
                        NSLog("DSSLOTS(pilot) %@", els.map {
                    "\($0.id):slots=\($0.slots.map(String.init) ?? "-")" +
                    ":dates=\($0.dates?.count ?? -1)" +
                    ":center=\($0.center.map { String(format: "%.2f", $0) } ?? "-")" +
                    ":r=\(String(format: "%.1f", $0.r))"
                }.joined(separator: " "))
                NSLog("DSCHROME(pilot) role=%@ mainFrame=%d armed=[%@]",
                      self.role == .host ? "host" : (self.role == .calendar ? "calendar" : "normal"),
                      message.frameInfo.isMainFrame ? 1 : 0,
                              els.map { $0.id }.joined(separator: ","))
                        #endif
                        wv.evaluateJavaScript(
                            // caps.tileRows: the pilot's overlays render
                            // through the SAME GlassChromeLayer, so this relay
                            // can draw the rows too and must say so — a
                            // capability announced by one relay and not the
                            // other would hand the tile over on one surface
                            // and orphan the number on the other.
                            "window.DSNativeChrome && DSNativeChrome([\(ids)], { scrubMotion: true, tileRows: 2, dateWidget: 1, navGlyphs: 1, navPill: 1, couponsFab: 1 })",
                            in: frame, in: .page, completionHandler: nil)
                    }
                }
                return
            }
            if t == "chrometrack" {
                // continuous follow (Rashid: buttons must ride the drag, not
                // settle-then-jump): the page streams verbatim rects per frame
                // while the sheet moves; positions apply with NO animation so
                // the twins are glued to the surface, and the rest report's
                // spring lands the final anchor
                var pos: [String: CGPoint] = [:]
                var dims: [String: (w: CGFloat?, h: CGFloat?)] = [:]
                var ctr: [String: Double] = [:]
                var rad: [String: CGFloat] = [:]
                var slotc: [String: Int] = [:]
                for e in body["els"] as? [[String: Any]] ?? [] {
                    guard let id = e["id"] as? String else { continue }
                    func n(_ k: String) -> CGFloat {
                        CGFloat((e[k] as? NSNumber)?.doubleValue ?? 0)
                    }
                    pos[id] = CGPoint(x: n("x"), y: n("y"))
                    // scrub morphs (label -> pill -> full-width): track may
                    // carry w/h; absent keys keep the el's armed size
                    dims[id] = ((e["w"] as? NSNumber).map { CGFloat($0.doubleValue) },
                                (e["h"] as? NSNumber).map { CGFloat($0.doubleValue) })
                    if let c = e["center"] as? NSNumber { ctr[id] = c.doubleValue }
                    // ·195 sends `r` on track frames — the radius morphs with
                    // the pill (tile 16 -> scrub 26), so follow it live
                    if let rv = e["r"] as? NSNumber { rad[id] = CGFloat(rv.doubleValue) }
                    if let sv = e["slots"] as? NSNumber { slotc[id] = sv.intValue }
                }
                #if DEBUG
                NSLog("DSTRACK %@", pos.map { "\($0.key)=\(Int($0.value.y))" }
                    .sorted().joined(separator: " "))
                #endif
                DispatchQueue.main.async {
                    guard !self.chrome.els.isEmpty else { return }
                    var tx = Transaction()
                    tx.disablesAnimations = true
                    withTransaction(tx) {
                        // verbatim while tracking — normalization would pin
                        // the twin to the top line and break the follow
                        self.chrome.mode = "sheet"
                        self.chrome.els = self.chrome.els.map { el in
                            guard let p = pos[el.id] else { return el }
                            let d = dims[el.id]
                            // A COPY, not a second memberwise init. The
                            // rebuild law's other half: this was the site
                            // where a newly added field silently dropped on
                            // the first tracked frame. Copy-and-mutate means
                            // a field the struct has is a field a track frame
                            // keeps, with nothing to remember. (Mirror of
                            // LabWebView's handler — change both.)
                            var moved = el
                            moved.x = p.x
                            moved.y = p.y
                            if let w = d?.w { moved.w = w }
                            if let h = d?.h { moved.h = h }
                            if let r = rad[el.id] { moved.r = r }
                            if let c = ctr[el.id] { moved.center = c }
                            if let s = slotc[el.id] { moved.slots = s }
                            return moved
                        }
                    }
                }
                return
            }
            if t == "selector" {
                // chrome layers: the calendar posts this from its selector
                // open/close choke points — the pilot's persistent bar
                // yields the screen while the selector sheet owns it
                let up = (body["up"] as? Bool) ?? false
                #if DEBUG
                // the edge the sheet-host watchdog will be measured FROM: the
                // calendar opening the selector. Paired with the selector's
                // first DSSLOTS/DSCHROME line, the gap between them is the
                // page-load latency the watchdog has to sit above.
                NSLog("DSSELECTOR(pilot) up=%d", up ? 1 : 0)
                #endif
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        self.chrome.selectorUp = up
                        self.chrome.setLayer("selector", up)   // legacy alias
                    }
                }
                return
            }
            if t == "layer" {
                guard message.frameInfo.isMainFrame,
                      let id = body["id"] as? String, !id.isEmpty else { return }
                let up = (body["up"] as? Bool) ?? false
                // the bar watches the calendar's chrome, so the hosted
                // sheet's view reports into its owner
                let target: OverlayChrome? = role == .host ? sheet?.owner : chrome
                let key = role == .host ? "host:" + id : id
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        target?.setLayer(key, up)
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
                let nextFlag = (body["next"] as? Bool) ?? false
                let model = DSGaugeModel(rect: rect, fill: num("fill"),
                                         kcal: Int(num("kcal")), goal: Int(num("goal")),
                                         p: Int(num("p")), c: Int(num("c")), f: Int(num("f")),
                                         next: nextFlag,
                                         state: body["state"] as? String ?? "progress",
                                         dock: body["dock"] as? String ?? (nextFlag ? "next" : "none"),
                                         warnMsg: body["warn"] as? String ?? "",
                                         selc: body["selc"] as? String ?? "#ED1C24",
                                         selcDark: (body["selcDark"] as? Bool) ?? false,
                                         instant: (body["instant"] as? Bool) ?? false)
                #if DEBUG
                NSLog("DSGAUGE state=%@ dock=%@ kcal=%d fill=%.2f instant=%d",
                      model.state, model.dock, model.kcal, model.fill,
                      model.instant ? 1 : 0)
                #endif
                DispatchQueue.main.async {
                    self.chrome.frame = frame
                    // no ambient animation: the persistent twin drives every
                    // state's motion itself (protocol v2 — one glass)
                    self.chrome.gauge = model
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
            #if DEBUG
            NSLog("DSHAPTIC kind=%@ style=%@", kind, style)
            #endif
            DispatchQueue.main.async {
                switch kind {
                case "notification":
                    let map: [String: UINotificationFeedbackGenerator.FeedbackType] = [
                        "success": .success, "warning": .warning, "error": .error,
                    ]
                    UINotificationFeedbackGenerator()
                        .notificationOccurred(map[style] ?? .success)
                case "selection":
                    UISelectionFeedbackGenerator().selectionChanged()
                default:
                    UIImpactFeedbackGenerator(style: Relay.impactStyle[style] ?? .light)
                        .impactOccurred()
                }
            }
        }
    }

    // MARK: - Sheet host (composition.html#spec-sheethost, canon 426a54b)

    /// The one injected capability object. MAIN-FRAME-ONLY, document start,
    /// and only into views that take part in hosting (the calendar and its
    /// host) — per surface, per the spec's clause A. Every hub flow is an
    /// embed=1 IFRAME and the bridge script reaches subframes, so a cap
    /// visible there would read `hosted` and send that flow's lab Exit
    /// native; the page also requires parent === window. Both guards, kept.
    /// Adding a capability means adding it HERE, in the same diff as the code
    /// that honours it.
    static let capsJS = "window.DSNativeCaps = { sheetHost: 1, tileRows: 2, dateWidget: 1 };"

    /// ONE LAB MENU (Rashid): views that sit under the pilot's own
    /// three-finger gesture announce it, so lab-shell binds no second web
    /// menu there. MERGED, never assigned — the calendar's caps are already
    /// on the object. Main frame only, like every cap.
    static let labMenuCapsJS = "window.DSNativeCaps = Object.assign(window.DSNativeCaps || {}, { labMenu: 1, layers: 1 });"

    /// document-END runs at DOMContentLoaded (didFinish is the later load
    /// event). Down-messages buffer until this edge.
    static let readyJS = "try { webkit.messageHandlers.ds.postMessage({ t: 'ds-ready' }); } catch (_) {}"

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
        // The calendar is the only pilot surface that HOSTS a sheet, so it is
        // the only entry that announces sheetHost (per-surface caps).
        if path == "meal-select" {
            relay.role = .calendar
            cfg.userContentController.addUserScript(
                WKUserScript(source: Self.capsJS + " " + Self.labMenuCapsJS,
                             injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        // Flow pages detect the shell by the UA token (embed styling, haptics)
        wv.customUserAgent = (WKWebView().value(forKey: "userAgent") as? String ?? "Mozilla/5.0")
            + " DietStationLab/2"
        relay.chrome.webView = wv
        wv.navigationDelegate = relay
        relay.onTerminate = { [weak self] in self?.reload(path) }
        entries[path] = (wv, relay)
        reload(path)
        return entries[path]!
    }

    /// Fresh load — used to warm initially and to re-arm after a visit
    /// (the page's sheet has slid away once ds-close fires).
    func reload(_ path: String) {
        guard let e = entries[path] else { return }
        let stamp = Int(Date().timeIntervalSince1970)
        // a path may carry its own query (the solo details page) — append
        // rather than re-open one
        let sep = path.contains("?") ? "&" : "/?"
        // DEBUG-ONLY LANE PRIMER. The Calendar lane gates the date tile's
        // handover on a page-side flag that only flips once the rows are
        // measured on a shipped build — so there is no way to measure them
        // until someone forces the handover. `?tilenative=1` is their switch
        // for exactly that, and this passes it through (plus anything else a
        // lane run needs) from the launch environment, so a verification
        // drives the REAL pilot path rather than a page loaded by hand.
        var extra = ""
        #if DEBUG
        if let p = ProcessInfo.processInfo.environment["DSLAB_FLOW_QUERY"],
           !p.isEmpty {
            extra = "&" + p
        }
        #endif
        if let url = URL(string: "https://rashidalo.github.io/Diet-station/\(path)\(sep)embed=1&v=\(stamp)\(extra)") {
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
        // TOUCH LAW (system/platform.html): lab gestures never delay
        // touches under a web surface — delaysTouchesBegan/Ended both
        // false. (END defaults TRUE: it withheld a short swipe's
        // touch-end up to minimumPressDuration, eating quick sub-24pt
        // flicks; long flicks fail the recognizer instantly, which is
        // why it hid through every verification burst.)
        r.delaysTouchesBegan = false
        r.delaysTouchesEnded = false
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
        // TOUCH LAW (system/platform.html): lab gestures never delay
        // touches under a web surface — delaysTouchesBegan/Ended both
        // false. (END defaults TRUE: it withheld a short swipe's
        // touch-end up to minimumPressDuration, eating quick sub-24pt
        // flicks; long flicks fail the recognizer instantly, which is
        // why it hid through every verification burst.)
        r.delaysTouchesBegan = false
        r.delaysTouchesEnded = false
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
        r.cancelsTouchesInView = false   // parity with the hold recognizers
        // TOUCH LAW (system/platform.html): lab gestures never delay
        // touches under a web surface — delaysTouchesBegan/Ended both
        // false. (END defaults TRUE: it withheld a short swipe's
        // touch-end up to minimumPressDuration, eating quick sub-24pt
        // flicks; long flicks fail the recognizer instantly, which is
        // why it hid through every verification burst.)
        r.delaysTouchesBegan = false
        r.delaysTouchesEnded = false
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
    /* protocol v2 (Rashid 2026-09-09): ONE persistent glass, every state
       native — the web streams semantic states, no more bar hand-backs.
       Defaults keep older parses (the hub Coordinator) source-compatible. */
    var state: String = "progress"   // hidden | progress | warn | celebrate
    var dock: String = "none"        // none | check | next | loader
    var warnMsg: String = ""
    var selc: String = "#ED1C24"     // theme color for the Done flood
    var selcDark: Bool = false       // neon theme: ink Done text, not white
    var instant: Bool = false        // day-turn hide: no animation
}

@available(iOS 26.0, *)
struct DSGaugeGlassView: View {
    /// #f9f9f9 — the dock's label, glyphs and spinner all share it, so the
    /// word and the ring can never half-flip. It is WHITE, and the material
    /// is what moves: Rashid asked to "lower the glass brightness so the word
    /// Next and the loader are readable", which names the material as the
    /// variable and the white ink as a CONSTRAINT. Dark ink was an option we
    /// invented and he rejected it on sight.
    static let dockInk = Color(red: 249/255, green: 249/255, blue: 249/255)
    let model: DSGaugeModel
    var onNext: () -> Void
    /// grows by exactly 1 per warn — the shake effect plays t: 0→1 each time
    @State private var shakes: CGFloat = 0

    private var hidden: Bool { model.state == "hidden" }
    private var selcColor: Color { Color(dsHex: model.selc) }

    var body: some View {
        ZStack(alignment: .leading) {
            fillBar
                .opacity(model.state == "warn" || model.state == "celebrate" ? 0 : 1)
            // Done: the whole bar floods the theme color under the check
            Capsule().fill(selcColor)
                .opacity(model.state == "celebrate" ? 1 : 0)
            // over-quota: the error sits on FROST, not see-through glass
            Capsule().fill(.white.opacity(0.78))
                .opacity(model.state == "warn" ? 1 : 0)
            content
                .opacity(model.state == "progress" ? 1 : 0)
            doneCenter
                .opacity(model.state == "celebrate" ? 1 : 0)
                .scaleEffect(model.state == "celebrate" ? 1 : 0.92)
            warnCenter
                .opacity(model.state == "warn" ? 1 : 0)
        }
        // THE one glass — it never unmounts, never swaps for a web bar:
        // every state above is a crossfade INSIDE the same material
        .glassEffect(.regular, in: .capsule)
        // TOUCH LAW (system/platform.html, 2026-09-10): a display-only twin
        // must never create a dead zone over scrollable content — the bar
        // and its glass pass every touch through to the page. The dock is
        // the ONE real button, so it is layered ON TOP of this disable
        // (same draw order as before: glass is a background, dock above it).
        .allowsHitTesting(false)
        .overlay(alignment: .trailing) { dockView }
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        .animation(.easeOut(duration: 0.25), value: model.state)
        .modifier(DSShakeEffect(travel: shakes))
        // entrance/exit: the web's bar-hidden spring, played natively
        .opacity(hidden ? 0 : 1)
        .scaleEffect(hidden ? 0.9 : 1)
        .offset(y: hidden ? model.rect.height + 80 : 0)
        .animation(model.instant ? nil : .spring(response: 0.42, dampingFraction: 0.68),
                   value: hidden)
        .onChange(of: model.state) { _, s in
            if s == "warn" {
                withAnimation(.easeInOut(duration: 0.5)) { shakes += 1 }
            }
        }
    }

    /// none | check | next | loader — one glass pill morphing between them,
    /// width-animated with crossfading glyphs (Rashid: no button swapping)
    @ViewBuilder private var dockView: some View {
        if model.dock != "none" {
            Button {
                #if DEBUG
                NSLog("DSGAUGE native dock tap dock=%@", model.dock)
                #endif
                if model.dock == "next" { onNext() }
            } label: {
                ZStack {
                    HStack(spacing: 7) {
                        Text("Next").font(DS.urbane(14, .medium))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .fixedSize()
                    .opacity(model.dock == "next" ? 1 : 0)
                    DSSpinnerRing()
                        .opacity(model.dock == "loader" ? 1 : 0)
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .opacity(model.dock == "check" ? 1 : 0)
                }
                // DARK INK, Rashid's call (given both options with the
                // numbers): white on this capsule measured 1.33:1 even after
                // the tint fix, and reaching 3:1 with white would need the
                // capsule down at ~0.30 luminance — a hole punched in the
                // bar rather than glass. Ink on it measures 14.2:1. Safe in
                // every state: the dock only appears once the day is
                // COMPLETE, so its backdrop is always the fill's bright end.
                .foregroundStyle(Self.dockInk)
                // Two shadows, deliberately: the tight one gives the glyph an
                // edge against yellow, the wide soft one lifts it off a busy
                // backdrop without reading as a drop shadow. Applied to the
                // whole dock content, so it reaches the arrow, the check and
                // the spinner's ring as well as the word — on clear glass the
                // ring is the one thing that would otherwise vanish. (CSS
                // blur ≈ 2× SwiftUI radius: 2.5px → 1.25, 8px → 4.)
                // softened after Rashid found them too aggressive: the job
                // is to lift white off a bright ground, not to draw a shadow
                .shadow(color: .black.opacity(0.24), radius: 1.25, y: 1)
                .shadow(color: .black.opacity(0.10), radius: 4)
                .frame(width: model.dock == "next" ? 92 : 53, height: 53)
                // THE MATERIAL'S JOB IS TO DISAPPEAR. Rashid, after we spent
                // three rounds moving the tint: "I just want it in a glass
                // container that's fully transparent, and it blends with the
                // layer below it. No need to darken that much or lighten it
                // that much. It should be very close to what's under it."
                // So the tint is a whisper — no brightness shift in either
                // direction — and LEGIBILITY IS CARRIED BY THE TYPE, not by
                // the glass. Every value we tried failed for the same reason:
                // light was unreadable and dark stopped being glass.
                .glassEffect(.clear.tint(.white.opacity(0.05)).interactive(),
                             in: .capsule)
                // the WHOLE capsule is the button: without a shape only the
                // glyphs were hittable and edge taps fell through to the page
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            // the error owns the bar — Next steps aside while it speaks
            .opacity(model.state == "warn" ? 0 : 1)
            .scaleEffect(model.state == "warn" ? 0.6 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.75), value: model.dock)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.state == "warn")
            .transition(.scale(scale: 0.6).combined(with: .opacity))
        }
    }

    private var doneCenter: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
            Text("Done").font(DS.urbane(17, .semibold))
        }
        .foregroundStyle(model.selcDark
                         ? Color(red: 11/255, green: 14/255, blue: 18/255) : .white)
        .shadow(color: .black.opacity(model.selcDark ? 0 : 0.3), radius: 2, y: 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var warnCenter: some View {
        Text(model.warnMsg)
            .font(DS.urbane(13, .semibold))
            .foregroundStyle(DS.red)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

/// The web's navshake, as an animatable decaying sine: travel advances by 1
/// per warn, x sweeps -9…+8…-6…+4…-2-ish and lands exactly at 0.
struct DSShakeEffect: GeometryEffect {
    var travel: CGFloat
    var animatableData: CGFloat {
        get { travel }
        set { travel = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = travel - floor(travel)
        let x = -sin(t * .pi * 5) * 9 * (1 - t)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}

/// Web loader parity: 22pt ring, 2.5pt stroke, faint track + bright quarter
/// sweeping at .75s/turn.
@available(iOS 26.0, *)
struct DSSpinnerRing: View {
    @State private var spin = false
    /// Shares the dock's ink so the ring and the word can never half-flip.
    var ink: Color = Color(red: 249/255, green: 249/255, blue: 249/255)
    var body: some View {
        ZStack {
            Circle().stroke(ink.opacity(0.34), lineWidth: 2.5)
            Circle().trim(from: 0, to: 0.25)
                .stroke(ink, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(spin ? 360 : 0))
                .animation(.linear(duration: 0.75).repeatForever(autoreverses: false),
                           value: spin)
        }
        .frame(width: 22, height: 22)
        .onAppear { spin = true }
    }
}

extension Color {
    /// #RRGGBB (leading # optional); anything else falls back to DS red
    init(dsHex s: String) {
        var h = s.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        guard h.count == 6, Scanner(string: h).scanHexInt64(&v) else {
            self = DS.red
            return
        }
        self.init(red: Double((v >> 16) & 0xFF) / 255,
                  green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }
}

/// Chrome state for one preloaded overlay webview — the glasschrome protocol
/// mirrored, so flows summoned from the native pilot get chrome identical to
/// the hub path (twins, bar, and the calendar's clear/restore dance).
@available(iOS 26.0, *)
@available(iOS 26.0, *)
extension FlowPreloader.Relay {
    /// The sheet-host vocabulary. Returns true when the message was consumed.
    /// Direction is enforced BY SENDING VIEW: a `ds-up` from the calendar or a
    /// `ds-down` from the host is dropped and logged, never guessed at.
    @MainActor
    func handleSheet(_ t: String, _ body: [String: Any], _ message: WKScriptMessage) -> Bool {
        func drop(_ why: String) {
            #if DEBUG
            NSLog("DSSHEET(pilot) DROPPED %@ — %@", t, why)
            #endif
        }
        switch t {
        case "sheet-open":
            guard role == .calendar else { drop("sheet-open from a non-calendar view"); return true }
            guard message.frameInfo.isMainFrame else { drop("sheet-open from a subframe"); return true }
            guard let s = body["url"] as? String, let url = URL(string: s) else {
                drop("sheet-open without a valid url"); return true
            }
            guard chrome.sheetHost == nil, let cal = chrome.webView else { return true }
            let host = SheetHost(url: url, calendar: cal)
            host.owner = chrome
            chrome.sheetHost = host
            chrome.clearLayers(host: true)   // a fresh sheet starts with no layers
            return true
        case "ds-down":
            guard role == .calendar else { drop("ds-down must come from the calendar view"); return true }
            guard let host = chrome.sheetHost else { drop("ds-down with no host up"); return true }
            host.down(body["msg"] ?? NSNull())
            return true
        case "ds-up":
            guard role == .host else { drop("ds-up must come from the host view"); return true }
            sheet?.up(body["msg"] ?? NSNull())
            return true
        case "ds-ready":
            guard role == .host else { drop("ds-ready from a non-host view"); return true }
            sheet?.markReady()
            return true
        case "sheet-close":
            guard role == .host else { drop("sheet-close from a non-host view"); return true }
            // teardown ONLY here — never inferred from a relayed ds-close
            let owner = sheet?.owner
            owner?.clearLayers(host: true)
            sheet?.close(then: body["then"]) { owner?.sheetHost = nil }
            return true
        case "glasschrome":
            // the page owns what "complete" means; native keeps no id list.
            // Not consumed — the post still arms its twins as normal.
            if role == .host, (body["complete"] as? Bool) == true {
                sheet?.present(fallback: false)
            }
            return false
        default:
            return false
        }
    }
}

/// A native web view presented OVER the calendar's, carrying the meal
/// selector that used to be an iframe inside it. Riding (Ruling 3, b1): the
/// host view and its glass twins sit in one container and move on one native
/// clock, so the controls cannot trail the sheet or hand over mid-motion.
/// Contract: system/composition.html#spec-sheethost.
@available(iOS 26.0, *)
@MainActor
final class SheetHost: ObservableObject {
    let web: WKWebView
    let relay: FlowPreloader.Relay
    weak var calendar: WKWebView?
    /// the calendar overlay's chrome, which holds this host; cleared on teardown
    weak var owner: OverlayChrome?
    /// 1.03 = 103% of the container's height below its rest position
    @Published var offsetFraction: CGFloat = 1.03
    /// THE CONTROLS, FROZEN FOR THE EXIT. The page tears its chrome down on
    /// dismissal (a glasschrome with els:[] right after sheet-close), and the
    /// twins' removal fade then played at their REST position while the sheet
    /// slid away — measured: host els 3 -> 0 on the frame after `closing`,
    /// and the X, date and dual visibly pinned over the calendar mid-exit.
    /// Native owns the exit, so native keeps drawing what was on screen at
    /// the moment it started, riding out with the sheet, until teardown.
    @Published var exitEls: [GlassChromeEl]?
    private(set) var ready = false
    private var buffer: [Any] = []
    private(set) var presented = false
    private var closing = false
    private var watchdog: DispatchWorkItem?
    private let openedAt = Date()

    /// the spec's curve, used FORWARD for both entry (103% -> 0) and exit
    /// (0 -> 103%). Not time-reversed on exit — that would be a heavy ease-in
    /// nobody has approved.
    // curve: see `bezier` — cubic-bezier(.32,.72,0,1) over 0.55s, forward both ways
    /// PROVISIONAL. The spec requires this to be measured (uncached p95 of
    /// first complete post after sheet-open) and set just above it.
    static let watchdogSeconds: TimeInterval = 1.4

    init(url: URL, calendar: WKWebView) {
        let relay = FlowPreloader.Relay()
        relay.role = .host
        let cfg = WKWebViewConfiguration()
        // NO closeRelay here: the selector self-posts ds-close in one path
        // (select.html's window.postMessage), and in its own view that must not
        // be read as "close the overlay". Every hosted dismissal comes through
        // sheet-close instead.
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.userContentController.addUserScript(
            WKUserScript(source: LabWebView.Coordinator.bridgeJS,
                         injectionTime: .atDocumentStart, forMainFrameOnly: false))
        // The calendar is full-screen at rest, so ITS inset is the inset this
        // sheet will have at rest. Only the HOST gets `safeTop`: it is the one
        // view that loads while held off-screen, where env() reads 0.
        let restTop = calendar.window?.safeAreaInsets.top ?? calendar.safeAreaInsets.top
        cfg.userContentController.addUserScript(
            WKUserScript(source: FlowPreloader.capsJS + " " + FlowPreloader.labMenuCapsJS
                            + " window.DSNativeCaps.safeTop = \(Int(restTop.rounded()));",
                         injectionTime: .atDocumentStart, forMainFrameOnly: true))
        cfg.userContentController.addUserScript(
            WKUserScript(source: FlowPreloader.readyJS, injectionTime: .atDocumentEnd,
                         forMainFrameOnly: true))
        cfg.userContentController.add(relay, name: "ds")
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque = false
        wv.backgroundColor = .clear
        wv.scrollView.backgroundColor = .clear
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.customUserAgent = (WKWebView().value(forKey: "userAgent") as? String ?? "Mozilla/5.0")
            + " DietStationLab/2"
        relay.chrome.webView = wv
        self.web = wv
        self.relay = relay
        self.calendar = calendar
        relay.sheet = self
        #if DEBUG
        NSLog("DSSHEET(pilot) open url=%@", url.absoluteString)
        #endif
        wv.load(URLRequest(url: url))
        let work = DispatchWorkItem { [weak self] in self?.present(fallback: true) }
        watchdog = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.watchdogSeconds, execute: work)
    }

    private var sinceOpenMS: Int { Int(Date().timeIntervalSince(openedAt) * 1000) }
    #if DEBUG
    /// EVIDENCE 5 (storage round-trip) and 7 (visibility + timer cadence),
    /// taken in the host once it is on screen.
    func evidenceProbes() {
        let key = "dsprobe-\(Int(Date().timeIntervalSince1970))"
        // Read at 0s, 1s and 3s: localStorage between two WKWebViews in
        // different web content processes propagates ASYNCHRONOUSLY, so an
        // immediate nil is not evidence of "not shared" — the absence has to
        // be earned by a later read too. Also reads the calendar's origin.
        calendar?.evaluateJavaScript("localStorage.setItem('dsprobe', '\(key)'); location.origin") { [weak self] o, _ in
            let calOrigin = (o as? String) ?? "?"
            for delay in [0.0, 1.0, 3.0] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self?.web.evaluateJavaScript("JSON.stringify({ v: localStorage.getItem('dsprobe'), origin: location.origin })") { v, _ in
                        let s = (v as? String) ?? "nil"
                        NSLog("DSEVIDENCE(pilot) 5 storage t+%.0fs set=%@ calOrigin=%@ host=%@ %@",
                              delay, key, calOrigin, s, s.contains(key) ? "PASS" : "not-yet")
                    }
                }
            }
        }
        let cadence = """
        new Promise(function(res){ var n=0, t0=performance.now();
          var id=setInterval(function(){ n++; }, 100);
          setTimeout(function(){ clearInterval(id);
            res(JSON.stringify({ vis: document.visibilityState, hidden: document.hidden,
              ticksIn2s: n, expected: 20, ms: Math.round(performance.now()-t0) })); }, 2000); })
        """
        web.callAsyncJavaScript("return await " + cadence, arguments: [:], in: nil, in: .page) { r in
            NSLog("DSEVIDENCE(pilot) 7 host %@", String(describing: (try? r.get()) ?? "err"))
        }
    }

    /// What the page can see of the safe area, from inside the host view.
    private func logInsets(_ label: String) {
        let js = "(function(){var d=document.createElement('div');d.style.cssText='position:fixed;padding-top:env(safe-area-inset-top)';document.documentElement.appendChild(d);var v=getComputedStyle(d).paddingTop;d.remove();return v})()"
        let native = web.safeAreaInsets.top
        let frame = web.convert(web.bounds, to: nil)
        web.evaluateJavaScript(js) { v, _ in
            NSLog("DSSHEET(pilot) insets@%@ native=%.1f env=%@ frameY=%.0f",
                  label, native, String(describing: v ?? "nil"), frame.minY)
        }
    }
    #endif


    // relay -----------------------------------------------------------------

    func markReady() {
        guard !ready else { return }
        ready = true
        #if DEBUG
        NSLog("DSSHEET(pilot) ds-ready after %dms, flushing %d", sinceOpenMS, buffer.count)
        #endif
        let pending = buffer; buffer = []
        for m in pending { Self.dispatch(m, into: web) }
        #if DEBUG
        logInsets("ds-ready")
        #endif
    }

    /// calendar -> host. Buffered until the host has DOMContentLoaded.
    func down(_ msg: Any) {
        if ready { Self.dispatch(msg, into: web) } else { buffer.append(msg) }
    }

    /// host -> calendar.
    func up(_ msg: Any) {
        guard let cal = calendar else { return }
        Self.dispatch(msg, into: cal)
    }

    /// A real `message` event, so the pages' existing handlers (which read
    /// only e.data) cannot tell it from a cross-frame postMessage.
    static func dispatch(_ msg: Any, into wv: WKWebView) {
        guard JSONSerialization.isValidJSONObject(msg) || msg is String || msg is NSNumber,
              let data = try? JSONSerialization.data(withJSONObject: msg, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            #if DEBUG
            NSLog("DSSHEET(pilot) relay DROPPED unserialisable payload")
            #endif
            return
        }
        wv.evaluateJavaScript(
            "window.dispatchEvent(new MessageEvent('message', { data: \(json) }));",
            completionHandler: nil)
    }

    private func sheetCall(_ phase: String) {
        let js = "window.DSSheet && DSSheet('\(phase)');"
        web.evaluateJavaScript(js, completionHandler: nil)
        calendar?.evaluateJavaScript(js, completionHandler: nil)
    }

    // motion ----------------------------------------------------------------

    // motion ----------------------------------------------------------------
    //
    // ONE CLOCK, EXPLICITLY. The first version animated `offsetFraction` with
    // `withAnimation`. Filmed at 60fps, the web view rode but the glass twins
    // did NOT: the X drew at its rest y (125.8pt) from the frame it appeared,
    // while the sheet's top was still at 299pt and climbing — i.e. "pinned",
    // the motion Ruling 3 rejected. The twins' els arrive in their own
    // transaction and render at the model's FINAL value, so an interpolated
    // ancestor animation never reached them. A display link now advances the
    // offset every frame, applied with animations disabled, and BOTH the web
    // view and every twin read that same per-frame value. Completion is the
    // frame the curve reaches 1 — a real landing, not a timer.

    private var link: CADisplayLink?
    private var mFrom: CGFloat = 1.03, mTo: CGFloat = 0
    private var mStart: CFTimeInterval = 0
    private var mDone: (() -> Void)?

    private final class Tick: NSObject {
        weak var host: SheetHost?
        init(_ h: SheetHost) { host = h }
        @objc func step(_ l: CADisplayLink) { MainActor.assumeIsolated { host?.step() } }
    }

    private func run(from: CGFloat, to: CGFloat, done: @escaping () -> Void) {
        link?.invalidate()
        mFrom = from; mTo = to; mDone = done
        mStart = CACurrentMediaTime()
        let l = CADisplayLink(target: Tick(self), selector: #selector(Tick.step(_:)))
        l.add(to: .main, forMode: .common)
        link = l
    }

    #if DEBUG
    private var stepCount = 0
    #endif
    fileprivate func step() {
        let p = min(1, (CACurrentMediaTime() - mStart) / 0.55)
        #if DEBUG
        stepCount += 1
        if stepCount % 6 == 0 {
            NSLog("DSSHEET(pilot) step p=%.2f frac=%.3f els=%d", p, offsetFraction, relay.chrome.els.count)
        }
        #endif
        let e = Self.bezier(CGFloat(p))
        var tx = Transaction(); tx.disablesAnimations = true
        withTransaction(tx) { offsetFraction = mFrom + (mTo - mFrom) * e }
        if p >= 1 {
            link?.invalidate(); link = nil
            let d = mDone; mDone = nil
            d?()
        }
    }

    /// CSS cubic-bezier(.32, .72, 0, 1), evaluated at progress x.
    static func bezier(_ x: CGFloat) -> CGFloat {
        let x1: CGFloat = 0.32, y1: CGFloat = 0.72, x2: CGFloat = 0, y2: CGFloat = 1
        func bx(_ t: CGFloat) -> CGFloat { 3*(1-t)*(1-t)*t*x1 + 3*(1-t)*t*t*x2 + t*t*t }
        func by(_ t: CGFloat) -> CGFloat { 3*(1-t)*(1-t)*t*y1 + 3*(1-t)*t*t*y2 + t*t*t }
        if x <= 0 { return 0 }; if x >= 1 { return 1 }
        var lo: CGFloat = 0, hi: CGFloat = 1, t = x
        for _ in 0..<24 { t = (lo + hi) / 2; if bx(t) < x { lo = t } else { hi = t } }
        return by(t)
    }

    /// Entry. Released by the page's `complete: true` post — the page owns
    /// what complete means — or by the watchdog, which presents anyway and
    /// tells the page to keep its web chrome for this surface's life.
    func present(fallback: Bool) {
        guard !presented, !closing else { return }
        presented = true
        watchdog?.cancel(); watchdog = nil
        #if DEBUG
        NSLog("DSSHEET(pilot) present via %@ after %dms", fallback ? "WATCHDOG" : "complete", sinceOpenMS)
        #endif
        if fallback { sheetCall("fallback") }
        run(from: 1.03, to: 0) { [weak self] in
            self?.sheetCall("presented")
            #if DEBUG
            NSLog("DSSHEET(pilot) presented (landed)")
            self?.logInsets("presented")
            self?.evidenceProbes()
            #endif
        }
    }

    /// Exit: closing to the calendar, the same curve FORWARD to 103%, tear
    /// the host down, and only THEN relay `then` up — so the calendar paints
    /// its result with nothing departing over it.
    func close(then: Any?, onTornDown: @escaping () -> Void) {
        guard !closing else { return }
        closing = true
        watchdog?.cancel(); watchdog = nil
        calendar?.evaluateJavaScript("window.DSSheet && DSSheet('closing');", completionHandler: nil)
        #if DEBUG
        NSLog("DSSHEET(pilot) closing from=%.3f els=%d mode=%@ firstY=%@ hostChromeWV=%@",
              offsetFraction, relay.chrome.els.count, relay.chrome.mode ?? "nil",
              relay.chrome.els.first.map { String(format: "%.1f", $0.y) } ?? "-",
              relay.chrome.webView === web ? "host" : "OTHER")
        #endif
        exitEls = relay.chrome.els
        run(from: offsetFraction, to: 1.03) { [weak self] in
            guard let self else { return }
            self.web.stopLoading()
            self.web.configuration.userContentController.removeAllScriptMessageHandlers()
            self.relay.chrome.clear()
            onTornDown()
            if let then { self.up(then) }
            #if DEBUG
            NSLog("DSSHEET(pilot) torn down, relayed then")
            #endif
        }
    }
}

final class OverlayChrome: ObservableObject {
    /// the sheet currently hosted over this (calendar) overlay, if any.
    /// Typed as AnyObject because OverlayChrome predates the iOS 26 gate and
    /// SheetHost does not; read it through `host` below.
    @Published var sheetHostBox: AnyObject?
    @available(iOS 26.0, *)
    var sheetHost: SheetHost? {
        get { sheetHostBox as? SheetHost }
        set { sheetHostBox = newValue }
    }
    @Published var els: [GlassChromeEl] = []
    @Published var bar: String?
    @Published var flow: String?
    @Published var surface: String?
    @Published var mode: String?
    @Published var gauge: DSGaugeModel?
    /// chrome layers: true while a higher surface (the calendar's meal
    /// selector) owns the whole screen — hosts with a persistent DS bar
    /// drop it for the duration
    @Published var selectorUp = false
    /// LAYERS (platform.html `layer`): ids of web surfaces that currently own
    /// the screen. A SET, so covers stack and one closing never un-hides the
    /// bar over another. Ids from the hosted sheet's view are kept as
    /// "host:<id>" so the two views can't cancel each other's.
    @Published var layers: Set<String> = []
    func setLayer(_ id: String, _ up: Bool) {
        if up { layers.insert(id) } else { layers.remove(id) }
    }
    /// drop one view's ids — on its navigation, unload or teardown, so a
    /// missed `up:false` can't hide the bar for good
    func clearLayers(host: Bool) {
        layers = layers.filter { $0.hasPrefix("host:") != host }
    }
    weak var webView: WKWebView?
    var frame: WKFrameInfo?

    func chromeTap(_ id: String) {
        webView?.evaluateJavaScript("window.DSChromeTap && DSChromeTap('\(id)')",
                                    in: frame, in: .page, completionHandler: nil)
    }

    /// NO PAGE CURRENTLY CALLS THIS (2026-09-13). It was built for the
    /// calendar's badge, and the Calendar lane then proved the 620ms it was
    /// meant to compensate for was their own page's paint — so their fix is a
    /// plain CSS delay and they use nothing from here. It is kept because the
    /// COVER-PRESENTED paths (coupons, rewards, auth, guide, meal details) do
    /// animate and the question "am I on screen yet" is reasonable to be able
    /// to ask. But treat it as UNEXERCISED: no production page has ever taken
    /// the signal, so it is verified only by unit checks and my own logs. If
    /// nothing adopts it, DELETE IT rather than leave a primitive that looks
    /// load-bearing and has never carried anything.
    ///
    /// SURFACE PRESENTED. One-way, no confirm, two posts:
    ///   { phase: 'presenting', duration } — immediately, so a page can size
    ///      an `animation-delay` from the real number instead of a constant
    ///      tuned to one device
    ///   { phase: 'presented' }            — when the surface has arrived, so
    ///      a page can start on a SIGNAL and stop guessing altogether
    /// The shell owns the presentation, so the shell publishes the primitive
    /// and the page never times against it. A page that doesn't define
    /// `DSNativeSurface` is unaffected — the call no-ops, which is what makes
    /// this safe to ship before any page uses it.
    /// Fire-and-forget by design: a page's entry animation must not depend on
    /// the shell hearing an answer.
    private var announcedPresented = false

    private func postSurface(_ js: String) {
        guard let wv = webView else { return }
        wv.evaluateJavaScript(js, in: frame, in: .page, completionHandler: nil)
    }

    func announceSurfaceDuration(_ settle: TimeInterval) {
        announcedPresented = false
        postSurface("window.DSNativeSurface && DSNativeSurface("
                    + "{ phase: 'presenting', duration: \(settle) })")
    }

    /// AT MOST ONCE per presentation, whichever path gets here first — the
    /// observed settle or the safety timer. A page must be able to treat
    /// `presented` as an edge, not a stream.
    func announceSurfacePresented(reason: String) {
        guard !announcedPresented else { return }
        announcedPresented = true
        postSurface("window.DSNativeSurface && DSNativeSurface({ phase: 'presented' })")
        #if DEBUG
        NSLog("DSSURFACE(pilot) presented via %@", reason)
        #endif
    }
    func clear() {
        els = []
        bar = nil
        flow = nil
        surface = nil
        mode = nil
        gauge = nil
        frame = nil
        selectorUp = false
        layers = []
    }
}

/// Presents a (preloaded) lab web flow over the native screen with its native
/// glass chrome mounted inside the cover. The page runs its own sheet
/// choreography and posts ds-close when done; after dismissal the webview
/// re-arms in the background for the next summon.
@available(iOS 26.0, *)
struct FlowOverlay: View {
    let path: String
    /// false when the HOST keeps a persistent DS bar above this overlay
    /// (the pilot's one-bar architecture) — the internal bar stays off
    var ownsTabBar: Bool = true
    /// chrome layers: fires when a higher surface inside the flow (the
    /// calendar's meal selector) takes or releases the whole screen, so a
    /// persistent-bar host can drop its bar for the duration
    var onSelector: ((Bool) -> Void)? = nil
    /// fires when this flow's layer set turns non-empty / empty
    var onLayers: ((Bool) -> Void)? = nil
    let onClose: () -> Void
    @ObservedObject private var chrome: OverlayChrome

    @MainActor
    init(path: String, ownsTabBar: Bool = true, presentSettle: TimeInterval = 0.62,
         onSelector: ((Bool) -> Void)? = nil, onLayers: ((Bool) -> Void)? = nil,
         onClose: @escaping () -> Void) {
        self.path = path
        self.ownsTabBar = ownsTabBar
        self.presentSettle = presentSettle
        self.onSelector = onSelector
        self.onLayers = onLayers
        self.onClose = onClose
        _chrome = ObservedObject(wrappedValue: FlowPreloader.shared.entry(path).relay.chrome)
    }

    /// How long THIS host takes to put the surface on screen. Not a constant,
    /// because it is not the same on every path: a cover-presented flow rides
    /// a spring, while the calendar is switched on with no cover and no
    /// position shift at all (see `calendarOpen`), so its honest value is 0.
    /// Publishing 0.62 everywhere would tell a page to delay for an animation
    /// that isn't running — which is exactly the wrong number in the wrong
    /// direction, and the reason to ask "which surface" before wiring
    /// mechanism to a measurement.
    let presentSettle: TimeInterval

    /// last observed top edge, and whether it has ever moved — a surface that
    /// is already in place when we start watching must not be reported as
    /// "arrived" before it has actually animated
    @State private var lastY: CGFloat?
    @State private var everMoved = false

    private func settleWatch(_ y: CGFloat) {
        defer { lastY = y }
        guard let prev = lastY else { return }
        if abs(y - prev) > 0.5 { everMoved = true; return }
        // two consecutive frames within half a point, after real movement:
        // the presentation has landed
        if everMoved { chrome.announceSurfacePresented(reason: "settled") }
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
                // SURFACE PRESENTED — the shell owns this motion, so the
                // shell exposes the primitive and the page never times
                // against it (MATCH A FLAG, NOT A CURVE). A web page cannot
                // observe a native presentation: it renders, and then spends
                // the whole arrival off-screen. Measured on TestFlight 52,
                // the first ~620ms of any entry animation started at load
                // played where nobody could see it — which is why Rashid saw
                // a badge that "left on time" with no playful head: he was
                // shown it from 20% in. Two values, posted one-way, no
                // confirm:
                //   duration — sent AT ONCE so a page can delay its entry
                //              animation by the right amount from load
                //   presented — sent when the surface has actually arrived,
                //              so a page can start on a signal instead of a
                //              constant that rots
                // ARRIVAL IS OBSERVED, NOT TIMED. The duration post still
                // carries the settle for pages that need a number, but
                // `presented` now fires when this view's own frame STOPS
                // MOVING — the overlay presents with `.move(edge: .bottom)`,
                // so its global minY travels and then settles, and that is
                // the surface actually arriving rather than a constant that
                // agrees with it today. C&M's ·26 takes only the event, so
                // this was the last number in the chain that could rot.
                // The timer stays as a SAFETY net (a page that hid its
                // content waiting for a post that never came would be worse
                // than the bug this fixes), and announceSurface fires
                // `presented` at most once however it is reached.
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY }
                    action: { newY in settleWatch(newY) }
                .onAppear {
                    chrome.announceSurfaceDuration(presentSettle)
                    // safety: if the geometry never settles (or never moves,
                    // e.g. reduce-motion presenting with no animation) the
                    // page still gets its signal
                    DispatchQueue.main.asyncAfter(deadline: .now() + presentSettle + 0.08) {
                        chrome.announceSurfacePresented(reason: "timer")
                    }
                }
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
            if ownsTabBar, chrome.bar == "calendar" {
                // THE unified DS tab bar; home tap animates the pill, then
                // returns to the pilot (Apple's beat)
                DSTabBarHost(initial: .calendar) { tab in
                    if tab == .home {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { onClose() }
                    }
                }
                .padding(.bottom, DS.barBottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            // THE HOSTED SHEET, last so it sits above everything the calendar
            // draws (as the iframe did). The calendar's scrim stays in the
            // calendar's own document beneath it and never rides.
            if let host = chrome.sheetHost {
                SheetHostView(host: host, chrome: host.relay.chrome)
            }
        }
        .onChange(of: chrome.selectorUp) { _, up in onSelector?(up) }
        .onChange(of: chrome.layers.isEmpty) { _, empty in onLayers?(!empty) }
    }
}

/// The hosted sheet: its web view, its glass twins and its gauge in ONE
/// container with ONE offset, so they share a clock by construction — no
/// per-frame sync during entry or exit, and the page's rest rects stay valid
/// throughout because they're relative to the moving view.
@available(iOS 26.0, *)
private struct SheetHostView: View {
    @ObservedObject var host: SheetHost
    @ObservedObject var chrome: OverlayChrome

    var body: some View {
        GeometryReader { geo in
            // THE SAME NUMBER, APPLIED TO EVERYTHING, EVERY FRAME. No shared
            // ancestor offset: the web view is offset directly, and each twin
            // and the gauge are drawn at their posted rect shifted by the same
            // dy. So the sheet and its controls cannot disagree on any frame.
            let dy = host.offsetFraction * geo.size.height
            ZStack {
                HostedWebView(web: host.web)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .offset(y: dy)
                GlassChromeLayer(els: (host.exitEls ?? chrome.els).map { var e = $0; e.y += dy; return e },
                                 flow: chrome.flow,
                                 surface: chrome.surface,
                                 mode: chrome.mode) { chrome.chromeTap($0) }
                if let g = chrome.gauge {
                    DSGaugeGlassView(model: g) { chrome.chromeTap("gauge-next") }
                        .frame(width: g.rect.width, height: g.rect.height)
                        .position(x: g.rect.midX, y: g.rect.midY + dy)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
    }
}

/// An existing WKWebView placed in SwiftUI as-is (the host owns its lifetime).
private struct HostedWebView: UIViewRepresentable {
    let web: WKWebView
    func makeUIView(context: Context) -> WKWebView { web }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
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

/// Figma export: home/ic-restaurant.svg — the fork-knife (23-grid)
struct DSForkKnifeIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 15.333, y: 5.750))
        p.addLine(to: CGPoint(x: 15.333, y: 11.500))
        p.addCurve(to: CGPoint(x: 17.250, y: 13.417), control1: CGPoint(x: 15.333, y: 12.554), control2: CGPoint(x: 16.196, y: 13.417))
        p.addLine(to: CGPoint(x: 18.208, y: 13.417))
        p.addLine(to: CGPoint(x: 18.208, y: 20.125))
        p.addCurve(to: CGPoint(x: 19.167, y: 21.083), control1: CGPoint(x: 18.208, y: 20.652), control2: CGPoint(x: 18.640, y: 21.083))
        p.addCurve(to: CGPoint(x: 20.125, y: 20.125), control1: CGPoint(x: 19.694, y: 21.083), control2: CGPoint(x: 20.125, y: 20.652))
        p.addLine(to: CGPoint(x: 20.125, y: 3.000))
        p.addCurve(to: CGPoint(x: 18.937, y: 2.060), control1: CGPoint(x: 20.125, y: 2.377), control2: CGPoint(x: 19.540, y: 1.917))
        p.addCurve(to: CGPoint(x: 15.333, y: 5.750), control1: CGPoint(x: 16.867, y: 2.568), control2: CGPoint(x: 15.333, y: 4.322))
        p.closeSubpath()
        p.move(to: CGPoint(x: 10.542, y: 8.625))
        p.addLine(to: CGPoint(x: 8.625, y: 8.625))
        p.addLine(to: CGPoint(x: 8.625, y: 2.875))
        p.addCurve(to: CGPoint(x: 7.667, y: 1.917), control1: CGPoint(x: 8.625, y: 2.348), control2: CGPoint(x: 8.194, y: 1.917))
        p.addCurve(to: CGPoint(x: 6.708, y: 2.875), control1: CGPoint(x: 7.140, y: 1.917), control2: CGPoint(x: 6.708, y: 2.348))
        p.addLine(to: CGPoint(x: 6.708, y: 8.625))
        p.addLine(to: CGPoint(x: 4.792, y: 8.625))
        p.addLine(to: CGPoint(x: 4.792, y: 2.875))
        p.addCurve(to: CGPoint(x: 3.833, y: 1.917), control1: CGPoint(x: 4.792, y: 2.348), control2: CGPoint(x: 4.360, y: 1.917))
        p.addCurve(to: CGPoint(x: 2.875, y: 2.875), control1: CGPoint(x: 3.306, y: 1.917), control2: CGPoint(x: 2.875, y: 2.348))
        p.addLine(to: CGPoint(x: 2.875, y: 8.625))
        p.addCurve(to: CGPoint(x: 6.708, y: 12.458), control1: CGPoint(x: 2.875, y: 10.743), control2: CGPoint(x: 4.590, y: 12.458))
        p.addLine(to: CGPoint(x: 6.708, y: 20.125))
        p.addCurve(to: CGPoint(x: 7.667, y: 21.083), control1: CGPoint(x: 6.708, y: 20.652), control2: CGPoint(x: 7.140, y: 21.083))
        p.addCurve(to: CGPoint(x: 8.625, y: 20.125), control1: CGPoint(x: 8.194, y: 21.083), control2: CGPoint(x: 8.625, y: 20.652))
        p.addLine(to: CGPoint(x: 8.625, y: 12.458))
        p.addCurve(to: CGPoint(x: 12.458, y: 8.625), control1: CGPoint(x: 10.743, y: 12.458), control2: CGPoint(x: 12.458, y: 10.743))
        p.addLine(to: CGPoint(x: 12.458, y: 2.875))
        p.addCurve(to: CGPoint(x: 11.500, y: 1.917), control1: CGPoint(x: 12.458, y: 2.348), control2: CGPoint(x: 12.027, y: 1.917))
        p.addCurve(to: CGPoint(x: 10.542, y: 2.875), control1: CGPoint(x: 10.973, y: 1.917), control2: CGPoint(x: 10.542, y: 2.348))
        p.addLine(to: CGPoint(x: 10.542, y: 8.625))
        p.closeSubpath()
        let s = min(rect.width / 23, rect.height / 23)
        let t = CGAffineTransform(translationX: rect.midX - 23 * s / 2,
                                  y: rect.midY - 23 * s / 2)
            .scaledBy(x: s, y: s)
        return p.applying(t)
    }
}

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

/// Figma export: home/ic-coupon.svg — the coupon tag (Rashid, 2026-09-14:
/// "use this icon for coupons in the glass containers"); shape-for-shape
/// the same two layers checkout draws, in home's white on the red glass
/// (a red tag disappears on the red widget)
struct DSCouponIcon: View {
    var body: some View {
        ZStack {
            DSCouponBackShape().fill(.white.opacity(0.19))
            DSCouponFrontShape().fill(.white.opacity(0.65))
        }
    }
}

struct DSCouponBackShape: Shape {
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
        let s = min(rect.width / 37.9973, rect.height / 33.5123)
        let t = CGAffineTransform(translationX: rect.midX - 37.9973 * s / 2,
                                  y: rect.midY - 33.5123 * s / 2)
            .scaledBy(x: s, y: s)
        return p.applying(t)
    }
}

struct DSCouponFrontShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 10.955, y: 3.549))
        p.addCurve(to: CGPoint(x: 14.572, y: 3.549), control1: CGPoint(x: 11.975, y: 2.603), control2: CGPoint(x: 13.552, y: 2.603))
        p.addCurve(to: CGPoint(x: 20.731, y: 9.264), control1: CGPoint(x: 16.970, y: 5.774), control2: CGPoint(x: 20.709, y: 9.243))
        p.addCurve(to: CGPoint(x: 21.581, y: 11.213), control1: CGPoint(x: 21.273, y: 9.767), control2: CGPoint(x: 21.581, y: 10.473))
        p.addLine(to: CGPoint(x: 21.581, y: 25.031))
        p.addCurve(to: CGPoint(x: 18.922, y: 27.691), control1: CGPoint(x: 21.581, y: 26.500), control2: CGPoint(x: 20.391, y: 27.691))
        p.addLine(to: CGPoint(x: 6.603, y: 27.691))
        p.addCurve(to: CGPoint(x: 3.944, y: 25.031), control1: CGPoint(x: 5.134, y: 27.691), control2: CGPoint(x: 3.944, y: 26.500))
        p.addLine(to: CGPoint(x: 3.944, y: 11.213))
        p.addCurve(to: CGPoint(x: 4.794, y: 9.264), control1: CGPoint(x: 3.944, y: 10.473), control2: CGPoint(x: 4.252, y: 9.767))
        p.addCurve(to: CGPoint(x: 10.955, y: 3.549), control1: CGPoint(x: 4.794, y: 9.264), control2: CGPoint(x: 8.549, y: 5.781))
        p.closeSubpath()
        p.move(to: CGPoint(x: 12.767, y: 4.924))
        p.addCurve(to: CGPoint(x: 10.889, y: 6.802), control1: CGPoint(x: 11.730, y: 4.924), control2: CGPoint(x: 10.889, y: 5.765))
        p.addCurve(to: CGPoint(x: 12.767, y: 8.680), control1: CGPoint(x: 10.889, y: 7.839), control2: CGPoint(x: 11.730, y: 8.680))
        p.addCurve(to: CGPoint(x: 14.645, y: 6.802), control1: CGPoint(x: 13.804, y: 8.680), control2: CGPoint(x: 14.645, y: 7.839))
        p.addCurve(to: CGPoint(x: 12.767, y: 4.924), control1: CGPoint(x: 14.645, y: 5.765), control2: CGPoint(x: 13.804, y: 4.924))
        p.closeSubpath()
        let s = min(rect.width / 37.9973, rect.height / 33.5123)
        let t = CGAffineTransform(translationX: rect.midX - 37.9973 * s / 2,
                                  y: rect.midY - 33.5123 * s / 2)
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
