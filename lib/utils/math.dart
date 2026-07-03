import 'dart:math';
import 'package:vector_math/vector_math_64.dart';

class GameMath {
  GameMath._();

  static final Random _rng = Random();

  static double randomRange(double min, double max) {
    return min + _rng.nextDouble() * (max - min);
  }

  static int randomInt(int min, int max) {
    return min + _rng.nextInt(max - min + 1);
  }

  static double clamp(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static double lerp(double a, double b, double t) {
    return a + (b - a) * clamp(t, 0.0, 1.0);
  }

  static double distance(Vector2 a, Vector2 b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return sqrt(dx * dx + dy * dy);
  }

  static double distanceSquared(Vector2 a, Vector2 b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    return dx * dx + dy * dy;
  }

  static double distanceToLineSegment(Vector2 p, Vector2 a, Vector2 b) {
    final l2 = distanceSquared(a, b);
    if (l2 == 0) return distance(p, a);
    var t = ((p.x - a.x) * (b.x - a.x) + (p.y - a.y) * (b.y - a.y)) / l2;
    t = clamp(t, 0.0, 1.0);
    return distance(p, Vector2(a.x + t * (b.x - a.x), a.y + t * (b.y - a.y)));
  }

  static double angleTo(Vector2 from, Vector2 to) {
    return atan2(to.y - from.y, to.x - from.x);
  }

  static Vector2 directionTo(Vector2 from, Vector2 to) {
    final dir = Vector2(to.x - from.x, to.y - from.y);
    if (dir.length2 > 0) {
      dir.normalize();
    }
    return dir;
  }

  static Vector2 moveTowards(Vector2 current, Vector2 target, double maxDistance) {
    final dx = target.x - current.x;
    final dy = target.y - current.y;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist <= maxDistance || dist == 0) {
      return Vector2(target.x, target.y);
    }
    final ratio = maxDistance / dist;
    return Vector2(
      current.x + dx * ratio,
      current.y + dy * ratio,
    );
  }

  static Vector2 clampToWorld(Vector2 pos, double worldW, double worldH, double margin) {
    return Vector2(
      clamp(pos.x, margin, worldW - margin),
      clamp(pos.y, margin, worldH - margin),
    );
  }

  static bool pointInRect(Vector2 point, double x, double y, double w, double h) {
    return point.x >= x && point.x <= x + w && point.y >= y && point.y <= y + h;
  }

  static bool circlesOverlap(Vector2 a, double ra, Vector2 b, double rb) {
    final d = distance(a, b);
    return d < ra + rb;
  }

  static bool pointInCircle(Vector2 point, Vector2 center, double radius) {
    return distance(point, center) <= radius;
  }

  static double smoothstep(double edge0, double edge1, double x) {
    final t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }

  static double easeInOut(double t) {
    return t < 0.5 ? 2.0 * t * t : 1.0 - pow(-2.0 * t + 2.0, 2).toDouble() / 2.0;
  }

  static double easeOut(double t) {
    return 1.0 - (1.0 - t) * (1.0 - t);
  }

  static double easeIn(double t) {
    return t * t;
  }

  static double angleDifference(double a, double b) {
    double diff = b - a;
    while (diff > pi) diff -= 2.0 * pi;
    while (diff < -pi) diff += 2.0 * pi;
    return diff;
  }

  static double lerpAngle(double a, double b, double t) {
    return a + angleDifference(a, b) * clamp(t, 0.0, 1.0);
  }

  static Vector2 rotatePoint(Vector2 point, Vector2 center, double angle) {
    final cosA = cos(angle);
    final sinA = sin(angle);
    final dx = point.x - center.x;
    final dy = point.y - center.y;
    return Vector2(
      center.x + dx * cosA - dy * sinA,
      center.y + dx * sinA + dy * cosA,
    );
  }

  static double normalizeAngle(double angle) {
    while (angle > pi) angle -= 2.0 * pi;
    while (angle < -pi) angle += 2.0 * pi;
    return angle;
  }

  static Vector2 randomPointInCircle(Vector2 center, double radius) {
    final angle = _rng.nextDouble() * 2.0 * pi;
    final r = sqrt(_rng.nextDouble()) * radius;
    return Vector2(
      center.x + cos(angle) * r,
      center.y + sin(angle) * r,
    );
  }

  static Vector2 randomPointInRect(double x, double y, double w, double h) {
    return Vector2(
      x + _rng.nextDouble() * w,
      y + _rng.nextDouble() * h,
    );
  }

  static int generateId() {
    return _rng.nextInt(0x7FFFFFFF);
  }

  static Vector2 mirrorPoint(Vector2 p, double worldW, double worldH) {
    return Vector2(worldW - p.x, worldH - p.y);
  }
}
