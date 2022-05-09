log() {
  echo "[$(date -Ins -u)] $1"
}

load_api_config() {
  log 'Getting source endpoint and key...'
  source_api_endpoint="$(get_api_endpoint "$1" "$2")"
  source_api_key="$(get_api_key "$1" "$2")"

  log 'Getting destination endpoint and key...'
  destination_api_endpoint="$(get_api_endpoint "$3" "$4")"
  destination_api_key="$(get_api_key "$3" "$4")"
}

get_api_endpoint() {
  az cognitiveservices account show -n "$1" -g "$2" --query 'properties.endpoint' -o tsv
}

get_api_key() {
  az cognitiveservices account keys list -n "$1" -g "$2" --query key1 -o tsv
}
