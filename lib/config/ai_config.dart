/// Developer configuration for the AI execution backend.
///
/// This file centralises all AI-related knobs so that a developer can
/// switch between Firebase AI, direct REST API calls, and the external
/// Python FastAPI service by changing a single constant.
///
/// **No UI is exposed for these settings.** They are compile-time constants
/// meant to be toggled during development or before a release build.
library;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'package:flutter_dotenv/flutter_dotenv.dart';

// ---------------------------------------------------------------------------
// Execution mode
// ---------------------------------------------------------------------------

/// How the app should execute AI tasks (lesson generation, quiz generation).
enum AIExecutionMode {
  /// Uses the Firebase AI Logic SDK (`firebase_ai` package).
  /// This is the recommended approach — API keys are managed by Firebase,
  /// and App Check provides security. No separate server required.
  firebaseAI,

  /// Executes entirely within the Flutter app:
  ///  • PDF text extraction via `syncfusion_flutter_pdf`
  ///  • Calls the Google Gemini REST API directly from Dart
  ///  • Requires a Gemini API key loaded from .env
  ///  • No external server required
  directClientSide,

  /// Delegates to the external Python FastAPI service (`ai_backend/`).
  /// The service must be running and reachable at [AIConfig.pythonBackendUrl].
  pythonBackend,
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

class AIConfig {
  AIConfig._(); // non-instantiable

  // ── Execution mode ──────────────────────────────────────────────────────
  /// **DEV TOGGLE**: Change this constant to swap between execution modes.
  static const AIExecutionMode mode = AIExecutionMode.directClientSide;

  // ── Firebase AI (used in firebaseAI mode) ───────────────────────────────
  /// The Gemini model to use via Firebase AI Logic SDK.
  static const String firebaseAIModel = 'gemini-2.5-flash';

  // ── Gemini REST API (used in directClientSide mode) ─────────────────────
  /// Your Google Gemini API key loaded from the .env file.
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// The Gemini model identifier to use for direct REST calls.
  static const String geminiModel = 'gemini-3.6-flash';

  // ── Python backend (used in pythonBackend mode) ─────────────────────────
  /// Base URL of the running `ai_backend` FastAPI service.
  /// On Android emulators the host machine is reachable at `10.0.2.2`.
  static String get pythonBackendUrl {
    if (kIsWeb) return 'http://localhost:8001';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://localhost:8001';
  }

  /// The `X-API-Key` header value expected by the Python backend.
  static const String pythonApiKey = 'YOUR_BACKEND_API_KEY';
}
