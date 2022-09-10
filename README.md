# signal-mqtt
Docker image to send and receive messages for the [Signal](https://signal.org/) messenger via MQTT.

## Quick start
1. Register or link your Signal account
2. Start a container to send and receive messages via MQTT.

## Usage
### Docker Compose
1. Create a run configuration `docker-compose.yml`, e.g.
    ```yaml
    ---
    services:
      signal-mqtt:
        image: ckware/signal-mqtt
        container_name: signal-mqtt
        restart: unless-stopped
        init: true
        user: "nobody:nogroup"
        environment:
          MQTT_PUBLISH_OPTIONS: "-h broker -i signal-receiver"
          MQTT_SUBSCRIBE_OPTIONS: "-h broker -i signal-sender"
        volumes:
        - "./data:/home/.local/share/signal-cli"
    ```

2. Start a container:
    ```sh
    $ docker-compose up -d
    ```

### Result
```sh
$ mosquitto_sub -v -h broker -t signal/#
signal/receive/491713920000 Incoming message
signal/send/491713920000 Outgoing message
```

## Requirements
* A phone number that is registered as a Signal account (see [Registration with captcha](https://github.com/AsamK/signal-cli/wiki/Registration-with-captcha))
* Docker Compose

The Docker Compose [documentation](https://docs.docker.com/compose/install/)
contains a comprehensive guide explaining several install options. On recent debian-based systems, Docker Compose may be installed by calling
  ```sh
  $ sudo apt install docker-compose
  ```

## Configuration
The configuration is based on environment variables.

|Variable|Description|Allowed values|Default|Example
|--------|-----------|-----|-------|-------
|`MQTT_TOPIC_PREFIX`|Prefix for MQTT topics|[Topic names](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718106)|`signal`|`chats`
|`MQTT_PUBLISH_OPTIONS`|MQTT publish options|All options [supported by `mosquitto_pub`](https://mosquitto.org/man/mosquitto_pub-1.html) except `-t` and `-m`|_none_|`-h broker -id signal-publisher`
|`MQTT_PUBLISH_TOPIC`|MQTT topic for publishing messages received from Signal|[Topic names](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718106)|`${MQTT_TOPIC_PREFIX}/receive`|`chats/from`
|`MQTT_PUBLISH_JSON_RESPONSE`|Publish all json-rpc responses from signal-cli?|`true` / `false`|`false`|`true`
|`MQTT_PUBLISH_TOPIC_PER_SOURCE_NUMBER`|Publish incoming messages to a separate MQTT topic per sender?|`true`/ `false`|`true`|`false`
|`MQTT_SUBSCRIBE_OPTIONS`|MQTT subscribe options|All options [supported by `mosquitto_sub`](https://mosquitto.org/man/mosquitto_sub-1.html) except `-t` and formatting-related options like  `-F` & `-N`|_none_|`-h broker -i signal-subscriber`
|`MQTT_SUBSCRIBE_TOPIC`|MQTT topic to listen for messages that are sent to a Signal receiver|[Topic names](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718106)|`${MQTT_TOPIC_PREFIX}/send`|`chats/to`
|`MQTT_LOG`|Enable logging via MQTT?|`true` / `false`|`false`|`true`
|`MQTT_LOG_TOPIC`|MQTT topic to publish the log to|`${MQTT_TOPIC_PREFIX}/log`|`chats/logs`
|`SIGNAL_ACCOUNT`|Phone number of the signal account|International phone number format with leading `+`|Account from signal-cli configuration|`+493023125000`
|`DEBUG`|Enable debug logging?|`true` / `false`|`false`|`true`
|`TRACE`|Enable trace logging?|`true` / `false`|`false`|`true`

## Examples
### Text messages, topic per number
```sh
$ mosquitto_sub -v -h broker -t signal/#
# The text 'Incoming message' is sent from mobile phone +491713920000 to +493023125000
signal/receive/491713920000 Incoming message
# The text 'Outgoing message' is published to MQTT topic 'signal/send/491713920000'
signal/send/491713920000 Outgoing message
```

### signal-cli json-rpc messages
Options:
- `MQTT_PUBLISH_JSON_RESPONSE: "true"`

```sh
$ mosquitto_sub -v -h broker -t signal/#
# The user starts to type 'Incoming message' on mobile phone +491713920000
signal/receive {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1662783654115,"typingMessage":{"action":"STARTED","timestamp":1662783654115}},"account":"+493023125000","subscription":0}}
# The text 'Incoming message' is completed
signal/receive {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1662783660699,"typingMessage":{"action":"STOPPED","timestamp":1662783660699}},"account":"+493023125000","subscription":0}}
# The message is sent to +493023125000
signal/receive {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1662783663560,"dataMessage":{"timestamp":1662783663560,"message":"Incoming message","expiresInSeconds":0,"viewOnce":false}},"account":"+493023125000","subscription":0}}
signal/receive/491713920000 Incoming message
# The text 'Outgoing message' is published to MQTT topic 'signal/send/491713920000'
signal/send/491713920000 Outgoing message
# The message was delivered to mobile phone +491713920000
signal/receive {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1662783706642,"receiptMessage":{"when":1662783706642,"isDelivery":true,"isRead":false,"isViewed":false,"timestamps":[1662783708533]}},"account":"+493023125000","subscription":0}}
# The message was read on mobile phone +491713920000
signal/receive {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1662783706824,"receiptMessage":{"when":1662783706824,"isDelivery":false,"isRead":true,"isViewed":false,"timestamps":[1662783708533]}},"account":"+493023125000","subscription":0}}
```

## Advanced usage
* Run a signal-cli command: `$ docker-compose run signal-mqtt signal-cli <command>`
  * Example: `$ docker-compose run signal-mqtt signal-cli --help`



## FHEM integration
This section contains example configurations to send and receive Signal messages within [FHEM](https://fhem.de/).

### Using a `MQTT2_DEVICE`
```
define mosquitto MQTT2_CLIENT localhost:1883

define mqtt_signal MQTT2_DEVICE
attr   mqtt_signal readingList signal/receive/.* { return { 'from_'.(split('/', $TOPIC))[-1] => $EVTPART0 } }
```

## References
* This project is an integration of
  * [signal-cli](https://github.com/AsamK/signal-cli/) - A commandline interface for [Signal](https://signal.org/)
  * [Mosquitto](https://mosquitto.org/) - An Open Source MQTT Broker
  * The [OCI image](https://github.com/opencontainers/image-spec) format 
  * [Docker](https://www.docker.com)

* It was inspired by
  * [signal-cli-rest-api](https://github.com/bbernhard/signal-cli-rest-api)
  * [mqtt-signal-cli-gateway](https://github.com/woifes/mqtt-signal-cli-gateway)
  * [Making a Signal bot](https://codingindex.xyz/2021/06/06/making-a-signal-bot/)
