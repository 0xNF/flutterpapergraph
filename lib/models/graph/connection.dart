typedef ConnectionLink = String;

extension C on ConnectionLink {
  String from() {
    return split('-')[0];
  }

  String to() {
    return split('-')[1];
  }
}
