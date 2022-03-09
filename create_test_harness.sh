#!/bin/bash

# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Create test tables from GCS bucket
project="$1"
dataset="$2"
location=${3:-US}
location_low=$(echo "${location}" | tr '[:upper:]' '[:lower:]')

N=10

open_semaphore() {
  mkfifo pipe-$$
  exec 3<>pipe-$$
  rm pipe-$$
  local i=$1
  for (( ; i > 0; i--)); do
    printf %s 000 >&3
  done
}

process_table() {
  tab=$1

  tabname=$(basename "${tab}" .parquet)

  echo "Processing ${tabname}"
  exists=$(bq show --project_id "${project}" --location="${location}" "${dataset}.${tabname}")
  if [[ "${exists}" == *"Not found"* ]]; then
    bq load --location="${location}" --project_id "${project}" --noreplace --source_format=PARQUET "${dataset}.${tabname}" "${tab}"
    echo
  else
    echo "Table ${tabname} already exists, skipping"
  fi
}

run_with_lock() {
  local x
  # this read waits until there is something to read
  read -u 3 -n 3 x && ((0 == x)) || exit $x
  ( 
    ("$@")
    # push the return code of the command to the semaphore
    printf '%.3d' $? >&3
  ) &

}

open_semaphore "${N}"
for tab in $(gsutil ls "gs://kittycorn-test-harness-${location_low}"); do
  run_with_lock process_table "${tab}"
done

wait
