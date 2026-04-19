// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

const _defaultMessages = [
  'Finding the best spots for you...',
  'Checking reviews...',
  'Looking for open tables...',
  'Almost there...',
];

class LoadingState {
  LoadingState._() {
    // When the processing state changes from true to false, reset messages.
    isProcessing.addListener(() {
      // Went from false to true: do nothing.
      if (_isProcessingValue && !isProcessing.value) {
        // Went from true to false, reset messages after a short delay
        // to allow the fade-out animation to complete.
        Future<void>.delayed(const Duration(milliseconds: 500), clearMessages);
      }
      _isProcessingValue = isProcessing.value;
    });
  }

  static final instance = LoadingState._();

  final messages = ValueNotifier<List<String>>(_defaultMessages);
  final isProcessing = ValueNotifier<bool>(false);
  bool _isProcessingValue = false;

  List<String> _defaults = _defaultMessages;

  void setMessages(List<String> newMessages) {
    messages.value = newMessages;
  }

  void setDefaults(List<String> newDefaults) {
    _defaults = newDefaults;
  }

  void clearMessages() {
    messages.value = _defaults;
  }
}
