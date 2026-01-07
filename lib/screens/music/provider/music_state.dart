import 'dart:typed_data';

class MusicState {
  static const _unset = Object();

  const MusicState({
    required this.isLoading,
    this.errorMessage,
    this.currentTrack,
    this.cachedThumbnail,
    this.cachedTrackId,
  });

  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic>? currentTrack;
  final Uint8List? cachedThumbnail;
  final String? cachedTrackId;

  MusicState copyWith({
    bool? isLoading,
    Object? errorMessage = _unset,
    Map<String, dynamic>? currentTrack,
    Uint8List? cachedThumbnail,
    String? cachedTrackId,
  }) {
    return MusicState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage == _unset ? this.errorMessage : errorMessage as String?,
      currentTrack: currentTrack ?? this.currentTrack,
      cachedThumbnail: cachedThumbnail ?? this.cachedThumbnail,
      cachedTrackId: cachedTrackId ?? this.cachedTrackId,
    );
  }

  static const initial = MusicState(isLoading: true);
}