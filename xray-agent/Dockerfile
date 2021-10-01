ARG BUILDPATH='/xray'

FROM golang:1.16 as builder

ARG BUILDPATH
WORKDIR $BUILDPATH

RUN git clone https://github.com/aws/aws-xray-daemon.git

RUN cd aws-xray-daemon &&\
    GOOS=linux GOARCH=arm64 go build -ldflags "-s -w" -o xray cmd/tracing/daemon.go cmd/tracing/tracing.go


FROM amazonlinux

ARG BUILDPATH
WORKDIR $BUILDPATH

COPY --from=builder $BUILDPATH .

RUN yum install -y lsof curl

EXPOSE 2000/udp
EXPOSE 2000/tcp

ENTRYPOINT ["/xray/aws-xray-daemon/xray", "--log-level", "debug", "-t", "0.0.0.0:2000", "-b", "0.0.0.0:2000"]
