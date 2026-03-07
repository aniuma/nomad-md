import Foundation
import CoreServices

final class FileWatcher {
    private var streamRef: FSEventStreamRef?
    private var watchedPaths: [String] = []
    private var onChange: (([String]) -> Void)?
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.5

    func start(paths: [URL], onChange: @escaping ([String]) -> Void) {
        stop()
        guard !paths.isEmpty else { return }

        self.watchedPaths = paths.map { $0.path }
        self.onChange = onChange

        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        var fsContext = FSEventStreamContext(
            version: 0,
            info: context,
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, clientCallBackInfo, numEvents, eventPaths, _, _ in
            guard let info = clientCallBackInfo else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()

            var changed: [String] = []
            if let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] {
                changed = Array(paths.prefix(numEvents))
            }
            watcher.scheduleDebounce(changedPaths: changed)
        }

        let pathsToWatch = self.watchedPaths as CFArray
        streamRef = FSEventStreamCreate(
            nil,
            callback,
            &fsContext,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.3,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        )

        if let stream = streamRef {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        debounceTimer?.invalidate()
        debounceTimer = nil
        if let stream = streamRef {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            streamRef = nil
        }
        onChange = nil
    }

    func updatePaths(_ paths: [URL]) {
        let newPaths = paths.map { $0.path }
        guard newPaths != watchedPaths else { return }
        if let handler = onChange {
            start(paths: paths, onChange: handler)
        }
    }

    private func scheduleDebounce(changedPaths: [String]) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.debounceTimer?.invalidate()
            self.debounceTimer = Timer.scheduledTimer(withTimeInterval: self.debounceInterval, repeats: false) { [weak self] _ in
                self?.onChange?(changedPaths)
            }
        }
    }

    deinit {
        stop()
    }
}
