import 'dart:math';
import 'package:vector_math/vector_math_64.dart';

import 'constants.dart';
import 'math.dart';

class CollisionSystem {
  CollisionSystem._();

  static bool checkCircleCircle(Vector2 posA, double radiusA, Vector2 posB, double radiusB) {
    return GameMath.circlesOverlap(posA, radiusA, posB, radiusB);
  }

  static bool checkPointInCircle(Vector2 point, Vector2 center, double radius) {
    return GameMath.pointInCircle(point, center, radius);
  }

  static bool checkRectRect(
    double x1, double y1, double w1, double h1,
    double x2, double y2, double w2, double h2,
  ) {
    return x1 < x2 + w2 && x1 + w1 > x2 && y1 < y2 + h2 && y1 + h1 > y2;
  }

  static bool checkPointInRect(Vector2 point, double x, double y, double w, double h) {
    return GameMath.pointInRect(point, x, y, w, h);
  }

  static bool checkLineCircle(Vector2 lineStart, Vector2 lineEnd, Vector2 center, double radius) {
    final d = lineEnd - lineStart;
    final f = lineStart - center;
    final a = d.dot(d);
    final b = 2.0 * f.dot(d);
    final c = f.dot(f) - radius * radius;
    double discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0) return false;
    discriminant = sqrt(discriminant);
    final t1 = (-b - discriminant) / (2.0 * a);
    final t2 = (-b + discriminant) / (2.0 * a);
    if (t1 >= 0 && t1 <= 1) return true;
    if (t2 >= 0 && t2 <= 1) return true;
    return false;
  }

  static Vector2? raycastCircle(
    Vector2 origin, Vector2 direction, double maxDist, Vector2 center, double radius,
  ) {
    final d = direction.clone()..normalize();
    final f = origin - center;
    final a = d.dot(d);
    final b = 2.0 * f.dot(d);
    final c = f.dot(f) - radius * radius;
    double discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0) return null;
    discriminant = sqrt(discriminant);
    final t1 = (-b - discriminant) / (2.0 * a);
    final t2 = (-b + discriminant) / (2.0 * a);
    double t = -1;
    if (t1 >= 0 && t1 <= maxDist) t = t1;
    else if (t2 >= 0 && t2 <= maxDist) t = t2;
    if (t < 0) return null;
    return origin + d * t;
  }

  static bool checkProjectileHit(
    Vector2 projectilePos, double projectileRadius,
    Vector2 targetPos, double targetRadius,
    Vector2 prevPos,
  ) {
    if (checkCircleCircle(projectilePos, projectileRadius, targetPos, targetRadius)) {
      return true;
    }
    final segDir = projectilePos - prevPos;
    final segLen = segDir.length;
    if (segLen < 0.001) return false;
    segDir.normalize();
    return checkLineCircle(prevPos, projectilePos, targetPos, targetRadius + projectileRadius);
  }

  static List<Vector2> findPathSimple(
    Vector2 start, Vector2 end, List<Obstacle> obstacles, double agentRadius,
  ) {
    final path = <Vector2>[start.clone()];
    final directDir = end - start;
    final directDist = directDir.length;
    if (directDist < 1) return [end.clone()];
    directDir.normalize();
    bool blocked = false;
    for (final obs in obstacles) {
      if (checkLineCircle(start, end, obs.position, obs.radius + agentRadius)) {
        blocked = true;
        break;
      }
    }
    if (!blocked) {
      path.add(end.clone());
      return path;
    }
    final perp = Vector2(-directDir.y, directDir.x);
    final mid1 = start + directDir * (directDist * 0.33) + perp * (agentRadius * 3);
    final mid2 = start + directDir * (directDist * 0.66) - perp * (agentRadius * 3);
    path.add(GameMath.clampToWorld(mid1, GameConstants.worldWidth, GameConstants.worldHeight, 50));
    path.add(GameMath.clampToWorld(mid2, GameConstants.worldWidth, GameConstants.worldHeight, 50));
    path.add(end.clone());
    return path;
  }

  static Vector2 avoidObstacles(
    Vector2 currentPos, Vector2 desiredDir, List<Obstacle> obstacles, double agentRadius,
  ) {
    Vector2 avoidance = Vector2.zero();
    for (final obs in obstacles) {
      final toAgent = currentPos - obs.position;
      final dist = toAgent.length;
      final minDist = obs.radius + agentRadius;
      if (dist < minDist && dist > 0.001) {
        toAgent.normalize();
        final strength = (minDist - dist) / minDist;
        avoidance += toAgent * strength;
      }
    }
    if (avoidance.length2 > 0) {
      avoidance.normalize();
      return (desiredDir + avoidance * 0.5)..normalize();
    }
    return desiredDir;
  }

  static bool isInBush(Vector2 position, List<BushZone> bushes) {
    for (final bush in bushes) {
      if (GameMath.distance(position, bush.position) < bush.radius) {
        return true;
      }
    }
    return false;
  }
}

class Obstacle {
  final Vector2 position;
  final double radius;

  Obstacle({required this.position, required this.radius});
}

class BushZone {
  final Vector2 position;
  final double radius;

  BushZone({required this.position, required this.radius});
}

class LanePath {
  final List<Vector2> waypoints;
  final String name;

  LanePath({required this.waypoints, required this.name});

  Vector2 getStart() => waypoints.first;
  Vector2 getEnd() => waypoints.last;

  int get waypointCount => waypoints.length;

  Vector2 getWaypoint(int index) {
    if (index < 0) return waypoints.first;
    if (index >= waypoints.length) return waypoints.last;
    return waypoints[index];
  }

  double getTotalLength() {
    double total = 0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      total += GameMath.distance(waypoints[i], waypoints[i + 1]);
    }
    return total;
  }

  Vector2 getPositionAtProgress(double progress) {
    if (progress <= 0) return waypoints.first.clone();
    if (progress >= 1) return waypoints.last.clone();
    final totalLen = getTotalLength();
    final targetDist = progress * totalLen;
    double traveled = 0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      final segLen = GameMath.distance(waypoints[i], waypoints[i + 1]);
      if (traveled + segLen >= targetDist) {
        final t = (targetDist - traveled) / segLen;
        return Vector2(
          GameMath.lerp(waypoints[i].x, waypoints[i + 1].x, t),
          GameMath.lerp(waypoints[i].y, waypoints[i + 1].y, t),
        );
      }
      traveled += segLen;
    }
    return waypoints.last.clone();
  }
}
