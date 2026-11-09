import 'package:avanilands_admin/core/errors.dart';
import 'package:avanilands_admin/features/media/media_rules.dart';
import 'package:flutter_test/flutter_test.dart';

const _mb = 1024 * 1024;

void main() {
  group('file checks (same limits as the storage buckets)', () {
    test('photos', () {
      expect(
        checkFile(
          MediaKind.photo,
          name: 'plot.jpg',
          type: 'image/jpeg',
          size: 3 * _mb,
        ),
        isNull,
      );
      expect(
        checkFile(MediaKind.photo, name: 'IMG_1.HEIC', type: '', size: 2 * _mb),
        isNull,
        reason: 'some browsers give HEIC no type',
      );
      expect(
        checkFile(
          MediaKind.photo,
          name: 'big.jpg',
          type: 'image/jpeg',
          size: 16 * _mb,
        ),
        '"big.jpg" is 16 MB. The limit is 15 MB.',
      );
      expect(
        checkFile(
          MediaKind.photo,
          name: 'doc.pdf',
          type: 'application/pdf',
          size: _mb,
        ),
        contains('not allowed'),
      );
      expect(
        checkFile(MediaKind.photo, name: 'x.gif', type: 'image/gif', size: _mb),
        contains('not allowed'),
      );
      expect(
        checkFile(
          MediaKind.photo,
          name: 'empty.png',
          type: 'image/png',
          size: 0,
        ),
        contains('empty'),
      );
    });

    test('videos', () {
      expect(
        checkFile(
          MediaKind.video,
          name: 'walk.mp4',
          type: 'video/mp4',
          size: 40 * _mb,
        ),
        isNull,
      );
      expect(
        checkFile(
          MediaKind.video,
          name: 'walk.mp4',
          type: 'video/mp4',
          size: 51 * _mb,
        ),
        contains('50 MB'),
      );
      expect(
        checkFile(
          MediaKind.video,
          name: 'walk.mov',
          type: 'video/quicktime',
          size: _mb,
        ),
        contains('MP4'),
      );
    });

    test('documents', () {
      expect(
        checkFile(
          MediaKind.document,
          name: 'layout.pdf',
          type: 'application/pdf',
          size: 5 * _mb,
        ),
        isNull,
      );
      expect(
        checkFile(
          MediaKind.document,
          name: 'deed.png',
          type: 'image/png',
          size: 5 * _mb,
        ),
        isNull,
      );
      expect(
        checkFile(
          MediaKind.document,
          name: 'deed.docx',
          type: 'application/msword',
          size: _mb,
        ),
        contains('not allowed'),
      );
      expect(
        checkFile(
          MediaKind.document,
          name: 'scan.pdf',
          type: 'application/pdf',
          size: 21 * _mb,
        ),
        contains('20 MB'),
      );
    });
  });

  test('photo sizes never enlarge and keep the shape', () {
    expect(fitWithin(4000, 3000, 2000), (width: 2000, height: 1500));
    expect(fitWithin(3000, 4000, 400), (width: 300, height: 400));
    expect(fitWithin(800, 600, 1200), (width: 800, height: 600));
    expect(
      [for (final s in PhotoSize.values) s.longestSide],
      [400, 1200, 2000],
    );
  });

  group('YouTube links', () {
    const id = 'dQw4w9WgXcQ';
    for (final link in [
      'https://www.youtube.com/watch?v=$id',
      'https://youtube.com/watch?v=$id&t=42s',
      'https://m.youtube.com/watch?v=$id',
      'https://youtu.be/$id?si=abc',
      'youtu.be/$id',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/embed/$id',
      'https://www.youtube.com/live/$id',
      id,
    ]) {
      test(link, () => expect(youtubeId(link), id));
    }

    test('not YouTube', () {
      expect(youtubeId('https://vimeo.com/123456'), isNull);
      expect(youtubeId('https://www.youtube.com/channel/UC123'), isNull);
      expect(youtubeId('hello'), isNull);
      expect(youtubeId('https://evil.example/watch?v=$id'), isNull);
    });
  });

  test('document titles and extensions', () {
    expect(titleFromFileName('layout_plan-v2.pdf'), 'Layout plan v2');
    expect(titleFromFileName('.pdf'), 'Document');
    expect(extensionFor('Deed.PDF', 'application/pdf'), 'pdf');
    expect(extensionFor('scan', 'image/jpeg'), 'jpg');
  });

  test('sizes read naturally', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(1536 * 1024), '1.5 MB');
    expect(formatBytes(20 * _mb), '20 MB');
  });

  test('media problems show as written', () {
    expect(
      friendlyError(
        const MediaException('This file type is not allowed here.'),
      ),
      'This file type is not allowed here.',
    );
  });
}
