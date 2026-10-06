# Sonic — Ứng dụng nghe nhạc online (Bài 6)

Project Flutter cho Android, iOS và Web, giao diện tiếng Việt. Chạy ngay ở chế độ khách, không cần Firebase để nghe nhạc.

## Chạy project

Máy hiện tại đã có Flutter. Tại thư mục `D:\TH-DiDongDaNenTang\Bai6`:

```powershell
flutter pub get
flutter run -d emulator-5554
```

Hoặc chạy trên trình duyệt:

```powershell
flutter run -d chrome
```

Chọn bài hát hoặc nhấn **Nghe ngay** để bắt đầu. Trên Web, cần thao tác người dùng để trình duyệt cho phép phát âm thanh. iOS cần macOS và Xcode để build; project không cấu hình Windows desktop.

## Các chức năng

- Khám phá: thumbnail, tên bài hát, nghệ sĩ; tìm kiếm không phân biệt hoa/thường và dấu tiếng Việt; lọc thể loại.
- Trình phát: ảnh lớn, tên bài/nghệ sĩ, thời gian thực và progress có thể tua, Play/Pause, Next/Previous.
- Stream MP3 HTTPS bằng `just_audio`, chuẩn bị bài trong hàng đợi khi cần; không có chức năng tải file MP3 về thiết bị. Player vẫn sử dụng bộ đệm khi stream.
- Hàng đợi tự chuyển bài; phát ngẫu nhiên và lặp (tắt / toàn bộ / một bài).
- Mini player để tiếp tục điều khiển khi chuyển tab.
- Playlist: tạo, thêm bài từ menu `…`, chọn bài để phát, xóa bài, xóa playlist có xác nhận.
- Yêu thích: nhấn trái tim để thích/bỏ thích, phát toàn bộ bài yêu thích.
- Chế độ khách: lưu thư viện bằng `shared_preferences`, giữ lại khi đóng/mở ứng dụng.
- Tài khoản (*): Firebase Authentication Email/Password, đăng ký, đăng nhập, đặt lại mật khẩu, đăng xuất; lưu thư viện riêng theo UID trên Cloud Firestore sau khi cấu hình Firebase.
- Thư viện khách và tài khoản tách riêng. Thư viện khách không tự nhập vào tài khoản khi đăng nhập.
- Trạng thái tải, lỗi kết nối, danh sách rỗng và ảnh dự phòng.

## Nguồn nhạc và thay đổi danh sách

