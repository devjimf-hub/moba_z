import 'dart:ui';
import 'package:vector_math/vector_math_64.dart';
import '../utils/constants.dart';
import '../utils/math.dart';

class GameCamera {
  Vector2 position = Vector2(GameConstants.worldWidth / 2, GameConstants.worldHeight / 2);
  Vector2 _targetPosition = Vector2(GameConstants.worldWidth / 2, GameConstants.worldHeight / 2);
  double _zoom = GameConstants.cameraZoomDefault;
  double _targetZoom = GameConstants.cameraZoomDefault;
  double _shakeAmount = 0;
  double _shakeTimer = 0;
  Vector2 _shakeOffset = Vector2.zero();
  double _viewWidth = 800;
  double _viewHeight = 600;

  double get zoom => _zoom;
  Vector2 get shakeOffset => _shakeOffset;

  void setViewportSize(double width, double height) {
    _viewWidth = width;
    _viewHeight = height;
  }

  void follow(Vector2 target) {
    _targetPosition = target.clone();
  }

  void setZoom(double zoom) {
    _targetZoom = GameMath.clamp(zoom, GameConstants.cameraZoomMin, GameConstants.cameraZoomMax);
  }

  void zoomIn() {
    setZoom(_targetZoom + 0.1);
  }

  void zoomOut() {
    setZoom(_targetZoom - 0.1);
  }

  void shake(double amount, double duration) {
    _shakeAmount = amount;
    _shakeTimer = duration;
  }

  void update(double dt) {
    final smoothing = GameConstants.cameraSmoothing * dt;
    position.x = GameMath.lerp(position.x, _targetPosition.x, smoothing);
    position.y = GameMath.lerp(position.y, _targetPosition.y, smoothing);
    _zoom = GameMath.lerp(_zoom, _targetZoom, smoothing * 1.5);

    final halfViewW = (_viewWidth / 2) / _zoom;
    final halfViewH = (_viewHeight / 2) / _zoom;
    position.x = GameMath.clamp(position.x, halfViewW, GameConstants.worldWidth - halfViewW);
    position.y = GameMath.clamp(position.y, halfViewH, GameConstants.worldHeight - halfViewH);

    if (_shakeTimer > 0) {
      _shakeTimer -= dt;
      final intensity = _shakeTimer > 0 ? _shakeAmount * (_shakeTimer / 0.5) : 0;
      _shakeOffset = Vector2(
        (DateTime.now().millisecondsSinceEpoch % 100 - 50) / 50.0 * intensity,
        (DateTime.now().millisecondsSinceEpoch % 100 - 50) / 50.0 * intensity,
      );
    } else {
      _shakeOffset = Vector2.zero();
      _shakeAmount = 0;
    }
  }

  void applyTransform(Canvas canvas) {
    canvas.translate(_viewWidth / 2, _viewHeight / 2);
    canvas.scale(_zoom, _zoom);
    canvas.translate(
      -(position.x + _shakeOffset.x),
      -(position.y + _shakeOffset.y),
    );
  }

  void restoreTransform(Canvas canvas) {
    canvas.translate(
      position.x + _shakeOffset.x,
      position.y + _shakeOffset.y,
    );
    canvas.scale(1 / _zoom, 1 / _zoom);
    canvas.translate(-_viewWidth / 2, -_viewHeight / 2);
  }

  Vector2 screenToWorld(Vector2 screenPos) {
    return Vector2(
      (screenPos.x - _viewWidth / 2) / _zoom + position.x,
      (screenPos.y - _viewHeight / 2) / _zoom + position.y,
    );
  }

  Vector2 worldToScreen(Vector2 worldPos) {
    return Vector2(
      (worldPos.x - position.x) * _zoom + _viewWidth / 2,
      (worldPos.y - position.y) * _zoom + _viewHeight / 2,
    );
  }

  bool isOnScreen(Vector2 worldPos, double margin) {
    final screenPos = worldToScreen(worldPos);
    return screenPos.x > -margin &&
        screenPos.x < _viewWidth + margin &&
        screenPos.y > -margin &&
        screenPos.y < _viewHeight + margin;
  }

  Rect getVisibleRect() {
    final halfW = (_viewWidth / 2) / _zoom;
    final halfH = (_viewHeight / 2) / _zoom;
    return Rect.fromLTWH(
      position.x - halfW,
      position.y - halfH,
      halfW * 2,
      halfH * 2,
    );
  }
}
