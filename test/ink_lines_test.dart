import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaguide/features/scan/domain/ink_stroke.dart';

/// A stroke from [x1,y1] to [x2,y2] at [start] ms, sampled every 10ms.
InkStroke stroke(
  double x1,
  double y1,
  double x2,
  double y2, {
  int start = 0,
}) {
  return InkStroke([
    for (var i = 0; i <= 4; i++)
      InkPoint(
        x: x1 + (x2 - x1) * i / 4,
        y: y1 + (y2 - y1) * i / 4,
        t: start + i * 10,
      ),
  ]);
}

void main() {
  group('InkStroke', () {
    test('measures the box around its points', () {
      final line = stroke(10, 20, 40, 30);

      expect(line.bounds, const Rect.fromLTRB(10, 20, 40, 30));
    });

    test('accepts a single tap as a dot', () {
      final dot = InkStroke([
        const InkPoint(x: 5, y: 7, t: 0),
      ]);

      expect(dot.bounds.left, 5);
      expect(dot.bounds.top, 7);
      expect(dot.bounds.width, 0);
      expect(dot.bounds.height, 0);
    });

    test('keeps its points immutable', () {
      final points = [
        const InkPoint(x: 0, y: 0, t: 0),
        const InkPoint(x: 10, y: 10, t: 20),
      ];

      final line = InkStroke(points);
      points.add(const InkPoint(x: 99, y: 99, t: 99));

      expect(line.points, hasLength(2));
      expect(() => line.points.add(
        const InkPoint(x: 0, y: 0, t: 0),
      ), throwsUnsupportedError);
    });

    test('rejects a stroke with no points', () {
      expect(() => InkStroke(const []), throwsA(isA<AssertionError>()));
    });
  });

  group('InkLine', () {
    test('spans every stroke it holds', () {
      final line = InkLine([
        stroke(0, 20, 10, 20),
        stroke(20, 10, 20, 40),
      ]);

      expect(line.bounds, const Rect.fromLTRB(0, 10, 20, 40));
      expect(line.strokes, hasLength(2));
    });
  });

  group('groupStrokesIntoLines', () {
    test('puts letters written on the same row together', () {
      final lines = groupStrokesIntoLines([
        stroke(0, 20, 10, 40),
        stroke(20, 22, 30, 42),
        stroke(40, 25, 50, 45),
      ]);

      expect(lines, hasLength(1));
      expect(lines.first.strokes, hasLength(3));
    });

    test('keeps a stroke that dips below the row with that row', () {
      // The tail of a `y` hangs below the baseline but still overlaps the row.
      final lines = groupStrokesIntoLines([
        stroke(0, 20, 10, 40),
        stroke(0, 28, 3, 52),
        stroke(60, 60, 70, 80),
      ]);

      expect(lines, hasLength(2));
      expect(lines.first.strokes, hasLength(2));
      expect(lines.last.strokes, hasLength(1));
    });

    test('starts a new line at a full row gap', () {
      final lines = groupStrokesIntoLines([
        stroke(0, 20, 10, 40),
        stroke(0, 60, 10, 80),
      ]);

      expect(lines, hasLength(2));
    });

    test('keeps a flat stroke that sits on the row', () {
      // A dash or an underline has no height, so the overlap test has nothing
      // to measure and it has to be treated as touching instead.
      final lines = groupStrokesIntoLines([
        stroke(0, 20, 10, 40),
        stroke(20, 30, 40, 30),
      ]);

      expect(lines, hasLength(1));
      expect(lines.first.strokes, hasLength(2));
    });

    test('puts a flat stroke on a row of its own when it touches nothing', () {
      final lines = groupStrokesIntoLines([
        stroke(0, 20, 10, 40),
        stroke(20, 70, 40, 70),
      ]);

      expect(lines, hasLength(2));
    });

    test('does not merge two rows that nearly touch', () {
      // A tight leading with a descender reaching into the next row. Merging
      // would hand the recognizer two lines in one writing area.
      final lines = groupStrokesIntoLines([
        stroke(0, 20, 10, 55),
        stroke(0, 54, 10, 89),
      ]);

      expect(lines, hasLength(2));
    });

    test('preserves the order the strokes were written in', () {
      // Written bottom row first, then the top row. ML Kit reads better when
      // strokes arrive in capture order, so clustering must not sort them.
      final first = stroke(0, 60, 10, 80);
      final second = stroke(0, 10, 10, 30);
      final third = stroke(20, 12, 30, 32);

      final lines = groupStrokesIntoLines([first, second, third]);

      expect(lines, hasLength(2));
      expect(lines[0].strokes.single, same(first));
      expect(lines[1].strokes, [second, third]);
    });

    test('returns nothing for no strokes', () {
      expect(groupStrokesIntoLines(const []), isEmpty);
    });
  });
}
