class ApiConstants {
  static const String defaultBaseUrl = 'http://100.125.151.88:8000';
  static const String searchEndpoint = '/search';
  static const String streamEndpoint = '/stream';
  static const String suggestionsEndpoint = '/suggestions';
  static const String playlistEndpoint = '/playlist';
  static const String channelEndpoint = '/channel';
  static const String searchChannelsEndpoint = '/search_channels';
  static const String searchPlaylistsEndpoint = '/search_playlists';
  static const String homeFeedEndpoint = '/home_feed';
  static const String statusEndpoint = '/status';
  static const String cookiesEndpoint = '/cookies';
  static const String genreEndpoint = '/genre';
  static const String lyricsEndpoint = '/lyrics';

  static const Duration connectionTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 60);
}

class AppConstants {
  static const String appName = 'YouFree';
  static const int searchDelayMs = 500;
  static const int maxSearchResults = 10;
}