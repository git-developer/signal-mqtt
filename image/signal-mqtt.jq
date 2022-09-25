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

def cast:
  def cast_scalar(type_id):
    if type_id == null or (type_id | test("^\\s*$")) then
        if test("^[0-9]+$") then tonumber else . end
    elif ("boolean" | startswith(type_id)) then test("true")
    elif ("number" | startswith(type_id)) then tonumber
    else .
    end;

  split(":")
  | .[1] as $type_id
  | .[0] | split(",") | map(url_decode)
  | if length > 1 or ($type_id and ($type_id | endswith("[]")))
    then map(cast_scalar($type_id | rtrimstr("[]")))
    else .[0] | cast_scalar($type_id)
    end
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

def to_jsonrpc(message):
  split("/") + ["message", $message] | {
    jsonrpc: "2.0",
    (.[0]): .[1],
    params: [. as $v | range(2; length; 2) | {($v[.]): $v[(.+1)] | cast}] | add
  }
;
