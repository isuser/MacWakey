import Foundation

// Wakey helper: a root launchd daemon that runs `pmset disablesleep` for the app and widget.
let service = HelperService()
service.start()

let delegate = ListenerDelegate(service: service)
let listener = NSXPCListener(machServiceName: WakeyIDs.helper)
listener.delegate = delegate
listener.resume()

dispatchMain()
