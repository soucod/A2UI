// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:genui/genui.dart';
import 'package:genui_a2a/genui_a2a.dart';

import '../../core/logging.dart';
import '../state/loading_state.dart';

String a2aServerUrl = 'http://localhost:10002';

/// A provider for the A2UI agent connector.

A2uiAgentConnector a2uiAgentConnector() {
  final Uri url = Uri.parse(a2aServerUrl);
  appLogger.info('A2UI server URL: ${url.toString()}');
  return A2uiAgentConnector(url: url);
}

/// The state of the AI client provider.
class AiClientState {
  /// Creates an [AiClientState].
  AiClientState({
    required this.surfaceController,
    required this.connector,
    required this.conversation,
    required this.surfaceUpdateController,
  });

  /// The A2UI message processor.
  final SurfaceController surfaceController;

  /// The agent connector.
  final A2uiAgentConnector connector;

  /// The conversation manager.
  final Conversation conversation;

  /// A stream that emits the ID of the most recently updated surface.
  final StreamController<String> surfaceUpdateController;
}

class Ai {
  Future<AiClientState> build() async {
    final surfaceController = SurfaceController(
      catalogs: [BasicCatalogItems.asCatalog()],
    );
    final A2uiAgentConnector connector = a2uiAgentConnector();

    final transportAdapter = A2uiTransportAdapter(
      onSend: (message) async {
        // Send request via connector
        await connector.connectAndSend(message);
      },
    );

    // Wire up connector to transportAdapter
    connector.stream.listen(transportAdapter.addMessage);
    connector.textStream.listen(transportAdapter.addChunk);

    final conversation = Conversation(
      transport: transportAdapter,
      controller: surfaceController,
    );

    final surfaceUpdateController = StreamController<String>.broadcast();

    connector.stream.listen((message) {
      if (message is CreateSurface) {
        surfaceUpdateController.add(message.surfaceId);
      }
    });

    // Fetch the agent card to initialize the connection.
    await connector.getAgentCard();

    void updateProcessingState() {
      LoadingState.instance.isProcessing.value =
          conversation.state.value.isWaiting;
    }

    conversation.state.addListener(updateProcessingState);

    return AiClientState(
      surfaceController: surfaceController,
      connector: connector,
      conversation: conversation,
      surfaceUpdateController: surfaceUpdateController,
    );
  }
}
