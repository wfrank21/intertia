import SwiftUI

/// Analoges Stoppuhr-Zifferblatt (60-Sekunden-Skala) als visuelle Ergänzung
/// zur digitalen Zeitanzeige in `ResultShareCardView`. Der Zeiger zeigt auf
/// die gemessene Zeit (`seconds`); bei Zeiten über einer Minute läuft der
/// Zeiger entsprechend mehrfach um das Zifferblatt (`seconds` wird modulo
/// 60 genommen), wie bei einer klassischen mechanischen Stoppuhr.
///
/// Positionierung von Strichen/Zeiger nutzt bewusst den etablierten SwiftUI-
/// Kniff `.offset(y: -radius).rotationEffect(.degrees(angle))`: Da
/// `rotationEffect` standardmäßig um den (unverschobenen) Mittelpunkt des
/// Layout-Slots rotiert, "kreist" der bereits nach oben versetzte Strich so
/// exakt um den Zifferblatt-Mittelpunkt. Für die Zifferblatt-Zahlen wird
/// zusätzlich vorab gegenrotiert, damit die Ziffern selbst aufrecht bleiben.
struct StopwatchDialView: View {
    let seconds: Double
    var diameter: CGFloat = 92

    private var displaySeconds: Double {
        let m = seconds.truncatingRemainder(dividingBy: 60)
        return m < 0 ? m + 60 : m
    }

    private var handAngleDegrees: Double {
        displaySeconds / 60 * 360
    }

    private static let majorMarks = [0, 15, 30, 45]

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.systemBackground))
            Circle()
                .stroke(Color.secondary.opacity(0.5), lineWidth: 1.5)

            ForEach(0..<60, id: \.self) { index in
                tick(for: index)
            }

            ForEach(Self.majorMarks, id: \.self) { major in
                numberLabel(for: major)
            }

            // Zeiger
            Capsule()
                .fill(Color.accentColor)
                .frame(width: 2.5, height: diameter * 0.36)
                .offset(y: -diameter * 0.18)
                .rotationEffect(.degrees(handAngleDegrees))

            Circle()
                .fill(Color.accentColor)
                .frame(width: 6, height: 6)
        }
        .frame(width: diameter, height: diameter)
    }

    private func tick(for index: Int) -> some View {
        let isMajor = index % 5 == 0
        let length = isMajor ? diameter * 0.10 : diameter * 0.05
        return Capsule()
            .fill(isMajor ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.5))
            .frame(width: isMajor ? 2 : 1, height: length)
            .offset(y: -(diameter / 2) + length / 2 + 1)
            .rotationEffect(.degrees(Double(index) / 60 * 360))
    }

    private func numberLabel(for major: Int) -> some View {
        let angle = Double(major) / 60 * 360
        return Text("\(major)")
            .font(.system(size: diameter * 0.11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .rotationEffect(.degrees(-angle))
            .offset(y: -diameter * 0.32)
            .rotationEffect(.degrees(angle))
    }
}

#Preview {
    StopwatchDialView(seconds: 5.43)
        .padding()
}
