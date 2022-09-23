FROM alpine
RUN apk --no-cache add jq mosquitto-clients gcompat
RUN apk --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing add signal-cli
COPY signal-mqtt conversion.jq /opt/
ENV XDG_DATA_HOME=/home/.local/share
WORKDIR /opt
CMD /opt/signal-mqtt
