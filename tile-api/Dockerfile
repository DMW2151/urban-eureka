# NOTE: https://github.com/aws/aws-graviton-getting-started/blob/main/golang.md

ARG BUILDPATH='/build/tileserver/cmd'

FROM golang:1.16 as builder

ARG BUILDPATH

WORKDIR $BUILDPATH

# Copy code in && fetch dependencies
COPY . ./

RUN go mod download

# Tile API
RUN cd ./cmd/tiles && CGO_ENABLED=0;GOOS=linux;GOARCH=arm64 go build -o tiles

# Create final imag
FROM alpine:latest
    
ARG BUILDPATH
WORKDIR $BUILDPATH

COPY --from=builder $BUILDPATH .

CMD ["./cmd/tiles/tiles"]