import 'dart:async';

import 'package:genui/genui.dart';
import 'package:genui_a2a/genui_a2a.dart';

import 'primitives/loading_state.dart';

/// A client for interaction with agent.
class AgentClient {
  AgentClient();
}

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

class AiClient {
  static const _clientUrl = 'http://localhost:10002';
  final _connector = A2uiAgentConnector(url: Uri.parse(_clientUrl));

  Future<AiClientState> build() async {
    final surfaceController = SurfaceController(
      catalogs: [BasicCatalogItems.asCatalog()],
    );

    final transportAdapter = A2uiTransportAdapter(
      onSend: (message) async {
        // Send request via connector
        await _connector.connectAndSend(message);
      },
    );

    // Wire up connector to transportAdapter
    _connector.stream.listen(transportAdapter.addMessage);
    _connector.textStream.listen(transportAdapter.addChunk);

    final conversation = Conversation(
      transport: transportAdapter,
      controller: surfaceController,
    );

    final surfaceUpdateController = StreamController<String>.broadcast();

    _connector.stream.listen((message) {
      if (message is CreateSurface) {
        surfaceUpdateController.add(message.surfaceId);
      }
    });

    // Fetch the agent card to initialize the connection.
    await _connector.getAgentCard();

    void updateProcessingState() {
      LoadingState.instance.isProcessing.value =
          conversation.state.value.isWaiting;
    }

    conversation.state.addListener(updateProcessingState);

    return AiClientState(
      surfaceController: surfaceController,
      connector: _connector,
      conversation: conversation,
      surfaceUpdateController: surfaceUpdateController,
    );
  }

  void dispose() {
    conversation.state.removeListener(updateProcessingState);
    // Reset the loading state when the provider is disposed.
    LoadingState.instance.isProcessing.value = false;
    conversation.dispose();
    transportAdapter.dispose();
    surfaceUpdateController.close();
  }
}
