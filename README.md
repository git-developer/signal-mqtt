# signal-mqtt
signal-mqtt - An adapter between MQTT and signal-cli
[JSON RPC](https://github.com/AsamK/signal-cli/wiki/JSON-RPC-service).

This project allows to send and receive messages between MQTT clients and Signal messengers.
This includes, but is not limited to, sending and receiving of text messages,
quotations and emojis to/from Signal accounts and groups.
The signal-cli documentation contains a list of all
[supported commands](https://github.com/AsamK/signal-cli/blob/master/man/signal-cli.1.adoc#commands).

## Quick start
1. Register or link your Signal account.
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

1. Start a container:
    ```sh
    $ docker-compose up -d
    ```

1. Send and receive messages via MQTT:
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

## Usage
There are two different ways to use this service:
- Send and receive complete JSON RPC objects including content and metadata.
- Send and receive simple text messages and handle metadata as part of the MQTT topic (aka "parameter topics").

### Lifecycle commands
| Action | Command
| ------ | -------
| Start the container | `docker-compose up -d`
| Stop the container  | `docker-compose down`
| View the logs       | `docker-compose logs -f `

### Send and receive JSON RPC objects
Incoming and outgoing JSON RPC objects are published to a topic per direction.

| Direction | Default topic  | Environment variable
| ---       | ---            | ---
| Send      | `signal/out`   | `MQTT_SUBSCRIBE_TOPIC`
| Receive   | `signal/in`    | `MQTT_PUBLISH_TOPIC`

#### Send
To send a command, publish a JSON RPC object to the send topic (default: `signal/out`).

Example:
```sh
$ mosquitto_pub -h broker -t signal/out -m '{"jsonrpc":"2.0","method":"send","params":{"recipient":["+491713920000"],"message":"Outgoing message"}}'
```
The text _Outgoing message_ is sent to the phone.

#### Receive
To receive JSON RPC objects, subscribe to the receive topic (default: `signal/in`).

Reception of JSON RPC objects is disabled by default.
To enable it, set `MQTT_PUBLISH_JSONRPC` to `true`.
You may additionally want to disable reception of messages on parameter topics
by setting `MQTT_PUBLISH_TO_PARAMETER_TOPIC` to `false`.

Example:

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

### Send and receive messages via parameter topics
Parameter topics have been designed for use cases
where handling of complete JSON RPC objects is not suitable.
They allow to send and receive commands in form of simple text messages,
whereas all required metadata is managed in the MQTT topic.

#### Topic structure
A parameter topic has the following structure:

  _\<PREFIX>_`/method/`_\<METHOD>_[`/`_\<PARAMETER_NAME>_`/`_\<PARAMETER_VALUE>_]…

It is composed of:
- A prefix per direction,
  defaulting to `signal/out` for outgoing and `signal/in` for incoming MQTT messages
- The JSON RPC method, e.g. `send` or `receive`
- An optional list of parameters. Each parameter is composed of a name and a value.
  Parameters may be in any order.

#### Value encoding
Some parameter values, e.g. an international account number or a group id,
include special characters which are forbidden as part of an MQTT topic.
Thus, all values in parameter topics are percent-encoded (aka URL-encoded).

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


#### Send
To send a JSON RPC command, publish the message text to a topic that is composed of
* the send topic (default: `signal/out`) and
* the method (e.g. `method/send`) and
* all parameters of the command.

The signal-cli documentation contains a
[list of commands](https://github.com/AsamK/signal-cli/blob/master/man/signal-cli.1.adoc#commands)
and parameters. Syntax rules:
* Parameter names are provided in camelCase format instead of the hyphen-format.
* Multi-valued parameters can be provided as comma-separated list.

See the
[signal-cli wiki](https://github.com/AsamK/signal-cli/wiki/JSON-RPC-service#commands)
for detailed explanations of commands and parameters.

##### Examples
The following values are used in the examples:
* Account number of signal-mqtt: `+493023125000`
* Phone number: `+491713920000`
* Hostname of the MQTT broker: `broker`
* Group Name: _Admins_
* Group ID: `LS0+YWRtaW5zPz8/Cg==`

###### Send a text message
```sh
$ mosquitto_pub -h broker -t signal/out/method/send/recipient/%2B491713920000 -m 'Outgoing message'
```
The text _Outgoing message_ is sent to the phone.

###### Send a text message with a quotation
```sh
$ mosquitto_pub -h broker -t signal/out/method/send/recipient/%2B491713920000/quoteAuthor/%2B491713920001/quoteTimestamp/1577882096000 -m 'Outgoing message'
```
The text _Outgoing message_ is sent to the phone, quoting a message sent from `+491713920001` at timestamp `1577882096000`.

###### Send a text message to a group
```sh
$ mosquitto_pub -h broker -t signal/out/method/send/groupId/LS0%2BYWRtaW5zPz8%2FCg%3D%3D -m 'Outgoing message'
```
The text _Outgoing message_ is sent to the group _Admins_.

##### Value types
By default, the type of a parameter value is derived from its content.
When the default type does not match the expected type,
the value must be suffixed by a colon (`:`) and a type-id:

_\<PARAMETER_NAME>_`/`_\<PERCENT_ENCODED_VALUE>_`:`_\<TYPE_ID>_

Some parameters allow multiple values;
these may be represented by a comma-separated list of multiple values:

_\<PARAMETER_NAME>_`/`_\<PERCENT_ENCODED_VALUE1>_`,`_\<PERCENT_ENCODED_VALUE2>_`:`_\<TYPE_ID>_

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

Example: topic
`signal/out/method/send/recipient/%2B491713920000,%2B491713920001/quoteTimestamp/1577882096000:n`
contains a parameter _recipient_ holding a `string` array
of the two phone numbers `+491713920000` & `+491713920001`,
and parameter _quoteTimestamp_ is explicitely typed as `number`
(although the default would work here, too).

#### Receive
To receive messages on parameter topics,
subscribe to all children of the receive topic (default: `signal/in`).

##### Examples
The following values are used in the examples:
* Account number of signal-mqtt: `+493023125000`
* Phone number: `+491713920000`
* Hostname of the MQTT broker: `broker`
* Group Name: _Admins_
* Group ID: `LS0+YWRtaW5zPz8/Cg==`

###### Receive a text message
The text _Incoming message_ is sent from the phone to `+493023125000`.
```sh
$ mosquitto_sub -v -h broker -t signal/#
signal/in/method/receive/source_number/%2B491713920000/timestamp/1577882096000 Incoming message
```

###### Receive a text message from a group
The text _Incoming message_ is sent from the phone to the group _Admins_.
```sh
$ mosquitto_sub -v -h broker -t signal/#
signal/in/method/receive/source_number/%2B491713920000/timestamp/1577882096000/group_id/LS0%2BYWRtaW5zPz8%2FCg%3D%3D Incoming message
```

###### Receive a quotation message
The text _Incoming quote_ is sent from the phone as quotation to the message _Outgoing message_ from above.
```sh
$ mosquitto_sub -v -h broker -t signal/#
signal/in/method/receive/source_number/%2B491713920000/timestamp/1577882100000/quote_id/1577882096000 Incoming quote
```

###### Receive a reaction (emoji)
The emoji 👍 is sent from the phone as reaction to the message _Outgoing message_ from above.
```sh
$ mosquitto_sub -v -h broker -t signal/#
signal/in/method/receive/source_number/%2B491713920000/timestamp/1577882100000/reaction_emoji/%F0%9F%91%8D%F0%9F%8F%BB/reaction_timestamp/1577882096000 (null)
```

##### Customization of topic parameters
A JSON RPC object usually contains a lot of metadata parameters along with the main content.
Most metadata parameters are not required for an average user,
thus the parameters are filtered before building an MQTT topic.

The parameters that are used for topic building
are read from `/etc/signal-mqtt/topic-parameters` (within the container) once at application start.
The file contains a key/value pair per parameter.
The key is used as parameter name in the topic. The value is a path expression in
[dot notation](https://developer.mozilla.org/docs/Web/JavaScript/Reference/Operators/Property_Accessors#dot_notation),
representing the position of the value in JSON RPC objects. Example:
```
# Restrict the topic to method, source number and group id.
method        = method
source_number = params.envelope.sourceNumber
group_id      = params.envelope.dataMessage.groupInfo.groupId
```

The default file can be found under `image/topic-parameters`.

There are several options to customize the filter,
overriding the default file being the simplest one.

###### Override the default filter file
Write a custom file and mount it to `/etc/signal-mqtt/topic-parameters` in the container.
Example:
```yaml
services:
  signal-mqtt:
    [...]
    volumes:
      - "./data:/home/.local/share/signal-cli"
      - "./custom-topic-parameters:/etc/signal-mqtt/topic-parameters"
```

###### Use a custom filter file
Write a custom file, mount it into the container and
set the environment variable `MQTT_TOPIC_PARAMETERS_FILE`.
In a containerized environment,
this option offers no advantages over replacing the default file.

```yaml
services:
  signal-mqtt:
    [...]
    environment:
      MQTT_TOPIC_PARAMETERS_FILE: "/home/custom-topic-parameters"
    volumes:
      - "./data:/home/.local/share/signal-cli"
      - "./custom-topic-parameters:/home/custom-topic-parameters"
```

###### Use an environment variable
The filter may be configured without file
by setting the environment variable `MQTT_TOPIC_PARAMETERS_PATTERN`.
The variable must contain a regular expression of named capturing groups.
The group name corresponds to the filter key, the content of the group to the filter value.

Example:
```yaml
services:
  signal-mqtt:
    [...]
    environment:
      MQTT_TOPIC_PARAMETERS_PATTERN: "(?<method>method)|(?<source_number>params.envelope.sourceNumber)|(?<group_id>params.envelope.dataMessage.groupInfo.groupId)"
```

### Run signal-cli commands from the command line
Syntax: 
```sh
$ docker-compose run signal-mqtt signal-cli <command>
```
Most signal-cli commands require that no container is running.

Example:
```sh
$ docker-compose run --rm -ti signal-mqtt signal-cli listContacts
Number: +491713920000 Name:  Profile name: Sally Sender Blocked: false Message expiration: disabled
Number: +491713920001 Name:  Profile name: Rudy Receiver Blocked: false Message expiration: disabled
```

## Configuration
The configuration is based on environment variables.

|Variable|Description|Allowed values|Default|Example
|--------|-----------|-----|-------|-------
|`MQTT_PUBLISH_OPTIONS`|MQTT publish options|All options [supported by `mosquitto_pub`](https://mosquitto.org/man/mosquitto_pub-1.html) except `-t` and `-m`|_none_|`-h broker -id signal-publisher`
|`MQTT_PUBLISH_TOPIC`|MQTT topic for publishing messages received from Signal|[Topic names](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718106)|`${MQTT_TOPIC_PREFIX}/in`|`chats/from`
|`MQTT_PUBLISH_JSONRPC`|Publish JSON RPC objects received from signal-cli?|`true` / `false`|`false`|`true`
|`MQTT_PUBLISH_TO_PARAMETER_TOPIC`|Publish messages received from Signal to a parameter topic?|`true` / `false`|`true`|`false`
|`MQTT_SUBSCRIBE_OPTIONS`|MQTT subscribe options|All options [supported by `mosquitto_sub`](https://mosquitto.org/man/mosquitto_sub-1.html) except `-t` and formatting-related options like  `-F` & `-N`|_none_|`-h broker -i signal-subscriber`
|`MQTT_SUBSCRIBE_TOPIC`|MQTT topic to listen for messages that are sent to a Signal receiver|[Topic names](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718106)|`${MQTT_TOPIC_PREFIX}/out`|`chats/to`
|`MQTT_TOPIC_PREFIX`|Prefix for MQTT topics|[Topic names](http://docs.oasis-open.org/mqtt/mqtt/v3.1.1/os/mqtt-v3.1.1-os.html#_Toc398718106)|`signal`|`chats`
|`MQTT_TOPIC_PARAMETERS_FILE`|Custom filter file for topic parameters|File paths|_none_|`/home/custom-topic-parameters`
|`MQTT_TOPIC_PARAMETERS_PATTERN`|Custom pattern for topic parameters|A regular expression containing named capturing groups|_none_|`(?<method>method)\|(?<source_number>params.envelope.sourceNumber)\|(?<group_id>params.envelope.dataMessage.groupInfo.groupId)`
|`MQTT_LOG`|Enable logging via MQTT?|`true` / `false`|`false`|`true`
|`MQTT_LOG_TOPIC`|MQTT topic to publish the log to|`${MQTT_TOPIC_PREFIX}/log`|`chats/logs`
|`LOG_JSONRPC`|Enable logging of JSON RPC objects?|`true` / `false`|`false`|`true`
|`SIGNAL_ACCOUNT`|Phone number of the signal account|International phone number format with leading `+`|Account from signal-cli configuration|`+493023125000`
|`SIGNAL_CLI_OPTIONS`|signal-cli options|All options [supported by `signal-cli`](https://github.com/AsamK/signal-cli/blob/master/man/signal-cli.1.adoc#options) except `-a` and `-o`|_none_|`--trust-new-identities never -v`

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
