typedef Scope = String;
typedef OAuthURI = String;

class OAuthClient {
  final String clientId;
  final String name;
  final OAuthURI? redirectUri;
  final List<Scope> scopes;

  const OAuthClient({required this.clientId, required this.name, required this.redirectUri, required this.scopes});
}
