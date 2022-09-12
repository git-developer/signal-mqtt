# signal-mqtt
Docker image to send and receive messages for the [Signal](https://signal.org/) messenger via MQTT.

## How to use
1. Register or link your Signal account.
1. Configure and start a container.
1. Send and receive messages via MQTT.

## Quick start
1. Create a run configuration `docker-compose.yml`, e.g.:
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

3. Send and receive messages:
    ```sh
    $ mosquitto_sub -v -h broker -t 'signal/#' &
    signal/receive/491713920000 Incoming message
    $ mosquitto_pub -v -h broker -t signal/send/491713920000 -m 'Outgoing message'
    signal/send/491713920000 Outgoing message
    ```

## Requirements
* A phone number that is registered as a Signal account (see [Registration with captcha](https://github.com/AsamK/signal-cli/wiki/Registration-with-captcha))
* Docker Compose


  The Docker Compose [documentation](https://docs.docker.com/compose/install/) contains a comprehensive guide explaining several install options. On recent debian-based systems, Docker Compose may be installed by calling
  ```sh
  $ sudo apt install docker-compose
  ```

## Commands

### Lifecycle commands
| Action | Command
| ------ | -------
| Start the container | `docker-compose up -d`
| Stop the container  | `docker-compose down`
| View the logs       | `docker-compose logs -f `

### MQTT commands
The following values are used in the examples:
* Account number of signal-mqtt: `+493023125000`
* Phone number: `+491713920000`
* Hostname of the MQTT broker: `broker`
* Group Name: _Admins_
* Group ID: `LS0+YWRtaW5zPz8/Cg==`

#### Send a text message
* Topic: `<TOPIC_PREFIX>/<MQTT_SUBSCRIBE_TOPIC>/<PHONE_NUMBER_WITHOUT_LEADING_PLUS>`
* Example:
  ```sh
  $ mosquitto_pub -h broker -t signal/send/491713920000 -m 'Outgoing message'
  ```
  The text _Outgoing message_ is sent to the phone.

#### Receive a text message
* Topic: `<TOPIC_PREFIX>/<MQTT_PUBLISH_TOPIC>/<PHONE_NUMBER_WITHOUT_LEADING_PLUS>`
* Example:
  The text _Incoming message_ is sent from the phone to `+493023125000`.
  ```sh
  $ mosquitto_sub -v -h broker -t signal/#
  signal/receive/491713920000 Incoming message
  ```

#### Send a text message to a group
* Topic: `<TOPIC_PREFIX>/<MQTT_SUBSCRIBE_TOPIC>/group/<BASE64URL_ENCODED_GROUP_ID>`
* Note: The group id (which is `base64` encoded) must be converted to `base64url` encoding
  by applying the following replacements:
  - `+` (plus) becomes `-` (minus)
  - `/` (slash) becomes `_` (underscore)
* Example:
  ```sh
  $ mosquitto_pub -h broker -t signal/send/group/LS0-YWRtaW5zPz8_Cg== -m 'Outgoing message'
  ```
  The text _Outgoing message_ is sent to the group _Admins_.

#### Receive a text message from a group
* Topic: `<TOPIC_PREFIX>/<MQTT_PUBLISH_TOPIC>/<PHONE_NUMBER_WITHOUT_LEADING_PLUS>/<BASE64URL_ENCODED_GROUP_ID>`
* Note: The last segment of the topic is `base64url` encoded.
  To retrieve the group id, it must be converted to `base64` encoding
  by applying the following replacements:
  - `-` (minus) becomes `+` (plus)
  - `_` (underscore) becomes `/` (slash)
* Example:
  The text _Incoming message_ is sent from the phone to the group _Admins_.
  ```sh
  $ mosquitto_sub -v -h broker -t signal/#
  signal/receive/491713920000/LS0-YWRtaW5zPz8_Cg== Incoming message
  ```

#### Send a JSON-RPC message
* Topic: `<TOPIC_PREFIX>/<MQTT_SUBSCRIBE_TOPIC>`
* Example:
  ```sh
  $ mosquitto_pub -h broker -t signal/send -m '{"jsonrpc":"2.0","method":"send","params":{"recipient":["+491713920000"],"message":"Outgoing message"}}'
  ```
  The text _Outgoing message_ is sent to the phone.

#### Receive JSON-RPC messages
* Topic: `<TOPIC_PREFIX>/<MQTT_PUBLISH_TOPIC>`
* Required configuration option: `MQTT_PUBLISH_JSON_RESPONSE: "true"`
* Example:
  ```sh
  $ mosquitto_sub -v -h broker -t 'signal/#' &
  # The user starts to type 'Incoming message' on the phone
  signal/receive {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1662783654115,"typingMessage":{"action":"STARTED","timestamp":1662783654115}},"account":"+493023125000","subscription":0}}
  # The text 'Incoming message' is completed
  signal/receive {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1662783660699,"typingMessage":{"action":"STOPPED","timestamp":1662783660699}},"account":"+493023125000","subscription":0}}
  # The message is sent to +493023125000
  signal/receive {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1662783663560,"dataMessage":{"timestamp":1662783663560,"message":"Incoming message","expiresInSeconds":0,"viewOnce":false}},"account":"+493023125000","subscription":0}}
  signal/receive/491713920000 Incoming message

  $ mosquitto_pub -h broker -t signal/send/491713920000 -m 'Outgoing message'
  signal/send/491713920000 Outgoing message
  # The message was delivered to mobile phone +491713920000
  signal/receive {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1662783706642,"receiptMessage":{"when":1662783706642,"isDelivery":true,"isRead":false,"isViewed":false,"timestamps":[1662783708533]}},"account":"+493023125000","subscription":0}}
  # The message was read on mobile phone +491713920000
  signal/receive {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1662783706824,"receiptMessage":{"when":1662783706824,"isDelivery":false,"isRead":true,"isViewed":false,"timestamps":[1662783708533]}},"account":"+493023125000","subscription":0}}
  ```

#### Run a signal-cli command
* Syntax: 
  ```sh
  $ docker-compose run signal-mqtt signal-cli <command>
  ```
* Example:
  ```sh
  $ docker-compose run --rm -ti signal-mqtt signal-cli listContacts
  Number: +491713920000 Name:  Profile name: Sally Sender Blocked: false Message expiration: disabled
  Number: +491713920001 Name:  Profile name: Rudy Receiver Blocked: false Message expiration: disabled
  ```
* Note: Most signal-cli commands require that no container is running.

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