Metadata được khai báo trong `lib/data/catalog.dart`. Bộ mẫu gồm 8 URL MP3 công khai của [SoundHelix](https://www.soundhelix.com/audio-examples), giữ tên gốc `SoundHelix Song 1..8`, tác giả T. Schürger. Đây là dữ liệu mẫu phục vụ bài thực hành, không phải API tìm kiếm nhạc thương mại. URL và khả năng truy cập phụ thuộc máy chủ bên ngoài.

Ảnh minh họa tải từ Unsplash và đóng gói tại `assets/covers/`; không phải bìa album chính thức. `SongCover` có ảnh dự phòng nếu asset hoặc URL ảnh không dùng được.

Để thêm nhạc, thêm một `Song` trong catalog:

```dart
Song(
  id: 'my_song',
  title: 'Tên bài hát',
  artist: 'Tên nghệ sĩ',
  genre: 'Electronic',
  url: 'https://your-server.example/music.mp3',
  coverUrl: 'https://your-server.example/cover.jpg',
)
```

Dùng URL HTTPS có thể truy cập trực tiếp. Khi chạy Web, máy chủ MP3 cần đáp ứng yêu cầu truy cập của trình duyệt. Có thể đặt ảnh tại `assets/covers/my_song.jpg`. Nếu muốn lưu MP3 trong Firebase Storage, thay `url` bằng download URL từ Storage; ứng dụng vẫn stream URL đó.

## Bật đăng nhập và đồng bộ Firebase

Không có project Firebase hoặc khóa giả được gắn sẵn. Mặc định ứng dụng chạy chế độ khách. Phần đăng nhập đã được triển khai nhưng cần cấu hình dự án Firebase của bạn; nếu chưa bật, màn hình tài khoản thông báo rõ và cho phép tiếp tục nghe nhạc.

1. Tạo project trong [Firebase Console](https://console.firebase.google.com/).
2. Bật **Authentication → Sign-in method → Email/Password**.
3. Tạo **Cloud Firestore**. Dán nội dung `firestore.rules` vào tab Rules và Publish để mỗi người chỉ đọc/ghi thư viện của chính mình. Không dùng quyền đọc/ghi công khai.
4. Cài Firebase CLI và FlutterFire CLI theo [hướng dẫn Firebase chính thức](https://firebase.google.com/docs/flutter/setup), rồi tại thư mục project chạy:

```powershell
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

Chọn đúng project và các nền tảng Android, iOS, Web cần dùng. Cho phép công cụ thay thế `lib/firebase_options.dart`; file này đang là placeholder lấy thông tin qua `--dart-define`.

5. Chạy với Firebase bật:

```powershell
flutter run -d emulator-5554 --dart-define=FIREBASE_ENABLED=true
# hoặc:
flutter run -d chrome --dart-define=FIREBASE_ENABLED=true
```

Web: thêm tên miền chạy ứng dụng (ví dụ `localhost`) vào **Authentication → Settings → Authorized domains** nếu cần. Khi thay cấu hình, dừng và chạy lại ứng dụng.

Nếu đã có Firebase CLI, có thể deploy rules bằng:

```powershell
firebase deploy --only firestore:rules --project YOUR_PROJECT_ID
```

Firestore lưu tại `users/{uid}`:

```json
{
  "favorites": ["sh1", "sh3"],
  "playlists": [
    {"id": "unique-id", "name": "Nhạc học bài", "songIds": ["sh1", "sh2"]}
  ],
  "updatedAt": "server timestamp"
}
```

Mật khẩu do Firebase Authentication quản lý, không lưu trong Firestore hay SharedPreferences. Metadata/MP3 mẫu không cần Firestore/Storage. Firestore hiện lưu thư viện cá nhân, không làm kho nhạc.

## Cấu trúc

```text
lib/
  main.dart                         Khởi tạo và cấu hình Firebase tùy chọn
  firebase_options.dart             Cấu hình Firebase (FlutterFire có thể tạo lại)
  models/song.dart                  Song, MusicPlaylist và tìm kiếm
  data/catalog.dart                 Danh sách URL MP3/metadata mẫu
  controllers/music_controller.dart Phát nhạc, thư viện và đồng bộ
  ui/
    theme.dart                      Theme tối
    home_screen.dart                Khám phá, Playlist, Yêu thích, Tài khoản
    player_screen.dart              Màn hình phát và hàng đợi
    auth_screen.dart                Đăng nhập/đăng ký/đặt lại mật khẩu
    widgets.dart                    Thumbnail, progress và nút điều khiển
assets/covers/                      Ảnh minh họa
test/                               Kiểm tra hành vi và giao diện
firestore.rules                     Quyền thư viện theo UID
```

## Kiểm tra và build

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter build web
```

APK debug nằm tại `build/app/outputs/flutter-apk/app-debug.apk`. APK debug phù hợp để chạy thử/nộp bài; khi phát hành cần cấu hình ký release riêng. Không triển khai thông báo điều khiển nhạc/foreground service; nếu yêu cầu phát nền và điều khiển màn hình khóa, có thể bổ sung `audio_service`.

Đã kiểm tra: unit/widget tests cho tìm kiếm, lưu thư viện, hàng đợi, lỗi phát, đồng bộ tài khoản bằng Firebase giả lập; bố cục 320/390/1280 px. Test quyền kiểm tra điều kiện UID bằng fake; chưa chạy toàn bộ rules bằng Firebase Emulator. Đã chạy thử stream MP3 thật trên trình giả lập Android. Đăng nhập với Firebase thật chưa kiểm tra vì chưa có cấu hình dự án.

Ảnh chạy thử: [Màn hình chính](screenshots/home-android.png), [Trình phát nhạc](screenshots/player-android.png).

Tài liệu: [just_audio](https://pub.dev/packages/just_audio), [Firebase Email/Password](https://firebase.google.com/docs/auth/flutter/password-auth).
