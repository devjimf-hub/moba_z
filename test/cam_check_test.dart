import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:moba_z/game/camera.dart';

void main() {
  test('camera convergence', () {
    final cam = GameCamera();
    cam.setViewportSize(800, 600);
    final target = Vector2(460, 2740);
    for (int i = 0; i < 5; i++) {
      cam.follow(target);
      cam.update(0.016);
      print('frame $i: pos=${cam.position}');
    }
  });
}
