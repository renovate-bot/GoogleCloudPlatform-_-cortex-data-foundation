# Copyright 2023 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""This DAG starts a Beam pipeline for processing CM360 RAW layer ingestion."""

from datetime import datetime
from datetime import timedelta
import os.path
from pathlib import Path

from airflow import DAG
from airflow.providers.apache.beam.operators.beam import BeamRunPythonPipelineOperator
from airflow.providers.google.cloud.operators.dataflow import DataflowConfiguration
from airflow.version import version as AIRFLOW_VERSION

_PROJECT_ID = "${project_id}"
_DATASET_ID = "${raw_dataset}"
_TABLE_NAME = "${table_name}"
_GCP_CONN_ID = "cm360_raw_dataflow"

_THIS_DIR = Path(__file__).resolve().parent

beam_pipeline_params = {
    "setup_file":
        str(Path(_THIS_DIR, "${pipeline_setup}")),
    "tempLocation":
        "${pipeline_temp_location}",
    "stagingLocation":
        "${pipeline_staging_location}",
    "input_file_pattern":
        os.path.join("gs://${datatransfer_bucket}", "${file_pattern}"),
    "mapping_file":
        str(Path(_THIS_DIR, "${schemas_dir}", "${schema_file}")),
    "tgt_project":
        "${project_id}",
    "tgt_dataset":
        "${raw_dataset}",
    "tgt_table":
        _TABLE_NAME,
}

_START_DATE = datetime.fromisoformat("${start_date}")
_IDENTIFIER = ("CM360_"
               f"{_PROJECT_ID}_{_DATASET_ID}_extract_to_raw_{_TABLE_NAME}")

if AIRFLOW_VERSION.startswith("1."):
    with DAG(dag_id=_IDENTIFIER,
             description=f"Extract from source to raw {_TABLE_NAME} entities",
             schedule_interval="${load_frequency}",
             start_date=_START_DATE,
             dagrun_timeout=timedelta(minutes=60),
             tags=["cm360", "raw"],
             catchup=False,
             max_active_runs=1) as dag:

        # Import here to avoid slow DAG imports in Airflow.
        from airflow.operators.dummy_operator import DummyOperator

        start_task = DummyOperator(task_id="start",
                                   depends_on_past=True,
                                   wait_for_downstream=True)
        extract_data = BeamRunPythonPipelineOperator(
            # from DataflowHook: name must consist of only the
            # characters [-a-z0-9]
            task_id=_IDENTIFIER,
            runner="DataflowRunner",
            py_file=str(Path(_THIS_DIR, "${pipeline_file}")),
            pipeline_options=beam_pipeline_params,
            py_requirements=["apache-beam[gcp]==2.53.0"],
            py_system_site_packages=False,
            gcp_conn_id = _GCP_CONN_ID,
            dataflow_config=DataflowConfiguration(
                project_id="${project_id}",
                location="${project_region}",
                wait_until_finished=True,
                poll_sleep=60,
                gcp_conn_id=_GCP_CONN_ID,
                job_name=_IDENTIFIER.lower()),
        )
    stop_task = DummyOperator(task_id="stop")

else:
    with DAG(dag_id=_IDENTIFIER,
             description=f"Extract from source to raw {_TABLE_NAME} entities",
             schedule="${load_frequency}",
             start_date=_START_DATE,
             dagrun_timeout=timedelta(minutes=60),
             tags=["cm360", "raw"],
             catchup=False,
             max_active_runs=1) as dag:

        # Import here to avoid slow DAG imports in Airflow.
        from airflow.operators.empty import EmptyOperator

        start_task = EmptyOperator(task_id="start",
                                   depends_on_past=True,
                                   wait_for_downstream=True)
        extract_data = BeamRunPythonPipelineOperator(
            # from DataflowHook: name must consist of only the
            # characters [-a-z0-9]
            task_id=_IDENTIFIER,
            runner="DataflowRunner",
            py_file=str(Path(_THIS_DIR, "${pipeline_file}")),
            pipeline_options=beam_pipeline_params,
            py_requirements=["apache-beam[gcp]==2.53.0"],
            py_system_site_packages=False,
            gcp_conn_id = _GCP_CONN_ID,
            dataflow_config=DataflowConfiguration(
                project_id="${project_id}",
                location="${project_region}",
                wait_until_finished=True,
                poll_sleep=60,
                gcp_conn_id=_GCP_CONN_ID,
                job_name=_IDENTIFIER.lower()),
        )
        stop_task = EmptyOperator(task_id="stop")

start_task >> extract_data >> stop_task  # pylint: disable=pointless-statement
