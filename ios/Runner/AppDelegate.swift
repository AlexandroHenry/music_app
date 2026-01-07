// import UIKit
// import Flutter
// import MediaPlayer

// @main
// @objc class AppDelegate: FlutterAppDelegate {
//     private var eventSink: FlutterEventSink?
//     private var musicChannel: FlutterMethodChannel?
    
//     override func application(
//         _ application: UIApplication,
//         didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
//     ) -> Bool {
        
//         GeneratedPluginRegistrant.register(with: self)
        
//         // Window가 준비된 후에 채널 설정
//         DispatchQueue.main.async { [weak self] in
//             self?.setupFlutterChannels()
//         }
        
//         // Now Playing Info 변경 감지
//         setupNowPlayingObserver()
        
//         // Remote Command 활성화
//         setupRemoteCommands()
        
//         return super.application(application, didFinishLaunchingWithOptions: launchOptions)
//     }
    
//     private func setupFlutterChannels() {
//         guard let controller = window?.rootViewController as? FlutterViewController else {
//             return
//         }
        
//         // Method Channel 설정
//         musicChannel = FlutterMethodChannel(
//             name: "com.yourapp/music_control",
//             binaryMessenger: controller.binaryMessenger
//         )
        
//         musicChannel?.setMethodCallHandler { [weak self] (call, result) in
//             self?.handleMethodCall(call, result: result)
//         }
        
//         // Event Channel 설정
//         let eventChannel = FlutterEventChannel(
//             name: "com.yourapp/music_events",
//             binaryMessenger: controller.binaryMessenger
//         )
        
//         eventChannel.setStreamHandler(self)
//     }
    
//     private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//         switch call.method {
//         case "getNowPlayingInfo":
//             getNowPlayingInfo(result: result)
//         case "togglePlayPause":
//             togglePlayPause(result: result)
//         case "nextTrack":
//             nextTrack(result: result)
//         case "previousTrack":
//             previousTrack(result: result)
//         case "seek":
//             if let args = call.arguments as? [String: Any],
//                let seconds = args["seconds"] as? Double {
//                 seek(seconds: seconds, result: result)
//             } else {
//                 result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid seek argument", details: nil))
//             }
//         default:
//             result(FlutterMethodNotImplemented)
//         }
//     }
    
//     private func getNowPlayingInfo(result: @escaping FlutterResult) {
//         let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
//         guard let nowPlayingItem = musicPlayer.nowPlayingItem else {
//             result(nil)
//             return
//         }
        
//         var info: [String: Any] = [:]
        
//         // 곡 정보
//         if let title = nowPlayingItem.title {
//             info["title"] = title
//         }
//         if let artist = nowPlayingItem.artist {
//             info["artist"] = artist
//         }
//         if let album = nowPlayingItem.albumTitle {
//             info["album"] = album
//         }
        
//         // 재생 시간
//         info["duration"] = nowPlayingItem.playbackDuration
//         info["currentTime"] = musicPlayer.currentPlaybackTime
        
//         // 앨범 아트 (썸네일)
//         if let artwork = nowPlayingItem.artwork {
//             let image = artwork.image(at: CGSize(width: 300, height: 300))
//             if let imageData = image?.pngData() {
//                 info["thumbnail"] = FlutterStandardTypedData(bytes: imageData)
//             }
//         }
        
//         // 재생 상태
//         info["isPlaying"] = musicPlayer.playbackState == .playing
        
//         result(info)
//     }
    
//     private func togglePlayPause(result: @escaping FlutterResult) {
//         let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
//         if musicPlayer.playbackState == .playing {
//             musicPlayer.pause()
//         } else {
//             musicPlayer.play()
//         }
        
//         result(nil)
//     }
    
//     private func nextTrack(result: @escaping FlutterResult) {
//         let musicPlayer = MPMusicPlayerController.systemMusicPlayer
//         musicPlayer.skipToNextItem()
//         result(nil)
//     }
    
//     private func previousTrack(result: @escaping FlutterResult) {
//         let musicPlayer = MPMusicPlayerController.systemMusicPlayer
//         musicPlayer.skipToPreviousItem()
//         result(nil)
//     }
    
//     private func seek(seconds: Double, result: @escaping FlutterResult) {
//         let musicPlayer = MPMusicPlayerController.systemMusicPlayer
//         musicPlayer.currentPlaybackTime = seconds
//         result(nil)
//     }
    
//     private func setupNowPlayingObserver() {
//         let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
//         // 재생 중인 음악 변경 감지
//         NotificationCenter.default.addObserver(
//             self,
//             selector: #selector(nowPlayingItemChanged),
//             name: .MPMusicPlayerControllerNowPlayingItemDidChange,
//             object: musicPlayer
//         )
        
//         NotificationCenter.default.addObserver(
//             self,
//             selector: #selector(playbackStateChanged),
//             name: .MPMusicPlayerControllerPlaybackStateDidChange,
//             object: musicPlayer
//         )
        
