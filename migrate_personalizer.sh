#!/usr/bin/env bash

source common.sh

source_resource_name=chrricepersonalizersrc
source_rg=personalizertest
destination_resource_name=chrricepersonalizerdst
destination_rg=personalizertest

copy_configuration() {
  config_type="$1"

  log "Downloading $config_type configuration from source resource $source_resource_name..."
  configuration="$(curl -s \
    -H "Ocp-Apim-Subscription-Key: $source_api_key" \
    -H 'Content-Type: application/json' \
    "${source_api_endpoint}personalizer/v1.0/configurations/$config_type")"

  log "Configuration: $configuration"

  log "Uploading $config_type configuration to destination resource $destination_resource_name..."
  output="$(curl -s -w "\n%{http_code}" \
    -H "Ocp-Apim-Subscription-Key: $destination_api_key" \
    -H 'Content-Type: application/json' \
    -X PUT \
    -d "$configuration" \
    "${destination_api_endpoint}personalizer/v1.0/configurations/$config_type")"

    status="$(echo -n "$output" | tail -n 1)"
    body="$(echo -n "$output" | head -n -1)"

    if [[ $status == 200 ]]; then
      log "Successfully copied $config_type configuration to destination resource $destination_resource_name"
    else
      log "Failed to copy $config_type configuration to destination resource $destination_resource_name"
      log "Status Code: $status"
      log "Body: $body"
    fi
}

copy_model() {
  log "Downloading model file from source resource $source_resource_name..."
  curl -s \
    -H "Ocp-Apim-Subscription-Key: $source_api_key" \
    -o ./personalizer_model.zip \
    "${source_api_endpoint}personalizer/v1.1-preview.3/model?signed=True" 

  log "Uploading model file to destination resource $destination_resource_name..."
  output="$(curl -s -w "\n%{http_code}" \
    -H "Ocp-Apim-Subscription-Key: $destination_api_key" \
    -H "Content-Type: application/octet-stream" \
    -X PUT \
    --data-binary @./personalizer_model.zip \
    "${destination_api_endpoint}personalizer/v1.1-preview.3/model")"

  status="$(echo -n "$output" | tail -n 1)"
  body="$(echo -n "$output" | head -n -1)"

  if [[ $status == 204 ]]; then
    log "Successfully copied model to destination resource $destination_resource_name"
  else
    log "Failed to copy model to destination resource $destination_resource_name"
    log "Status Code: $status"
    log "Body: $body"
  fi
}

load_api_config "$source_resource_name" "$source_rg" "$destination_resource_name" "$destination_rg"

copy_configuration service
copy_configuration policy
copy_model
