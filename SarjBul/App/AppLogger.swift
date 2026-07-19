import OSLog

enum AppLogger {
    static let data = Logger(subsystem: "com.ozdemirbaris.sarjbul", category: "data")
    static let account = Logger(subsystem: "com.ozdemirbaris.sarjbul", category: "account")
    static let routing = Logger(subsystem: "com.ozdemirbaris.sarjbul", category: "routing")
}
