import Foundation
import Darwin

func runInstanceProbe() {
    guard let index = CommandLine.arguments.firstIndex(of: "--instance-probe"), CommandLine.arguments.count > index + 2 else { exit(4) }
    do {
        guard let instance = try SingleInstanceLock.acquire(directory: URL(fileURLWithPath: CommandLine.arguments[index + 1])) else { exit(2) }
        withExtendedLifetime(instance) {
            FileHandle.standardOutput.write(Data("acquired\n".utf8))
            if CommandLine.arguments[index + 2] == "hold" { _ = readLine() }
        }
    } catch { exit(3) }
}

func runLaunchTests() {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("kiyo-launch-tests-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: folder) }
    func probe(_ directory: URL, hold: Bool = false) -> (Process, Pipe, Pipe) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        process.arguments = ["--instance-probe", directory.path, hold ? "hold" : "once"]
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        try! process.run()
        return (process, input, output)
    }
    func holding() -> (Process, Pipe) {
        let (process, input, output) = probe(folder, hold: true)
        let ready = output.fileHandleForReading.readData(ofLength: 9)
        assert(String(data: ready, encoding: .utf8) == "acquired\n")
        return (process, input)
    }
    let (owner, input) = holding()
    for _ in 0..<8 {
        let (other, _, _) = probe(folder)
        other.waitUntilExit()
        assert(other.terminationStatus == 2, "A second process acquired the instance lock")
    }
    input.fileHandleForWriting.closeFile()
    owner.waitUntilExit()
    assert(owner.terminationStatus == 0)
    let (restart, _, _) = probe(folder)
    restart.waitUntilExit()
    assert(restart.terminationStatus == 0, "Clean exit left a stale lock")
    let (crashed, crashInput) = holding()
    kill(crashed.processIdentifier, SIGKILL)
    crashed.waitUntilExit()
    crashInput.fileHandleForWriting.closeFile()
    let (recovered, _, _) = probe(folder)
    recovered.waitUntilExit()
    assert(recovered.terminationStatus == 0, "Abnormal exit left a stale lock")

    let unsafe = folder.appendingPathComponent("unsafe")
    try! FileManager.default.createDirectory(at: unsafe, withIntermediateDirectories: true)
    let target = folder.appendingPathComponent("untouched.txt")
    try! Data("untouched".utf8).write(to: target)
    try! FileManager.default.createSymbolicLink(at: unsafe.appendingPathComponent("instance.lock"), withDestinationURL: target)
    let (symlink, _, _) = probe(unsafe)
    symlink.waitUntilExit()
    assert(symlink.terminationStatus == 3)
    assert((try! String(contentsOf: target, encoding: .utf8)) == "untouched")
    print("Launch checks passed: concurrent copies excluded; lock released after normal exit and crash; symlink rejected.")
}
