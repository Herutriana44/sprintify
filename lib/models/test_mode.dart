enum TestMode {
  videoOnly,
}

extension TestModeLabel on TestMode {
  String get label {
    switch (this) {
      case TestMode.videoOnly:
        return 'Video saja';
    }
  }
}
