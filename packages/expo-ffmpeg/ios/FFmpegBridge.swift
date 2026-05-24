import Foundation

/// Bridge to FFmpeg C library via ObjC wrapper
class FFmpegBridge {

    /// Get FFmpeg version string
    static func getVersion() -> String {
        return FFmpegWrapper.versionInfo()
    }

    /// Set log callback for receiving FFmpeg log messages
    static func setLogCallback(
        callback: @escaping (Int32, String) -> Void
    ) {
        FFmpegWrapper.setLogCallback { level, message in
            callback(level, message)
        }
    }

    /// Clear the log callback
    static func clearLogCallback() {
        FFmpegWrapper.clearLogCallback()
    }

    /// Execute FFmpeg command
    static func execute(
        args: [String],
        logLevel: Int32,
        shouldCancel: @escaping () -> Bool,
        onProgress: ((Int64, Double, Double, Int, Double, Int64) -> Void)? = nil
    ) -> Int32 {
        return FFmpegWrapper.execute(
            withArgs: args,
            logLevel: logLevel,
            shouldCancel: shouldCancel,
            onProgress: { time, bitrate, speed, frame, fps, size in
                onProgress?(time, bitrate, speed, Int(frame), fps, size)
            }
        )
    }
}
