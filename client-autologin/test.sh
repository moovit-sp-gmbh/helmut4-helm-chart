#!/bin/sh
# Offline checks for the parsing logic in claim-autologin.sh. No network, no framework.
set -eu

cd "$(dirname "$0")"
CLAIM_LIB_ONLY=1 . ./claim-autologin.sh

fail=0

assert_eq() {
	if [ "$2" = "$3" ]; then
		echo "ok   - $1"
	else
		echo "FAIL - $1: expected '$3', got '$2'"
		fail=1
	fi
}

# Response headers arrive CRLF-terminated and the scheme may or may not be spelled out.
headers_with_bearer=$(printf 'HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAuthorization: Bearer jwt.token.value\r\n\r\n')
headers_bare=$(printf 'HTTP/1.1 200 OK\r\nauthorization: jwt.token.value\r\n\r\n')
headers_none=$(printf 'HTTP/1.1 401 Unauthorized\r\n\r\n')

assert_eq "parse_token strips the Bearer prefix" \
	"$(printf '%s\n' "$headers_with_bearer" | parse_token)" "jwt.token.value"
assert_eq "parse_token accepts a bare token and a lowercased header" \
	"$(printf '%s\n' "$headers_bare" | parse_token)" "jwt.token.value"
assert_eq "parse_token yields nothing when the header is absent" \
	"$(printf '%s\n' "$headers_none" | parse_token)" ""

# Only free users, only the requested prefix — nested group/product ids must not leak through.
assert_eq "free_user_ids returns just the disconnected matches" \
	"$(free_user_ids linux-render- < fixtures/users-search.json | tr '\n' ' ')" \
	"6603d6df04348000010262d2 6603d6df04348000010262d3 "
assert_eq "free_user_ids honours a narrower prefix" \
	"$(free_user_ids linux-transcode- < fixtures/users-search.json)" \
	"6603d6df04348000010262d4"
assert_eq "free_user_ids returns nothing for an unknown prefix" \
	"$(free_user_ids nope- < fixtures/users-search.json)" ""

# The claim index is fed straight to `sed -n Np`, so it must never fall outside 0..n-1.
i=0
out_of_range=""
while [ "$i" -lt 50 ]; do
	n=$(rand_below 3)
	case "$n" in
		0 | 1 | 2) ;;
		*) out_of_range="$n"; break ;;
	esac
	i=$((i + 1))
done
assert_eq "rand_below stays within bounds" "$out_of_range" ""

exit "$fail"
