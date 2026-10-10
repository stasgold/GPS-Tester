import Foundation

/// Dilution of precision predicted from where the satellites are: how much the sky geometry
/// magnifies ranging errors into position errors (lower is better; under 1 is excellent).
struct DilutionOfPrecision: Equatable {
    var horizontal: Double
    var vertical: Double
    var position: Double
    /// Satellites above the mask that went into the solution.
    var satelliteCount: Int

    /// Elevation mask in degrees: receivers ignore satellites lower than this.
    static let mask = 10.0
    /// Typical smartphone range error (1σ, metres) used to turn HDOP into an expected accuracy.
    static let rangeError = 5.0
    /// iOS rarely reports better than this, whatever the geometry.
    static let accuracyFloor = 3.0

    /// Best horizontal accuracy (m) to expect in open sky with this geometry.
    var expectedAccuracy: Double { max(horizontal * Self.rangeError, Self.accuracyFloor) }

    /// Least-squares geometry with a separate receiver clock for each system, as multi-GNSS receivers solve it.
    /// SBAS satellites only carry corrections, so they are left out. Nil when there are too few satellites.
    static func predict(from satellites: [SatellitePosition], mask: Double = mask) -> DilutionOfPrecision? {
        let usable = satellites.filter { $0.elevation >= mask && $0.constellation != .other }
        let counts = Dictionary(grouping: usable, by: \.constellation).mapValues(\.count)
        // A system seen through a single satellite only pins its own clock, so it adds nothing.
        let systems = Constellation.allCases.filter { (counts[$0] ?? 0) >= 2 }
        let used = usable.filter { systems.contains($0.constellation) }
        let unknowns = 3 + systems.count
        guard used.count >= unknowns else { return nil }

        var normal = [[Double]](repeating: [Double](repeating: 0, count: unknowns), count: unknowns)
        for satellite in used {
            let az = satellite.azimuth * .pi / 180, el = satellite.elevation * .pi / 180
            var row = [-cos(el) * sin(az), -cos(el) * cos(az), -sin(el)]
            row += systems.map { $0 == satellite.constellation ? 1.0 : 0.0 }
            for i in 0..<unknowns {
                for j in 0..<unknowns { normal[i][j] += row[i] * row[j] }
            }
        }
        guard let q = invert(normal) else { return nil }
        let east = q[0][0], north = q[1][1], up = q[2][2]
        guard east >= 0, north >= 0, up >= 0 else { return nil }
        return DilutionOfPrecision(horizontal: (east + north).squareRoot(), vertical: up.squareRoot(),
                                   position: (east + north + up).squareRoot(), satelliteCount: used.count)
    }

    /// Gauss–Jordan inversion with partial pivoting; nil when the matrix is singular.
    static func invert(_ matrix: [[Double]]) -> [[Double]]? {
        let n = matrix.count
        var a = matrix
        var inverse = (0..<n).map { i in (0..<n).map { $0 == i ? 1.0 : 0.0 } }
        for column in 0..<n {
            guard let pivot = (column..<n).max(by: { abs(a[$0][column]) < abs(a[$1][column]) }),
                  abs(a[pivot][column]) > 1e-12 else { return nil }
            a.swapAt(column, pivot)
            inverse.swapAt(column, pivot)
            let scale = a[column][column]
            for k in 0..<n {
                a[column][k] /= scale
                inverse[column][k] /= scale
            }
            for row in 0..<n where row != column {
                let factor = a[row][column]
                if factor == 0 { continue }
                for k in 0..<n {
                    a[row][k] -= factor * a[column][k]
                    inverse[row][k] -= factor * inverse[column][k]
                }
            }
        }
        return inverse
    }
}

/// How open the sky looks, from the accuracy iOS reports against what the geometry should allow.
enum SkyView: Equatable {
    case open, partial, obstructed

    /// `reported` and `expected` are horizontal accuracies in metres.
    init(reported: Double, expected: Double) {
        let ratio = reported / max(expected, 0.1)
        switch ratio {
        case ..<2: self = .open
        case ..<5: self = .partial
        default: self = .obstructed
        }
    }

    var title: String {
        switch self {
        case .open: "Open sky"
        case .partial: "Partly blocked"
        case .obstructed: "Blocked"
        }
    }

    var explanation: String {
        switch self {
        case .open: "Accuracy is close to what the satellites overhead allow."
        case .partial: "Accuracy is worse than the geometry allows: buildings, trees or a roof may be blocking part of the sky."
        case .obstructed: "Accuracy is far worse than the geometry allows: most of the sky is probably blocked, or signals are reflecting."
        }
    }
}
