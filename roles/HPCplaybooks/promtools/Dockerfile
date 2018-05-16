FROM golang:1.9-stretch

MAINTAINER Egon Rijpkema <e.m.a.rijpkema@rug.nl>

RUN mkdir /results

RUN go get github.com/prometheus/node_exporter && \
    cd ${GOPATH-$HOME/go}/src/github.com/prometheus/node_exporter && \
    make && \
    cp node_exporter /results

RUN go get github.com/robustperception/pushprox/proxy && \
    cd ${GOPATH-$HOME/go}/src/github.com/robustperception/pushprox/proxy && \
    go build && \
    cp /go/bin/proxy /results

RUN go get github.com/robustperception/pushprox/client && \
    cd ${GOPATH-$HOME/go}/src/github.com/robustperception/pushprox/client && \
    go build && \
    cp /go/bin/client /results

CMD /go/bin/proxy
