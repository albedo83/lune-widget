import SwiftUI
import WidgetKit
import LuneKit

extension NightEntry {
    /// Entry for a stored place at `date`.
    init(place: StoredPlace, at date: Date) {
        let tz = TimeZone(identifier: place.timeZoneID) ?? .current
        self.init(date: date, placeName: place.name.isEmpty ? nil : place.name,
                  report: NightCalculator.report(at: date, location: place.location, timeZone: tz),
                  latitude: place.location.latitude, timeZone: tz, isCurrentLocation: true)
    }
}

struct ContentView: View {
    private enum Status { case idle, locating, denied, failed }

    private let store: LocationStore
    private let now: Date
    @State private var place: StoredPlace?
    @State private var status = Status.idle
    @State private var authorizer = LocationAuthorizer()
    @Environment(\.locale) private var locale

    init(store: LocationStore = LocationStore(), place: StoredPlace? = nil, now: Date = Date()) {
        self.store = store
        self.now = now
        _place = State(initialValue: place ?? store.current)
    }

    private func text(_ key: String) -> String { Strings.localized(key, locale: locale) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Lune").font(.largeTitle.weight(.semibold))
            Text(text(Strings.howToAdd)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button(text(Strings.useMyLocation)) { Task { await locate() } }
                    .disabled(status == .locating)
                if status == .locating {
                    ProgressView().controlSize(.small)
                    Text(text(Strings.locating)).foregroundStyle(.secondary)
                }
            }
            if let message {
                Text(text(message)).font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            Text(text(Strings.preview)).font(.headline).padding(.top, 4)
            preview
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 480, height: 440, alignment: .topLeading)
    }

    private var message: String? {
        switch status {
        case .denied: Strings.locationDenied
        case .failed: Strings.locationFailed
        default: nil
        }
    }

    @ViewBuilder private var preview: some View {
        if let place {
            ZStack {
                NightBackground()
                NightWidgetView(entry: NightEntry(place: place, at: now)).padding(16)
            }
            .frame(width: 364, height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            Text(text(Strings.previewHint)).foregroundStyle(.secondary)
        }
    }

    private func locate() async {
        status = .locating
        guard await authorizer.ensureAuthorized() else { status = .denied; return }
        guard let found = await CurrentPlaceLocator.fetch() else { status = .failed; return }
        store.current = found
        place = found
        status = .idle
        WidgetCenter.shared.reloadAllTimelines()
    }
}
