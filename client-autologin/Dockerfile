FROM alpine:3.22

RUN apk add --no-cache curl jq

COPY claim-autologin.sh /usr/local/bin/claim-autologin
RUN chmod 0555 /usr/local/bin/claim-autologin

# Nothing here needs root; the client container that consumes the file runs as 0.
USER 65532:65532

ENTRYPOINT ["/usr/local/bin/claim-autologin"]
