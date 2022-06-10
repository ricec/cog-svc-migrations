#!/usr/bin/env bash

source common.sh

source_resource_name=chrricecustomquestion
source_rg=qnamakertest
destination_resource_name=chrriceqnadestination
destination_rg=qnamakertest

wait_for_job() {
  local status_location="$1"
  local api_key="$2"

  while true; do
    log "Checking job status at $status_location..."
    status_json="$(curl -s \
      -H "Ocp-Apim-Subscription-Key: $api_key" \
      -H 'Content-Type: application/json' \
      "$status_location")"

    status="$(echo "$status_json" | jq -r '.status')"
    case $status in
      succeeded)
        log "Job succeeded: $status_json"
        break
        ;;
      notStarted | running | '')
        log "Job still pending (status: $status)..."
        log "$status_json"
        sleep 5
        ;;
      *)
        log "Job failed: $status_json"
        exit 1
        ;;
    esac
  done
}

load_api_config "$source_resource_name" "$source_rg" "$destination_resource_name" "$destination_rg"

log 'Listing source projects...'
project_names="$(curl -s \
  -H "Ocp-Apim-Subscription-Key: $source_api_key" \
  -H 'Content-Type: application/json' \
  "${source_api_endpoint}language/query-knowledgebases/projects?api-version=2021-10-01" \
  | jq -r '.value[].projectName')"

while read -r project_name; do
  log "Starting export of project $project_name from source account $source_resource_name..."
  url="${source_api_endpoint}language/query-knowledgebases/projects/${project_name}/:export?api-version=2021-10-01&format=json"
  status_location="$(curl -s -i -d '{exportAssetTypes": ["qnas","synonyms"]}' \
    -H "Ocp-Apim-Subscription-Key: $source_api_key" \
    -H 'Content-Type: application/json' \
    "$url" \
    | grep -oP '(?<=operation-location: ).*' \
    | tr -d "\r\n")"

  wait_for_job "$status_location" "$source_api_key"
  result_url="$(echo "$status_json" | jq -r '.resultUrl')"

  log "Export job succeeded. Downloading results from $result_url..."
  curl -s \
    -H "Ocp-Apim-Subscription-Key: $source_api_key" \
    -H 'Content-Type: application/json' \
    -o ./tmpresults.json "$result_url" 

  log "Starting import of project $project_name to destination account $destination_resource_name..."
  # TODO: Address below import limitations. 
  # - Cannot import qna pair with ":" or "|" in metadata
  url="${destination_api_endpoint}language/query-knowledgebases/projects/${project_name}/:import?api-version=2021-10-01&format=json"
  status_location="$(curl -s -i -d @./tmpresults.json \
    -H "Ocp-Apim-Subscription-Key: $destination_api_key" \
    -H 'Content-Type: application/json' \
    "$url" \
    | grep -oP '(?<=operation-location: ).*' \
    | tr -d "\r\n")"

  wait_for_job "$status_location" "$destination_api_key"
  log "Import succeeded for $project_name to destination account $destination_resource_name"

  # TODO: Deploy the new KB if desired
done <<< "$project_names"
