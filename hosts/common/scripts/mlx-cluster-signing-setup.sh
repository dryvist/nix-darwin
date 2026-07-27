# One-time per host: create the code-signing identity the MLX cluster binaries
# are signed with, so their macOS privacy grants survive a rebuild.
#
# MUST be run in the host's own GUI login session (Terminal on that Mac, or over
# Screen Sharing). Over ssh the trust step fails with "User interaction is not
# allowed" — the authorization dialog has nowhere to appear.
#
# Not run by activation, and deliberately so: it needs a keychain unlock and a
# trust decision, and neither belongs in an automated converge.
#
# Three details below were each found by hitting them:
#
#   1. keyUsage=digitalSignature is REQUIRED. Without it the identity imports
#      and appears in the keychain, but `find-identity -v -p codesigning`
#      reports "(Invalid Key Usage for policy)" and codesign refuses to use it.
#      extendedKeyUsage alone is NOT enough.
#   2. The legacy PKCS12 algorithms are required. OpenSSL 3 defaults to
#      AES-256 + SHA-256, which macOS `security import` rejects outright with
#      "MAC verification failed (wrong password?)" — a misleading message, since
#      the password is fine.
#   3. The certificate must be TRUSTED for code signing before codesign will
#      accept it; importing alone leaves `find-identity` reporting nothing.
#
# The private key never leaves this host. Trust is scoped to code signing only,
# in the user's login keychain — not the system domain.
set -o errexit -o nounset

dir="$HOME/Library/Application Support/mlx-cluster/signing"
name="mlx-cluster-signing"
# Protects the PKCS12 bundle for the seconds between export and import; the
# bundle is deleted immediately after. It is not a secret and guards nothing at
# rest.
transport_pw="mlxcluster"

mkdir -p "$dir"
cd "$dir"

if security find-identity -v -p codesigning 2> /dev/null | grep -q "$name"; then
  echo "signing: '$name' already present and valid — nothing to do."
  exit 0
fi

echo "signing: generating a self-signed code-signing certificate..."
openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 3650 -nodes \
  -subj "/CN=$name" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "basicConstraints=critical,CA:false"

echo "signing: packaging for macOS (legacy algorithms — see header)..."
openssl pkcs12 -export -out b.p12 -inkey key.pem -in cert.pem \
  -passout "pass:$transport_pw" -name "$name" \
  -certpbe PBE-SHA1-3DES -keypbe PBE-SHA1-3DES -macalg sha1

echo "signing: importing into the login keychain..."
security import b.p12 -k "$HOME/Library/Keychains/login.keychain-db" \
  -P "$transport_pw" -T /usr/bin/codesign -A

# Lets codesign use the key without prompting on every run. Non-fatal: if it
# fails, codesign still works, it just may ask.
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  "$HOME/Library/Keychains/login.keychain-db" > /dev/null 2>&1 \
  || echo "signing: WARN could not set the key partition list; codesign may prompt" >&2

echo "signing: trusting the certificate for code signing (expect an auth prompt)..."
security add-trusted-cert -r trustRoot -p codeSign \
  -k "$HOME/Library/Keychains/login.keychain-db" cert.pem

rm -f b.p12

echo
if security find-identity -v -p codesigning 2> /dev/null | grep "$name"; then
  echo
  echo "signing: OK — run darwin-rebuild and the cluster binaries get this identity."
else
  echo "signing: FAILED — the identity is not valid for code signing." >&2
  echo "If it lists with '(Invalid Key Usage for policy)', the certificate was" >&2
  echo "generated without keyUsage=digitalSignature; delete it and re-run." >&2
  exit 1
fi
