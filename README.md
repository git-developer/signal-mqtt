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
    signal/in/method/receive/source_number/%2B491713920000/timestamp/1577882096000 Incoming message
    $ mosquitto_pub -v -h broker -t signal/out/method/send/recipient/%2B491713920000 -m 'Outgoing message'
    signal/out/method/send/recipient/%2B491713920000 Outgoing message
    ```

## Requirements
* A phone number that is registered as a Signal account
  (see [Registration with captcha](https://github.com/AsamK/signal-cli/wiki/Registration-with-captcha))
* Docker Compose


  The Docker Compose [documentation](https://docs.docker.com/compose/install/)
  contains a comprehensive guide explaining several install options.
  On recent debian-based systems, Docker Compose may be installed by calling
  ```sh
  $ sudo apt install docker-compose
  ```

## Topic formatting
MQTT topics have the following structure by default:

  _\<PREFIX>_`/`_\<DIRECTION>_`/method/`_\<METHOD>_[`/`_\<PARAMETER_NAME>_`/`_\<PARAMETER_VALUE>_]...

- A prefix, defaulting to `signal`
- The direction, defaulting to either `in` or `out`
- The rpc method, e.g. `send` or `receive`
- An optional list of parameters
  - Each parameter consists of a name and a value.
  - The name is a simple text.
  - The value is either a scalar value or a comma-separated list of scalar values.
    The value may be suffixed by a type-id if required.
    All scalar values are percent-encoded.

### Percent encoding
Some of the values, e.g. international account numbers and base64 encoded group ids,
may include special characters which are forbidden as part of an MQTT topic.
Thus, all values in MQTT topics are percent-encoded (aka URL-encoded).

Example: topic `signal/out/method/send/recipient/%2B491713920000` contains parameter _recipient_ with value `+491713920000`.

Characters with a special meaning in the context of MQTT, base64 and percent-encoding include:

| Character | Percent Encoding |
| ---       | ---      |
|    `#`    |  `%23`   |
|    `$`    |  `%24`   |
|    `%`    |  `%25`   |
|    `+`    |  `%2B`   |
|    `,`    |  `%2C`   |
|    `/`    |  `%2F`   |
|    `=`    |  `%3D`   |

### Explicit typing
By default, a parameter's type is derived from its value.
When the default type does not match the expected type,
the value must be suffixed by a colon (`:`) and a type-id:

_\<PARAMETER>_`/`_\<PERCENT_ENCODED_VALUE>_`:`_\<TYPE_ID>_

Some parameters allow multiple values;
these may be represented by a comma-separated list of multiple values:

_\<PARAMETER>_`/`_\<PERCENT_ENCODED_VALUE1>_`,`_\<PERCENT_ENCODED_VALUE2>_`:`_\<TYPE_ID>_

Type Rules:

- The supported type-ids are `string`, `number`, `boolean`.
  Each type-id may be suffixed with `[]` which means that the value is a list.
- When a value contains digits only, its default type is `number`, otherwise `string`.
- The type-id may be abbreviated.
  For example, `string`, `str` and `s` are all valid type-ids for type `string`, 
- In a comma-separated value list, the type-id suffix `[]` may be omitted.

| Type      | type-id     | JSON syntax      | Topic syntax
| ---       | ---         | ---              |  ---
| String    | `string`    | `"foo"`          | `foo` or `foo:s` or `foo:string`
| Number    | `number`    | `123`            | `123` or `123:n` or `123:number`
| Boolean   | `boolean`   | `true`           | `true:b` or `true:boolean`
| String[]  | `string[]`  | `["foo", "bar"]` | `foo,bar` or `foo,bar:s` or `foo,bar:s[]` or `foo,bar:string[]`
|           |             | `["foo"]`        | `foo:s[]`
| Number[]  | `number[]`  | `[123, 456]`     | `123,456` or `123,456:n` or `123,456:n[]` or `123,456:number[]`
|           |             | `[123]`          | `123:n[]`
| Boolean[] | `boolean[]` | `[true, false]`  | `true,false:b` or `true,false:b[]`
|           |             | `[true]`         | `true:b[]` 

Example:
- Topic: `signal/out/method/send/recipient/%2B491713920000,%2B491713920001/quoteTimestamp/1577882096000:n`
- Parameter _recipient_ contains a `string` array of the two phone numbers `+491713920000` and `+491713920001`;
  parameter _quoteTimestamp_ is explicitely typed as `number` (although the default would work here, too).

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
* Topic: `<MQTT_SUBSCRIBE_TOPIC>/method/send/recipient/<PHONE_NUMBER>`
* Example:
  ```sh
  $ mosquitto_pub -h broker -t signal/out/method/send/recipient/%2B491713920000 -m 'Outgoing message'
  ```
  The text _Outgoing message_ is sent to the phone.