//         musicPlayer.beginGeneratingPlaybackNotifications()
//     }
    
//     @objc private func nowPlayingItemChanged() {
//         sendMusicInfoToFlutter()
//     }
    
//     @objc private func playbackStateChanged() {
//         sendMusicInfoToFlutter()
//     }
    
//     private func sendMusicInfoToFlutter() {
//         getNowPlayingInfo { [weak self] info in
//             if let info = info as? [String: Any] {
//                 self?.eventSink?(info)
//             }
//         }
//     }
    
//     private func setupRemoteCommands() {
//         let commandCenter = MPRemoteCommandCenter.shared()
        
//         // 필요한 명령어들을 활성화
//         commandCenter.playCommand.isEnabled = true
//         commandCenter.pauseCommand.isEnabled = true
//         commandCenter.nextTrackCommand.isEnabled = true
//         commandCenter.previousTrackCommand.isEnabled = true
//         commandCenter.changePlaybackPositionCommand.isEnabled = true
        
//         // 명령어 핸들러 추가
//         commandCenter.playCommand.addTarget { [weak self] _ in
//             let musicPlayer = MPMusicPlayerController.systemMusicPlayer
//             musicPlayer.play()
//             self?.sendMusicInfoToFlutter()
//             return .success
//         }
        
//         commandCenter.pauseCommand.addTarget { [weak self] _ in
//             let musicPlayer = MPMusicPlayerController.systemMusicPlayer
//             musicPlayer.pause()
//             self?.sendMusicInfoToFlutter()
//             return .success
//         }
        
//         commandCenter.nextTrackCommand.addTarget { [weak self] _ in
//             let musicPlayer = MPMusicPlayerController.systemMusicPlayer
//             musicPlayer.skipToNextItem()
//             self?.sendMusicInfoToFlutter()
//             return .success
//         }
        
//         commandCenter.previousTrackCommand.addTarget { [weak self] _ in
//             let musicPlayer = MPMusicPlayerController.systemMusicPlayer
//             musicPlayer.skipToPreviousItem()
//             self?.sendMusicInfoToFlutter()
//             return .success
//         }
        
//         commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
//             if let event = event as? MPChangePlaybackPositionCommandEvent {
//                 let musicPlayer = MPMusicPlayerController.systemMusicPlayer
//                 musicPlayer.currentPlaybackTime = event.positionTime
//                 self?.sendMusicInfoToFlutter()
//                 return .success
//             }
//             return .commandFailed
//         }
//     }
// }

// // Event Channel Stream Handler
// extension AppDelegate: FlutterStreamHandler {
//     func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
//         self.eventSink = events
//         return nil
//     }
    
//     func onCancel(withArguments arguments: Any?) -> FlutterError? {
//         self.eventSink = nil
//         return nil
//     }
// }

