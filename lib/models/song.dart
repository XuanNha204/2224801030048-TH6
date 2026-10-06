class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.url,
    required this.coverUrl,
    required this.genre,
  });
  final String id;
  final String title;
  final String artist;
  final String url;
  final String coverUrl;
  final String genre;
  bool matches(String query) =>
      normalize('$title $artist $genre').contains(normalize(query.trim()));
  static String normalize(String value) {
    var result = value.toLowerCase();
    const groups = {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    };
    groups.forEach((key, letters) {
      for (final letter in letters.split('')) {
        result = result.replaceAll(letter, key);
      }
    });
    return result;
  }
}

class MusicPlaylist {
  MusicPlaylist({required this.id, required this.name, List<String>? songIds})
    : songIds = List.of(songIds ?? []);
  final String id;
  final String name;
  final List<String> songIds;
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'songIds': songIds};
  factory MusicPlaylist.fromJson(Map<String, dynamic> json) => MusicPlaylist(
    id: json['id'] as String,
    name: json['name'] as String,
    songIds: List<String>.from(json['songIds'] as List? ?? []),
  );
}
