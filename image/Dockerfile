FROM alpine
RUN apk --no-cache add jq mosquitto-clients gcompat
RUN apk --no-cache --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing add signal-cli
COPY signal-mqtt /opt/
ENV XDG_DATA_HOME=/home/.local/share
CMD /opt/signal-mqtt
