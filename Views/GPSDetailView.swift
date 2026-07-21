import SwiftUI

/// Kompakte Signalbalken-Anzeige (wie die Empfangsbalken für Mobilfunk),
/// tippbar, um ein Detail-Overlay mit den genauen Messwerten zu öffnen.
struct GPSSignalBarsView: View {
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    @Binding var showDetail: Bool

    private var quality: GPSQuality {
        GPSQuality.from(horizontalAccuracy: horizontalAccuracy)
    }

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: 6) {
                signalBars
                Text("GPS")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var signalBars: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1..<5) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index <= quality.rawValue ? quality.color : Color.secondary.opacity(0.25))
                    .frame(width: 4, height: CGFloat(index) * 4 + 2)
            }
        }
        .frame(height: 18, alignment: .bottom)
    }
}

/// Detail-Overlay, das beim Tippen auf die Signalbalken erscheint: zeigt die
/// exakte horizontale (und, falls verfügbar, vertikale) Genauigkeit in
/// Metern sowie einen Hinweis, warum keine Satellitenanzahl angezeigt wird.
struct GPSDetailView: View {
    let horizontalAccuracy: Double
    let verticalAccuracy: Double
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto

    private var locale: Locale { appLanguage.resolvedLocale }

    private var quality: GPSQuality {
        GPSQuality.from(horizontalAccuracy: horizontalAccuracy)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            HStack(alignment: .bottom, spacing: 5) {
                                ForEach(1..<5) { index in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(index <= quality.rawValue ? quality.color : Color.secondary.opacity(0.25))
                                        .frame(width: 10, height: CGFloat(index) * 10 + 4)
                                }
                            }
                            Text(quality.label)
                                .font(.headline)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                Section("Messwerte") {
                    LabeledContent("Horizontale Genauigkeit") {
                        Text(horizontalAccuracy >= 0 ? String(format: "±%.0f m", horizontalAccuracy) : "–")
                    }
                    LabeledContent("Vertikale Genauigkeit") {
                        Text(verticalAccuracy >= 0 ? String(format: "±%.0f m", verticalAccuracy) : "–")
                    }
                }

                Section("Satelliten") {
                    Text("iOS stellt Apps die Anzahl erfasster GPS-Satelliten aus Datenschutzgründen nicht zur Verfügung. Die Signalqualität wird stattdessen aus der Genauigkeit der Standortmessung abgeleitet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("GPS-Signal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    GPSDetailView(horizontalAccuracy: 6, verticalAccuracy: 10)
}
