import Foundation

/// Made-up but realistic constellations, for screenshots and tests when no real orbits are at hand.
enum SampleOrbits {
    static func elements(epoch: Date = Date()) -> [OrbitalElements] {
        var result: [OrbitalElements] = []
        func add(_ name: String, _ id: Int, n: Double, i: Double, raan: Double, anomaly: Double) {
            result.append(OrbitalElements(name: name, noradID: id, epoch: epoch, meanMotion: n, eccentricity: 0.005,
                                          inclination: i, rightAscension: raan, argumentOfPerigee: 0, meanAnomaly: anomaly))
        }
        // GPS: 6 planes of 4.
        for plane in 0..<6 {
            for slot in 0..<4 {
                let prn = plane * 4 + slot + 1
                add("GPS SAMPLE (PRN \(String(format: "%02d", prn)))", 90000 + prn, n: 2.00562, i: 55,
                    raan: Double(plane) * 60, anomaly: Double(slot) * 90 + Double(plane) * 15)
            }
        }
        // Galileo: 3 planes of 8.
        for plane in 0..<3 {
            for slot in 0..<8 {
                let number = 200 + plane * 8 + slot
                add("GSAT0\(number) (GALILEO SAMPLE)", 91000 + number, n: 1.70475, i: 56,
                    raan: Double(plane) * 120 + 20, anomaly: Double(slot) * 45 + Double(plane) * 15)
            }
        }
        // GLONASS: 3 planes of 8.
        for plane in 0..<3 {
            for slot in 0..<8 {
                let number = 730 + plane * 8 + slot
                add("COSMOS SAMPLE (\(number))", 92000 + number, n: 2.13102, i: 64.8,
                    raan: Double(plane) * 120 + 50, anomaly: Double(slot) * 45 + Double(plane) * 15)
            }
        }
        // BeiDou: 3 planes of 8 medium orbits.
        for plane in 0..<3 {
            for slot in 0..<8 {
                let number = 19 + plane * 8 + slot
                add("BEIDOU-3 SAMPLE (C\(number))", 93000 + number, n: 1.86231, i: 55,
                    raan: Double(plane) * 120 + 80, anomaly: Double(slot) * 45 + Double(plane) * 15)
            }
        }
        return result
    }
}
