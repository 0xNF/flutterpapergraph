typedef ConnectionId = String;

extension C on ConnectionId {
  String from() {
    return split('-')[0];
  }

  String to() {
    return split('-')[1];
  }
}
