import UIKit
import Flutter
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var eventSink: FlutterEventSink?
    private var musicChannel: FlutterMethodChannel?
    private var pollingTimer: Timer?
    private var lastTrackId: String?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        GeneratedPluginRegistrant.register(with: self)
        
        DispatchQueue.main.async { [weak self] in
            self?.setupFlutterChannels()
        }
        
        setupNowPlayingObserver()
        setupRemoteCommands()
        startPolling()
        
        // 미디어 라이브러리 권한 요청
        requestMediaLibraryAccess()
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func requestMediaLibraryAccess() {
        MPMediaLibrary.requestAuthorization { status in
            switch status {
            case .authorized:
                print("✅ Media library access authorized")
            case .denied:
                print("❌ Media library access denied")
            case .restricted:
                print("⚠️ Media library access restricted")
            case .notDetermined:
                print("⚠️ Media library access not determined")
            @unknown default:
                print("⚠️ Unknown media library status")
            }
        }
    }
    
    private func setupFlutterChannels() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }
        
        musicChannel = FlutterMethodChannel(
            name: "com.yourapp/music_control",
            binaryMessenger: controller.binaryMessenger
        )
        
        musicChannel?.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }
        
        let eventChannel = FlutterEventChannel(
            name: "com.yourapp/music_events",
            binaryMessenger: controller.binaryMessenger
        )
        
        eventChannel.setStreamHandler(self)
        print("✅ Flutter channels setup complete")
    }
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getNowPlayingInfo":
            getNowPlayingInfo(result: result)
        case "togglePlayPause":
            togglePlayPause(result: result)
        case "nextTrack":
            nextTrack(result: result)
        case "previousTrack":
            previousTrack(result: result)
        case "seek":
            if let args = call.arguments as? [String: Any],
               let seconds = args["seconds"] as? Double {
                seek(seconds: seconds, result: result)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid seek argument", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkTrackChanged()
        }
    }
    
    private func checkTrackChanged() {
        guard let trackInfo = getCurrentTrackInfo() else {
            return
        }
        
        let currentTrackId = "\(trackInfo["title"] ?? "")_\(trackInfo["artist"] ?? "")"
        
        if currentTrackId != lastTrackId && !currentTrackId.isEmpty {
            print("🔄 Track changed: \(trackInfo["title"] ?? "Unknown")")
            lastTrackId = currentTrackId
            sendMusicInfoToFlutter()
        }
    }
    
    private func getCurrentTrackInfo() -> [String: Any]? {
        if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            return [
                "title": info[MPMediaItemPropertyTitle] as? String ?? "",
                "artist": info[MPMediaItemPropertyArtist] as? String ?? ""
            ]
        }
        
        if let item = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem {
            return [
                "title": item.title ?? "",
                "artist": item.artist ?? ""
            ]
        }
        
        return nil
    }
    
    private func getNowPlayingInfo(result: @escaping FlutterResult) {
        print("📱 getNowPlayingInfo called")
        
        let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        var trackInfo: [String: Any] = [:]
        var hasData = false
        
        // 기본 정보
        if let info = nowPlayingInfo {
            trackInfo["title"] = info[MPMediaItemPropertyTitle] as? String ?? "Unknown"
            trackInfo["artist"] = info[MPMediaItemPropertyArtist] as? String ?? "Unknown Artist"
            trackInfo["album"] = info[MPMediaItemPropertyAlbumTitle] as? String ?? "Unknown Album"
            trackInfo["duration"] = info[MPMediaItemPropertyPlaybackDuration] as? Double ?? 0.0
            trackInfo["currentTime"] = info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double ?? 0.0
            trackInfo["isPlaying"] = (info[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0.0) > 0
            hasData = true
            
            // 앨범 아트 시도
            if let artwork = info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
                if let thumbnail = extractThumbnailAlternative(artwork) {
                    trackInfo["thumbnail"] = thumbnail
                }
            }
        }
        
        // Fallback
        if !hasData, let item = musicPlayer.nowPlayingItem {
            trackInfo["title"] = item.title ?? "Unknown"
            trackInfo["artist"] = item.artist ?? "Unknown Artist"
            trackInfo["album"] = item.albumTitle ?? "Unknown Album"
            trackInfo["duration"] = item.playbackDuration
            trackInfo["currentTime"] = musicPlayer.currentPlaybackTime
            trackInfo["isPlaying"] = musicPlayer.playbackState == .playing
            hasData = true
            
            // 앨범 아트 시도
            if let artwork = item.artwork {
                if let thumbnail = extractThumbnailAlternative(artwork) {
                    trackInfo["thumbnail"] = thumbnail
                }
            }
        }
        
        if hasData {
            print("✅ Returning track info")
            if trackInfo["thumbnail"] != nil {
                print("✅ WITH thumbnail")
            } else {
                print("⚠️ WITHOUT thumbnail")
            }
            result(trackInfo)
        } else {
            print("❌ No music data")
            result(nil)
        }
    }
    
    // 대체 썸네일 추출 방법
    private func extractThumbnailAlternative(_ artwork: MPMediaItemArtwork) -> FlutterStandardTypedData? {
        print("🖼️ Attempting alternative thumbnail extraction...")
        
        // 방법 1: bounds 사용
        if let image = artwork.image(at: artwork.bounds.size) {
            print("✅ Got image using bounds: \(artwork.bounds.size)")
            if let data = compressImage(image) {
                return data
            }
        }
        
        // 방법 2: 고정 크기들 시도
        let sizes: [CGSize] = [
            CGSize(width: 1024, height: 1024),
            CGSize(width: 800, height: 800),
            CGSize(width: 600, height: 600),
            CGSize(width: 512, height: 512),
            CGSize(width: 400, height: 400),
            CGSize(width: 300, height: 300),
            CGSize(width: 256, height: 256),
            CGSize(width: 200, height: 200),
            CGSize(width: 128, height: 128),
            CGSize(width: 100, height: 100),
            CGSize(width: 64, height: 64)
        ]
        
        for size in sizes {
            if let image = artwork.image(at: size) {
                print("✅ Got image at size: \(size)")
                if let data = compressImage(image) {
                    return data
                }
            }
        }
        
        // 방법 3: 메인 스레드에서 시도
        var resultImage: UIImage?
        let semaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.main.async {
            resultImage = artwork.image(at: CGSize(width: 512, height: 512))
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let image = resultImage {
            print("✅ Got image on main thread")
            if let data = compressImage(image) {
                return data
            }
        }
        
        print("❌ All thumbnail extraction methods failed")
        return nil
    }
    
    private func compressImage(_ image: UIImage) -> FlutterStandardTypedData? {
        // JPEG 압축
        if let jpegData = image.jpegData(compressionQuality: 0.8) {
            print("✅ JPEG: \(jpegData.count) bytes")
            return FlutterStandardTypedData(bytes: jpegData)
        }
        
        // PNG 압축
        if let pngData = image.pngData() {
            print("✅ PNG: \(pngData.count) bytes")
            return FlutterStandardTypedData(bytes: pngData)
        }
        
        // 낮은 품질로 재시도
        if let jpegData = image.jpegData(compressionQuality: 0.5) {
            print("✅ JPEG (low): \(jpegData.count) bytes")
            return FlutterStandardTypedData(bytes: jpegData)
        }
        
        return nil
    }
    
    private func togglePlayPause(result: @escaping FlutterResult) {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        if musicPlayer.playbackState == .playing {
            musicPlayer.pause()
        } else {
            musicPlayer.play()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.sendMusicInfoToFlutter()
        }
        
        result(nil)
    }
    
    private func nextTrack(result: @escaping FlutterResult) {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        musicPlayer.skipToNextItem()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendMusicInfoToFlutter()
        }
        
        result(nil)
    }
    
    private func previousTrack(result: @escaping FlutterResult) {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        musicPlayer.skipToPreviousItem()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendMusicInfoToFlutter()
        }
        
        result(nil)
    }
    
    private func seek(seconds: Double, result: @escaping FlutterResult) {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        musicPlayer.currentPlaybackTime = seconds
        result(nil)
    }
    
    private func setupNowPlayingObserver() {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingItemChanged),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )
        
        musicPlayer.beginGeneratingPlaybackNotifications()
    }
    
    @objc private func nowPlayingItemChanged() {
        print("🎵 Item changed")
        if let trackInfo = getCurrentTrackInfo() {
            lastTrackId = "\(trackInfo["title"] ?? "")_\(trackInfo["artist"] ?? "")"
        }
        sendMusicInfoToFlutter()
    }
    
    @objc private func playbackStateChanged() {
        print("▶️ State changed")
        sendMusicInfoToFlutter()
    }
    
    private func sendMusicInfoToFlutter() {
        guard eventSink != nil else { return }
        
        getNowPlayingInfo { [weak self] info in
            if let info = info as? [String: Any] {
                self?.eventSink?(info)
            }
        }
    }
    
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            MPMusicPlayerController.systemMusicPlayer.play()
            self?.sendMusicInfoToFlutter()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            MPMusicPlayerController.systemMusicPlayer.pause()
            self?.sendMusicInfoToFlutter()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            MPMusicPlayerController.systemMusicPlayer.skipToNextItem()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.sendMusicInfoToFlutter()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            MPMusicPlayerController.systemMusicPlayer.skipToPreviousItem()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.sendMusicInfoToFlutter()
            }
            return .success
        }
    }
    
    deinit {
        pollingTimer?.invalidate()
    }
}

extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("📡 EventSink connected")
        self.eventSink = events
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendMusicInfoToFlutter()
        }
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}