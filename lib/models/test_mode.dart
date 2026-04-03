enum TestMode {
  videoOnly,
  videoAndIot,
}

extension TestModeLabel on TestMode {
  String get label {
    switch (this) {
      case TestMode.videoOnly:
        return 'Video saja';
      case TestMode.videoAndIot:
        return 'Video + IoT';
    }
  }
}
