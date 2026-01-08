import UIKit
import Flutter
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var eventSink: FlutterEventSink?
    private var musicChannel: FlutterMethodChannel?
    private var pollingTimer: Timer?
    private var lastTrackId: String?
    private var lastSourceApp: String?
    
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
        requestMediaLibraryAccess()
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func requestMediaLibraryAccess() {
        MPMediaLibrary.requestAuthorization { status in
            print("📚 Media library: \(status.rawValue)")
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
        print("✅ Channels setup")
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
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func startPolling() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkTrackChanged()
        }
        print("✅ Polling started")
    }
    
    private func checkTrackChanged() {
        let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
        
        var currentTitle = ""
        var currentArtist = ""
        var currentSource = "unknown"
        
        if let info = nowPlayingInfo {
            currentTitle = info[MPMediaItemPropertyTitle] as? String ?? ""
            currentArtist = info[MPMediaItemPropertyArtist] as? String ?? ""
            currentSource = "NowPlayingInfo"
        } else {
            if let item = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem {
                currentTitle = item.title ?? ""
                currentArtist = item.artist ?? ""
                currentSource = "MusicPlayer"
            }
        }
        
        let currentTrackId = "\(currentTitle)_\(currentArtist)"
        
        if (currentTrackId != lastTrackId || currentSource != lastSourceApp) && !currentTrackId.isEmpty {
            print("🔄 Changed: \(currentTitle) from \(currentSource)")
            lastTrackId = currentTrackId
            lastSourceApp = currentSource
            sendMusicInfoToFlutter()
        }
    }
    
    private func getNowPlayingInfo(result: @escaping FlutterResult) {
        print("📱 getNowPlayingInfo")
        
        let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        var trackInfo: [String: Any] = [:]
        var hasData = false
        
        if let info = nowPlayingInfo {
            print("📋 Using NowPlayingInfo")
            
            trackInfo["title"] = info[MPMediaItemPropertyTitle] as? String ?? "Unknown"
            trackInfo["artist"] = info[MPMediaItemPropertyArtist] as? String ?? "Unknown Artist"
            trackInfo["album"] = info[MPMediaItemPropertyAlbumTitle] as? String ?? "Unknown Album"
            trackInfo["duration"] = info[MPMediaItemPropertyPlaybackDuration] as? Double ?? 0.0
            trackInfo["currentTime"] = info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double ?? musicPlayer.currentPlaybackTime
            
            let playbackRate = info[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0.0
            trackInfo["isPlaying"] = playbackRate > 0
            
            hasData = true
            
            if let artwork = info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
                if let thumbnail = extractThumbnail(artwork) {
                    trackInfo["thumbnail"] = thumbnail
                    print("✅ Thumbnail OK")
                }
            }
        }
        
        if !hasData, let item = musicPlayer.nowPlayingItem {
            print("📋 Using MusicPlayer")
            
            trackInfo["title"] = item.title ?? "Unknown"
            trackInfo["artist"] = item.artist ?? "Unknown Artist"
            trackInfo["album"] = item.albumTitle ?? "Unknown Album"
            trackInfo["duration"] = item.playbackDuration
            trackInfo["currentTime"] = musicPlayer.currentPlaybackTime
            trackInfo["isPlaying"] = musicPlayer.playbackState == .playing
            hasData = true
            
            if let artwork = item.artwork {
                if let thumbnail = extractThumbnail(artwork) {
                    trackInfo["thumbnail"] = thumbnail
                    print("✅ Thumbnail OK")
                }
            }
        }
        
        if hasData {
            print("✅ Returning track")
            result(trackInfo)
        } else {
            print("❌ No data")
            result(nil)
        }
    }
    
    private func extractThumbnail(_ artwork: MPMediaItemArtwork) -> FlutterStandardTypedData? {
        // bounds 사용
        if let image = artwork.image(at: artwork.bounds.size) {
            if let data = compressImage(image) {
                return data
            }
        }
        
        // 여러 크기 시도
        let sizes: [CGSize] = [
            CGSize(width: 600, height: 600),
            CGSize(width: 512, height: 512),
            CGSize(width: 300, height: 300),
        ]
        
        for size in sizes {
            if let image = artwork.image(at: size) {
                if let data = compressImage(image) {
                    return data
                }
            }
        }
        
        return nil
    }
    
    private func compressImage(_ image: UIImage) -> FlutterStandardTypedData? {
        if let jpegData = image.jpegData(compressionQuality: 0.8) {
            return FlutterStandardTypedData(bytes: jpegData)
        }
        if let pngData = image.pngData() {
            return FlutterStandardTypedData(bytes: pngData)
        }
        return nil
    }
    
    private func togglePlayPause(result: @escaping FlutterResult) {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        if let info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
           let playbackRate = info[MPNowPlayingInfoPropertyPlaybackRate] as? Double {
            
            if playbackRate > 0 {
                musicPlayer.pause()
                print("⏸️ Paused")
            } else {
                musicPlayer.play()
                print("▶️ Playing")
            }
        } else {
            if musicPlayer.playbackState == .playing {
                musicPlayer.pause()
            } else {
                musicPlayer.play()
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.sendMusicInfoToFlutter()
        }
        
        result(nil)
    }
    
    private func nextTrack(result: @escaping FlutterResult) {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        musicPlayer.skipToNextItem()
        print("⏭️ Next")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.sendMusicInfoToFlutter()
        }
        
        result(nil)
    }
    
    private func previousTrack(result: @escaping FlutterResult) {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        musicPlayer.skipToPreviousItem()
        print("⏮️ Previous")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkTrackChanged()
        }
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self?.sendMusicInfoToFlutter()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            MPMusicPlayerController.systemMusicPlayer.skipToPreviousItem()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self?.sendMusicInfoToFlutter()
            }
            return .success
        }
    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        print("🔄 App active")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.checkTrackChanged()
        }
    }
    
    deinit {
        pollingTimer?.invalidate()
    }
}

extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("📡 Connected")
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