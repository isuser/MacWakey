import Foundation

/// Wrapper around /usr/bin/pmset. Reading works for any user; changing needs root.
enum Pmset {
    /// True when `pmset -g` reports `SleepDisabled 1`.
    static func isSleepDisabled() -> Bool {
        guard let output = run(["-g"]).output else { return false }
        for line in output.split(separator: "\n") where line.contains("SleepDisabled") {
            return line.split(whereSeparator: { $0 == " " || $0 == "\t" }).last == "1"
        }
        return false
    }

    /// Runs `pmset -a disablesleep 1|0`. Returns an error message, or nil on success.
    static func setSleepDisabled(_ disabled: Bool) -> String? {
        let result = run(["-a", "disablesleep", disabled ? "1" : "0"])
        if result.status == 0 { return nil }
        return "pmset failed: \(result.output ?? "unknown error")"
    }

    private static func run(_ arguments: [String]) -> (status: Int32, output: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: data, encoding: .utf8))
    }
}
