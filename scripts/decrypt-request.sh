#!/usr/bin/env bash
set -euo pipefail

CONTROL_ROOT="${1:?control root required}"
ENVELOPE="${2:?encrypted request bundle required}"
OUTPUT_DIR="${3:?output directory required}"
CERT="$CONTROL_ROOT/config/request-encryption-cert.pem"

fail(){ echo "::error::$*" >&2; exit 1; }
: "${SOURCE_COMMIT_DECRYPT_KEY:?SOURCE_COMMIT_DECRYPT_KEY is required}"

[[ -f "$CERT" ]] || fail "Encryption certificate missing"
[[ -f "$ENVELOPE" && -s "$ENVELOPE" ]] || fail "Encrypted request bundle missing"
[[ "$(wc -c < "$ENVELOPE")" -le 4194304 ]] || fail "Encrypted request bundle is too large"

tmp_dir="$(mktemp -d)"
key_file="$tmp_dir/private-key.pem"
cms_file="$tmp_dir/request.cms"
tar_file="$tmp_dir/request.tar.gz"

cleanup(){
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

umask 077
printf '%s\n' "$SOURCE_COMMIT_DECRYPT_KEY" > "$key_file"
base64 --decode "$ENVELOPE" > "$cms_file" || fail "Encrypted bundle is not valid base64"

openssl cms -decrypt -binary -inform DER   -in "$cms_file"   -recip "$CERT"   -inkey "$key_file"   -out "$tar_file" >/dev/null 2>&1 || fail "Unable to decrypt request bundle"

mapfile -t entries < <(tar -tzf "$tar_file")
[[ "${#entries[@]}" -eq 2 ]] || fail "Decrypted bundle must contain exactly manifest.json and changes.patch"
printf '%s\n' "${entries[@]}" | sort | diff -u <(printf 'changes.patch\nmanifest.json\n') - >/dev/null   || fail "Unexpected files in decrypted request bundle"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
tar -xzf "$tar_file" -C "$OUTPUT_DIR" manifest.json changes.patch
[[ -f "$OUTPUT_DIR/manifest.json" && -f "$OUTPUT_DIR/changes.patch" ]] || fail "Decrypted request is incomplete"
