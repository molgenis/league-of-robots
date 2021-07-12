FROM golang:1.15-buster

MAINTAINER Egon Rijpkema <e.m.a.rijpkema@rug.nl>

RUN mkdir /results

RUN go get github.com/godbus/dbus

RUN go get github.com/prometheus/node_exporter && \
    cd ${GOPATH-$HOME/go}/src/github.com/prometheus/node_exporter && \
    make && \
    cp node_exporter /results

RUN go get github.com/vpenso/prometheus-slurm-exporter && \
    cd ${GOPATH-$HOME/go}/src/github.com/vpenso/prometheus-slurm-exporter && \
    go build && \
    cp /go/bin/prometheus-slurm-exporter /results

RUN go get github.com/lovoo/ipmi_exporter && \
    cd ${GOPATH-$HOME/go}/src/github.com/lovoo/ipmi_exporter && \
    go build && \
    cp /go/bin/ipmi_exporter /results

CMD tail -f /dev/null
