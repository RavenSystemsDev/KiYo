import Foundation
import Darwin

// A process-owned lock works across installed, DMG and translocated copies.
// Never unlink the lock file: another process may already have it open.
final class SingleInstanceLock {
    private let descriptor: Int32
    private init(descriptor: Int32) { self.descriptor = descriptor }
    deinit { close(descriptor) }

    static func acquire(directory: URL? = nil) throws -> SingleInstanceLock? {
        let folder = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("local.kiyo.switchet", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var folderInfo = stat()
        guard lstat(folder.path, &folderInfo) == 0, folderInfo.st_mode & S_IFMT == S_IFDIR, folderInfo.st_uid == getuid() else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))
        }
        let fd = open(folder.appendingPathComponent("instance.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG, info.st_uid == getuid() else {
            close(fd)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))
        }
        guard lockf(fd, F_TLOCK, 0) == 0 else {
            let failure = errno
            close(fd)
            if failure == EAGAIN || failure == EACCES { return nil }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(failure))
        }
        return SingleInstanceLock(descriptor: fd)
    }
}
