#!/bin/sh
# Claims a free Helmut render-node user and writes its autologin file, so Linux
# client pods stay interchangeable and can be scaled by an HPA.
set -eu

: "${AUTOLOGIN_PATH:=/autologin/helmut.auto.login}"
: "${CLAIM_RETRIES:=10}"
: "${CLAIM_RETRY_DELAY:=10}"
: "${CLAIM_JITTER_SECONDS:=15}"

log() { echo "claim-autologin: $*" >&2; }

die() { log "$*"; exit 1; }

# Random 0..$1-1. /dev/urandom, not $RANDOM or jq's `now` — pods starting in the
# same second must not land on the same slot.
rand_below() {
	[ "$1" -gt 0 ] || die "rand_below: bad bound $1"
	echo $(( $(od -An -N2 -tu2 < /dev/urandom | tr -d ' ') % $1 ))
}

# JWT out of the `Authorization` response header, with or without a Bearer prefix.
parse_token() {
	awk 'tolower($1) == "authorization:" { sub(/^[^:]*:[[:space:]]*/, ""); print }' \
		| tr -d '\r' \
		| sed 's/^[Bb]earer[[:space:]]*//'
}

# Ids of users matching $1 that no client is currently connected as, one per line.
free_user_ids() {
	jq -r --arg p "$1" '
		.[]
		| select(.username | startswith($p))
		| select(.isConnected | not)
		| .id
	'
}

login() {
	curl -sS -f -D - -o /dev/null \
		-X POST "$MCC_USERS_URL/auth/login/body" \
		-H 'Content-Type: application/json' \
		--data "$(jq -nc --arg u "$ADMIN_USERNAME" --arg p "$ADMIN_PASSWORD" \
			'{username: $u, password: $p}')" \
		| parse_token
}

claim_id() {
	curl -sS -f \
		-H "Authorization: Bearer $1" \
		"$MCC_USERS_URL/users/search/$USER_PREFIX?groupFilter=All&limit=1000" \
		| free_user_ids "$USER_PREFIX"
}

# The autologin file embeds the endpoints the client will talk to; they come from
# the chart's service-config ConfigMap, so they always match the deployed release.
generate_autologin() {
	curl -sS -f -o "$AUTOLOGIN_PATH" \
		-X POST "$MCC_USERS_URL/users/autologin/generate/$2" \
		-H "Authorization: Bearer $1" \
		-H 'Content-Type: application/json' \
		--data "$(jq -nc \
			--arg users "$MCC_USERS_URL" \
			--arg streams "$MCC_STREAM_URL" \
			--arg io "$MCC_IO_URL" \
			'{usersEndpoint: $users, streamsEndpoint: $streams, ioEndpoint: $io}')"
}

main() {
	for v in MCC_USERS_URL MCC_STREAM_URL MCC_IO_URL USER_PREFIX ADMIN_USERNAME ADMIN_PASSWORD; do
		eval "[ -n \"\${$v:-}\" ]" || die "$v is not set"
	done

	# Spread the herd before the first read, so replicas scaled up together see
	# each other's claims instead of racing on an identical free list.
	sleep "$(rand_below $((CLAIM_JITTER_SECONDS + 1)))"

	attempt=1
	while :; do
		token=$(login) || die "login as '$ADMIN_USERNAME' failed"
		[ -n "$token" ] || die "login returned no Authorization header"

		ids=$(claim_id "$token") || die "user search for prefix '$USER_PREFIX' failed"
		count=$(printf '%s\n' "$ids" | grep -c . || true)

		if [ "$count" -gt 0 ]; then
			id=$(printf '%s\n' "$ids" | sed -n "$(( $(rand_below "$count") + 1 ))p")
			log "claiming user $id ($count free for prefix '$USER_PREFIX')"
			generate_autologin "$token" "$id" || die "autologin generation for $id failed"
			[ -s "$AUTOLOGIN_PATH" ] || die "autologin file is empty"
			log "wrote $AUTOLOGIN_PATH"
			return 0
		fi

		[ "$attempt" -lt "$CLAIM_RETRIES" ] \
			|| die "no free user for prefix '$USER_PREFIX' after $attempt attempts — pool exhausted"
		log "no free user for prefix '$USER_PREFIX', retry $attempt/$CLAIM_RETRIES"
		attempt=$((attempt + 1))
		sleep "$CLAIM_RETRY_DELAY"
	done
}

[ "${CLAIM_LIB_ONLY:-}" = 1 ] || main "$@"
