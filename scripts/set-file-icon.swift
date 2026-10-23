import AppKit
let args = CommandLine.arguments
guard args.count == 3, let icon = NSImage(contentsOfFile: args[1]) else { exit(1) }
guard NSWorkspace.shared.setIcon(icon, forFile: args[2], options: []) else { exit(2) }
print("File icon applied")