import UIKit
import Flutter
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var eventSink: FlutterEventSink?
    private var musicChannel: FlutterMethodChannel?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        GeneratedPluginRegistrant.register(with: self)
        
        // Window가 준비된 후에 채널 설정
        DispatchQueue.main.async { [weak self] in
            self?.setupFlutterChannels()
        }
        
        // Now Playing Info 변경 감지
        setupNowPlayingObserver()
        
        // Remote Command 활성화
        setupRemoteCommands()
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    private func setupFlutterChannels() {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            return
        }
        
        // Method Channel 설정
        musicChannel = FlutterMethodChannel(
            name: "com.yourapp/music_control",
            binaryMessenger: controller.binaryMessenger
        )
        
        musicChannel?.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }
        
        // Event Channel 설정
        let eventChannel = FlutterEventChannel(
            name: "com.yourapp/music_events",
            binaryMessenger: controller.binaryMessenger
        )
        
        eventChannel.setStreamHandler(self)
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
    
    private func getNowPlayingInfo(result: @escaping FlutterResult) {
        // MPNowPlayingInfoCenter에서 정보 가져오기 (더 신뢰성 있음)
        let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        guard let info = nowPlayingInfo else {
            // Fallback: MPMusicPlayerController 시도
            if let nowPlayingItem = musicPlayer.nowPlayingItem {
                result(extractInfoFromMusicPlayerItem(nowPlayingItem, musicPlayer: musicPlayer))
            } else {
                result(nil)
            }
            return
        }
        
        var trackInfo: [String: Any] = [:]
        
        // 곡 정보
        if let title = info[MPMediaItemPropertyTitle] as? String {
            trackInfo["title"] = title
        }
        if let artist = info[MPMediaItemPropertyArtist] as? String {
            trackInfo["artist"] = artist
        }
        if let album = info[MPMediaItemPropertyAlbumTitle] as? String {
            trackInfo["album"] = album
        }
        
        // 재생 시간
        if let duration = info[MPMediaItemPropertyPlaybackDuration] as? Double {
            trackInfo["duration"] = duration
        }
        if let currentTime = info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double {
            trackInfo["currentTime"] = currentTime
        } else {
            trackInfo["currentTime"] = musicPlayer.currentPlaybackTime
        }
        
        // 앨범 아트 - MPNowPlayingInfoCenter에서 가져오기
        if let artwork = info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
            let image = artwork.image(at: CGSize(width: 512, height: 512))
            if let imageData = image?.jpegData(compressionQuality: 0.8) {
                trackInfo["thumbnail"] = FlutterStandardTypedData(bytes: imageData)
                print("✅ Thumbnail loaded from MPNowPlayingInfoCenter: \(imageData.count) bytes")
            }
        } else {
            // Fallback: MPMusicPlayerController에서 가져오기
            if let nowPlayingItem = musicPlayer.nowPlayingItem,
               let artwork = nowPlayingItem.artwork {
                let image = artwork.image(at: CGSize(width: 512, height: 512))
                if let imageData = image?.jpegData(compressionQuality: 0.8) {
                    trackInfo["thumbnail"] = FlutterStandardTypedData(bytes: imageData)
                    print("✅ Thumbnail loaded from MPMusicPlayerController: \(imageData.count) bytes")
                }
            } else {
                print("❌ No thumbnail available")
            }
        }
        
        // 재생 상태
        if let playbackRate = info[MPNowPlayingInfoPropertyPlaybackRate] as? Double {
            trackInfo["isPlaying"] = playbackRate > 0
        } else {
            trackInfo["isPlaying"] = musicPlayer.playbackState == .playing
        }
        
        result(trackInfo)
    }
    
    private func extractInfoFromMusicPlayerItem(_ item: MPMediaItem, musicPlayer: MPMusicPlayerController) -> [String: Any] {
        var info: [String: Any] = [:]
        
        if let title = item.title {
            info["title"] = title
        }
        if let artist = item.artist {
            info["artist"] = artist
        }
        if let album = item.albumTitle {
            info["album"] = album
        }
        
        info["duration"] = item.playbackDuration
        info["currentTime"] = musicPlayer.currentPlaybackTime
        
        if let artwork = item.artwork {
            let image = artwork.image(at: CGSize(width: 512, height: 512))
            if let imageData = image?.jpegData(compressionQuality: 0.8) {
                info["thumbnail"] = FlutterStandardTypedData(bytes: imageData)
                print("✅ Thumbnail from item: \(imageData.count) bytes")
            }
        }
        
        info["isPlaying"] = musicPlayer.playbackState == .playing
        
        return info
    }
    
    private func togglePlayPause(result: @escaping FlutterResult) {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        if musicPlayer.playbackState == .playing {
            musicPlayer.pause()
        } else {
            musicPlayer.play()
        }
        
        // Now Playing Info 업데이트
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.sendMusicInfoToFlutter()
        }
        
        result(nil)
    }
    
    private func nextTrack(result: @escaping FlutterResult) {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        musicPlayer.skipToNextItem()
        
        // 곡 변경 후 정보 업데이트
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendMusicInfoToFlutter()
        }
        
        result(nil)
    }
    
    private func previousTrack(result: @escaping FlutterResult) {
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        musicPlayer.skipToPreviousItem()
        
        // 곡 변경 후 정보 업데이트
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
        
        // 재생 중인 음악 변경 감지
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
        
        // MPNowPlayingInfoCenter 변경 감지 (더 정확함)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingInfoChanged),
            name: NSNotification.Name("MPNowPlayingInfoDidChange"),
            object: nil
        )
        
        musicPlayer.beginGeneratingPlaybackNotifications()
    }
    
    @objc private func nowPlayingItemChanged() {
        print("🎵 Now playing item changed")
        sendMusicInfoToFlutter()
    }
    
    @objc private func playbackStateChanged() {
        print("▶️ Playback state changed")
        sendMusicInfoToFlutter()
    }
    
    @objc private func nowPlayingInfoChanged() {
        print("ℹ️ Now playing info changed")
        sendMusicInfoToFlutter()
    }
    
    private func sendMusicInfoToFlutter() {
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
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            let musicPlayer = MPMusicPlayerController.systemMusicPlayer
            musicPlayer.play()
            self?.sendMusicInfoToFlutter()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            let musicPlayer = MPMusicPlayerController.systemMusicPlayer
            musicPlayer.pause()
            self?.sendMusicInfoToFlutter()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            let musicPlayer = MPMusicPlayerController.systemMusicPlayer
            musicPlayer.skipToNextItem()
            self?.sendMusicInfoToFlutter()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            let musicPlayer = MPMusicPlayerController.systemMusicPlayer
            musicPlayer.skipToPreviousItem()
            self?.sendMusicInfoToFlutter()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent {
                let musicPlayer = MPMusicPlayerController.systemMusicPlayer
                musicPlayer.currentPlaybackTime = event.positionTime
                self?.sendMusicInfoToFlutter()
                return .success
            }
            return .commandFailed
        }
    }
}

// Event Channel Stream Handler
extension AppDelegate: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}