#### Send a text message to a group
* Topic: `<MQTT_SUBSCRIBE_TOPIC>/method/send/groupId/<GROUP_ID>`
* Example:
  ```sh
  $ mosquitto_pub -h broker -t signal/out/method/send/groupId/LS0%2BYWRtaW5zPz8%2FCg%3D%3D -m 'Outgoing message'
  ```
  The text _Outgoing message_ is sent to the group _Admins_.

#### Send a JSON-RPC command
* Topic: `<MQTT_SUBSCRIBE_TOPIC>/method/<METHOD>[/PARAM_NAME/PARAM_VALUE]...`
* Example 1:
  ```sh
  $ mosquitto_pub -h broker -t signal/out/method/send/recipient/%2B491713920000 -m 'Outgoing message'
  ```
  The text _Outgoing message_ is sent to the phone.
* Example 2:
  ```sh
  $ mosquitto_pub -h broker -t signal/out/method/send/recipient/%2B491713920000/quoteAuthor/%2B491713920000/quoteTimestamp/1577882096000 -m 'Outgoing message'
  ```
  The text _Outgoing message_ is sent to the phone quoting a message sent from the phone at timestamp 1577882096000.

#### Send a JSON-RPC message
* Topic: `<MQTT_SUBSCRIBE_TOPIC>`
* Example:
  ```sh
  $ mosquitto_pub -h broker -t signal/out -m '{"jsonrpc":"2.0","method":"send","params":{"recipient":["+491713920000"],"message":"Outgoing message"}}'
  ```
  The text _Outgoing message_ is sent to the phone.


#### Receive a text message
* Topic: `<MQTT_PUBLISH_TOPIC>/method/receive/source_number/<PHONE_NUMBER>/timestamp/<TIMESTAMP>`
* Example:
  The text _Incoming message_ is sent from the phone to `+493023125000`.
  ```sh
  $ mosquitto_sub -v -h broker -t signal/#
  signal/in/method/receive/source_number/%2B491713920000/timestamp/1577882096000 Incoming message
  ```

#### Receive a text message from a group
* Topic: `<MQTT_PUBLISH_TOPIC>/method/receive/source_number/<PHONE_NUMBER>/timestamp/<TIMESTAMP>/group_id/<GROUP_ID>`
* Example:
  The text _Incoming message_ is sent from the phone to the group _Admins_.
  ```sh
  $ mosquitto_sub -v -h broker -t signal/#
  signal/in/method/receive/source_number/%2B491713920000/timestamp/1577882096000/group_id/LS0%2BYWRtaW5zPz8%2FCg%3D%3D Incoming message
  ```

#### Receive a quotation message
* Topic: `<MQTT_PUBLISH_TOPIC>/method/receive/source_number/<PHONE_NUMBER>/timestamp/<TIMESTAMP>/quote_id/<TIMESTAMP_OF_QUOTED_MESSAGE>`
* Example:
  The text _Incoming quote_ is sent from the phone as quotation to the message _Outgoing message_ from above.
  ```sh
  $ mosquitto_sub -v -h broker -t signal/#
  signal/in/method/receive/source_number/%2B491713920000/timestamp/1577882100000/quote_id/1577882096000 Incoming quote
  ```

#### Receive a reaction (emoji)
* Topic: `<MQTT_PUBLISH_TOPIC>/method/receive/source_number/<PHONE_NUMBER>/timestamp/<TIMESTAMP>/reaction_emoji/<EMOJI>/reaction_timestamp/<TIMESTAMP_OF_ORIGINAL_MESSAGE>`
* Example:
  The emoji 👍 is sent from the phone as reaction to the message _Outgoing message_ from above.
  ```sh
  $ mosquitto_sub -v -h broker -t signal/#
  signal/in/method/receive/source_number/%2B491713920000/timestamp/1577882100000/reaction_emoji/%F0%9F%91%8D%F0%9F%8F%BB/reaction_timestamp/1577882096000 (null)
  ```

#### Receive JSON-RPC messages
* Required configuration option: `MQTT_PUBLISH_JSON_RESPONSE: "true"`
  To suppress incoming messages on parameter topics, also set `MQTT_PUBLISH_TO_PARAMETER_TOPIC: "false"`
