##
# Cast a string to a json value (string, number, boolean, array, null).
#
# The string may be suffixed with an optional colon and type-id.
#
# Examples:
#   "1"       -> 1
#   "a"       -> "a"
#   "true:b"  -> true
#   "1:s"     -> "1"
#   null      -> null
#   "1,2"     -> [1, 2]
#   "1,2:s[]" -> ["1", "2"]
##
def cast:
  def cast_scalar(type_id):
    if type_id == null or (type_id | test("^\\s*$")) then
        if test("^[0-9]+$") then tonumber else . end
    elif ("boolean" | startswith(type_id)) then test("true")
    elif ("number" | startswith(type_id)) then tonumber
    else .
    end;

  (select(. != null)
  | split(":")
  | .[1] as $type_id
  | .[0] | split(",") | map(@urid)
  | if length > 1 or ($type_id and ($type_id | endswith("[]")))
    then map(cast_scalar($type_id | rtrimstr("[]")))
    else .[0] | cast_scalar($type_id)
    end
  ) // null
;

def to_topic(pattern):
  [([paths(scalars) as $path | {"key": $path | join("."), "value": getpath($path)}]
    | (map(.key | (
        capture("^" + pattern + "$")
        | with_entries(select(.value) | {key: .value, value: .key}))
       ) | add
      ) as $params
    | map({key:$params[.key], value:.value} | select(.key) | (.key, (.value | @uri)))
    | join("/")
   ), .params.envelope.dataMessage.message
  ] | @tsv
;

##
# Convert a JSON message in mosquitto_sub format to signal-cli JSON-RPC format.
# Parameters are extracted from the topic.
#
# Example input message (one single line, formatted for better readability):
#   {
#    "tst":"2020-01-15T00:00:00.000000Z+0100",
#    "topic":"signal/in/method/receive/source_number/%2B491713920000",
#    "qos":0,
#    "retain":0,
#    "payloadlen":13,
#    "payload":"line 1\nline2\n"
#   }
#
# Arguments:
#   $base_topic: a string containing the topic the message was published to,
#                without parameters. Example: 'signal/in'.
#
# Algorithm:
# 1.) Extract the payload from property 'payload'
# 2.) Check if the topic contains parameters. If not, return the original
#     payload, which is expected to be a valid JSON-RPC message for signal-cli
#     Example: $base_topic = 'signal/in'
# 3.) Extract parameters from key-value pairs. The first pair is expected as
#       'method/' + <method-value> + [ ':' + <payload-key> ]
#     where payload-key is optional and defaults to 'message'.
#     Examples:
#      'method/receive' and 'source_number/%2B491713920000'
#      'method/send:attachment' and 'source_number/%2B491713920000'
# 4.) Build a JSON-RPC message. Put the method in the root object.
#     Put all other parameters into the params object.
#     Add a parameter for the payload.
##
def to_jsonrpc($base_topic):
  .payload as $payload
  | .topic
  | (capture($base_topic + "/(?<params>.+)").params
     | split("/")
     | .[0] as $methodKey
     | (.[1] | split(":")) as $methodValue
     | ($methodValue[0]) as $method
     | ($methodValue[1] // "message") as $payloadKey
     | {
          jsonrpc: "2.0",
          ($methodKey): $method,
          params: ([. as $v | range(2; length; 2) | {($v[.]): $v[(.+1)] | cast}] + [{($payloadKey): $payload}]) | add
       }
    ) // $payload
;
