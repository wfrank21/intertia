import SwiftUI

/// Eigener Tab zur Verwaltung der vom Nutzer angelegten Fahrzeuge. Ein
/// Fahrzeug kann als Standard markiert werden (Stern), wird dann automatisch
/// bei neuen Messungen vorausgewählt (siehe `MeasurementView`).
struct VehicleListView: View {
    @ObservedObject private var store = VehicleStore.shared
    @AppStorage("appLanguage") private var appLanguage: AppLanguage = .auto
    @State private var editingVehicle: Vehicle?
    @State private var showAddSheet = false

    private var locale: Locale { appLanguage.resolvedLocale }

    var body: some View {
        NavigationStack {
            Group {
                if store.vehicles.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "car.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Noch keine Fahrzeuge")
                            .font(.headline)
                        Text("Füge dein Auto hinzu, um es Messungen zuzuordnen.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(store.vehicles) { vehicle in
                            Button {
                                editingVehicle = vehicle
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(vehicle.displayName)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        if let subtitle = subtitle(for: vehicle) {
                                            Text(subtitle)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if vehicle.isDefault {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                            .accessibilityLabel(Text("Standardfahrzeug"))
                                    }
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                if !vehicle.isDefault {
                                    Button {
                                        store.setDefault(vehicle)
                                    } label: {
                                        Label("Standardfahrzeug", systemImage: "star")
                                    }
                                    .tint(.yellow)
                                }
                            }
                        }
                        .onDelete(perform: store.delete)
                    }
                }
            }
            .navigationTitle("Fahrzeuge")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                VehicleEditView(vehicle: nil)
            }
            .sheet(item: $editingVehicle) { vehicle in
                VehicleEditView(vehicle: vehicle)
            }
        }
    }

    private func subtitle(for vehicle: Vehicle) -> String? {
        var parts: [String] = []
        if let year = vehicle.year { parts.append(String(year)) }
        if let hp = vehicle.horsepowerPS {
            parts.append(String(format: String(localized: "%d PS", locale: locale), hp))
        }
        if let plate = vehicle.licensePlate, !plate.isEmpty {
            parts.append(plate)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

#Preview {
    VehicleListView()
}
