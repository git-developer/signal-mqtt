FROM alpine
RUN apk --no-cache add jq mosquitto-clients gcompat signal-cli
ENV HOME=/home
ENV XDG_DATA_HOME="${HOME}/.local/share"
COPY signal-mqtt /usr/local/bin/
COPY signal-mqtt.jq "${HOME}/.jq"
COPY topic-parameters /etc/signal-mqtt/
CMD signal-mqtt
