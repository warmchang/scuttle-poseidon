FROM docker.io/golang:1.24.3 AS builder
COPY . src
RUN cd src && make build

FROM docker.io/alpine:3.22.0
LABEL maintainer="Dalton Hubble <dghubble@gmail.com>"
LABEL org.opencontainers.image.title="scuttle",
LABEL org.opencontainers.image.source="https://github.com/poseidon/scuttle"
LABEL org.opencontainers.image.vendor="Poseidon Labs"

RUN apk --no-cache --update add ca-certificates
COPY --from=builder /go/src/bin/scuttle /usr/local/bin
ENTRYPOINT ["/usr/local/bin/scuttle"]
