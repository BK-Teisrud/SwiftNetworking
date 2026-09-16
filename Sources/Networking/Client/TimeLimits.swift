import Foundation

/// One day is a deliberate practical maximum, comfortably representable as Duration.
enum TimeLimits {
  static let maximum: TimeInterval = 86_400
  static func valid(_ value: TimeInterval, allowZero: Bool = false) -> Bool {
    value.isFinite && value <= maximum && (allowZero ? value >= 0 : value > 0)
  }
}
