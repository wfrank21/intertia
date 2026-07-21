import SwiftUI

struct HistoryView: View {
    @ObservedObject private var store = ResultStore.shared
    @AppStorage("speedUnit") private var speedUnit: SpeedUnit = .kmh

    var body: some View {
        NavigationStack {
            Group {
                if store.results.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Noch keine Messungen")
                            .font(.headline)
                        Text("Starte auf dem Reiter „Messung“ deine erste Beschleunigungsmessung.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(store.results) { result in
                            NavigationLink(value: result) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.displayName(unit: speedUnit))
                                        .font(.headline)
                                    Text(String(format: "%.2f s · %@", result.elapsedSeconds, result.date.formatted(date: .abbreviated, time: .shortened)))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let vehicleDisplayName = result.vehicleDisplayName {
                                        Text(vehicleDisplayName)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: store.delete)
                    }
                }
            }
            .navigationTitle("Verlauf")
            .navigationDestination(for: MeasurementResult.self) { result in
                ResultDetailView(result: result)
            }
        }
    }
}

struct ResultDetailView: View {
    let result: MeasurementResult

    @AppStorage("speedUnit") private var speedUnit: SpeedUnit = .kmh

    var body: some View {
        ScrollView {
            ResultSummaryView(result: result)
                .padding()
        }
        .navigationTitle(result.displayName(unit: speedUnit))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HistoryView()
}