* Topic: `<MQTT_PUBLISH_TOPIC>`
* Example:
  ```sh
  $ mosquitto_sub -v -h broker -t 'signal/#' &
  # The user starts to type 'Incoming message' on the phone
  signal/in {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1577882080000,"typingMessage":{"action":"STARTED","timestamp":1577882080000}},"account":"+493023125000","subscription":0}}
  # The text 'Incoming message' is completed
  signal/in {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1577882090000,"typingMessage":{"action":"STOPPED","timestamp":1577882090000}},"account":"+493023125000","subscription":0}}
  # The message is sent to +493023125000
  signal/in {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1577882096000,"dataMessage":{"timestamp":1577882096000,"message":"Incoming message","expiresInSeconds":0,"viewOnce":false}},"account":"+493023125000","subscription":0}}

  $ mosquitto_pub -h broker -t signal/out/method/send/recipient/%2B491713920000 -m 'Outgoing message'
  signal/out/method/send/recipient/%2B491713920000 Outgoing message
  # The message was delivered to mobile phone +491713920000
  signal/in {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1577882097000,"receiptMessage":{"when":1577882097000,"isDelivery":true,"isRead":false,"isViewed":false,"timestamps":[1577882098000]}},"account":"+493023125000","subscription":0}}
  # The message was read on mobile phone +491713920000
  signal/in {"jsonrpc":"2.0","method":"receive","params":{"envelope":{"source":"+491713920000","sourceNumber":"+491713920000","sourceUuid":"3689ed97-01b2-4fa5-8ed8-18174ad5cf15","sourceName":"Sally Sender","sourceDevice":1,"timestamp":1577882099000,"receiptMessage":{"when":1577882099000,"isDelivery":false,"isRead":true,"isViewed":false,"timestamps":[1577882098000]}},"account":"+493023125000","subscription":0}}
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
|`MQTT_PUBLISH_TOPIC`|MQTT topic for publishing messages received from Signal|[Topic names](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718106)|`${MQTT_TOPIC_PREFIX}/in`|`chats/from`
|`MQTT_PUBLISH_JSON_RESPONSE`|Publish json-rpc responses from signal-cli?|`true` / `false`|`false`|`true`
|`MQTT_PUBLISH_TO_PARAMETER_TOPIC`|Publish received messages to a topic created from the message parameters?|`true` / `false`|`true`|`false`
|`MQTT_SUBSCRIBE_OPTIONS`|MQTT subscribe options|All options [supported by `mosquitto_sub`](https://mosquitto.org/man/mosquitto_sub-1.html) except `-t` and formatting-related options like  `-F` & `-N`|_none_|`-h broker -i signal-subscriber`
|`MQTT_SUBSCRIBE_TOPIC`|MQTT topic to listen for messages that are sent to a Signal receiver|[Topic names](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718106)|`${MQTT_TOPIC_PREFIX}/out`|`chats/to`
|`MQTT_LOG`|Enable logging via MQTT?|`true` / `false`|`false`|`true`
|`MQTT_LOG_TOPIC`|MQTT topic to publish the log to|`${MQTT_TOPIC_PREFIX}/log`|`chats/logs`
|`SIGNAL_ACCOUNT`|Phone number of the signal account|International phone number format with leading `+`|Account from signal-cli configuration|`+493023125000`
|`LOG_JSONRPC`|Enable logging of JSON RPC messages?|`true` / `false`|`false`|`true`
|`DEBUG`|Enable debug logging?|`true` / `false`|`false`|`true`
|`TRACE`|Enable trace logging?|`true` / `false`|`false`|`true`

## FHEM integration
This section contains example configurations to send and receive Signal messages within [FHEM](https://fhem.de/).

### Using a `MQTT2_DEVICE`
```
define mosquitto MQTT2_CLIENT localhost:1883

define mqtt_signal MQTT2_DEVICE
attr   mqtt_signal readingList signal/in/.* { return { 'from_'.(split('/', $TOPIC))[-1] => $EVTPART0 } }
```

## References
* This project is an integration of
  * [signal-cli](https://github.com/AsamK/signal-cli/) - A commandline interface for [Signal](https://signal.org/)
  * [jq](https://stedolan.github.io/jq/) - A lightweight and flexible command-line JSON processor
  * [Mosquitto](https://mosquitto.org/) - An Open Source MQTT Broker
  * The [OCI image](https://github.com/opencontainers/image-spec) format 
  * [Docker](https://www.docker.com)

* It was inspired by
  * [signal-cli-rest-api](https://github.com/bbernhard/signal-cli-rest-api)
  * [mqtt-signal-cli-gateway](https://github.com/woifes/mqtt-signal-cli-gateway)
  * [Making a Signal bot](https://codingindex.xyz/2021/06/06/making-a-signal-bot/)
