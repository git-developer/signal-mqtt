#
# This function to decode a percent-encoded string is required
# until https://github.com/stedolan/jq/issues/2261 is resolved.
#
# Source: https://rosettacode.org/wiki/URL_decoding#jq
#
def url_decode:
  # The helper function converts the input string written in the given
  # "base" to an integer
  def to_i(base):
    explode
    | reverse
    | map(if 65 <= . and . <= 90 then . + 32  else . end)   # downcase
    | map(if . > 96  then . - 87 else . - 48 end)  # "a" ~ 97 => 10 ~ 87
    | reduce .[] as $c
        # base: [power, ans]
        ([1,0]; (.[0] * base) as $b | [$b, .[1] + (.[0] * $c)]) | .[1];

  .  as $in
  | length as $length
  | [0, ""]  # i, answer
  | until ( .[0] >= $length;
      .[0] as $i
      |  if $in[$i:$i+1] == "%"
         then [ $i + 3, .[1] + ([$in[$i+1:$i+3] | to_i(16)] | implode) ]
         else [ $i + 1, .[1] + $in[$i:$i+1] ]
         end)
  | .[1]
;

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
  | .[0] | split(",") | map(url_decode)
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
# 1.) Extract the message from property 'payload'
# 2.) Check if the topic contains parameters. If not, return the original
#     message, which is expected to be a valid JSON-RPC message for signal-cli
#     Example: $base_topic = 'signal/in'
# 3.) Extract parameters. They are expected to begin with the method
#     and consist of key-value pairs.
#     Example: 'method/receive' and 'source_number/%2B491713920000'
# 4.) Build a JSON-RPC message. Put the method in the root object.
#     Put all other parameters into the params object.
#     Add the payload as 'message' parameter.
##
def to_jsonrpc($base_topic):
  .payload as $message
  | .topic
  | (capture($base_topic + "/(?<params>.+)").params
     | split("/")
     | {
          jsonrpc: "2.0",
          (.[0]): .[1],
          params: ([. as $v | range(2; length; 2) | {($v[.]): $v[(.+1)] | cast}] + [{message: $message}]) | add
       }
    ) // $message
;
