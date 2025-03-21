# Copyright 2023 Google LLC
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

# Fully update (refresh) the weekly inventory aggregation intermediate table.
#
# Week start date is defined in Date Dimension table (`calendar_date_dim`).
CREATE OR REPLACE PROCEDURE
`{{ project_id_tgt }}.{{ dataset_reporting_tgt }}.AggregateWeeklyInventory` ()
OPTIONS (description = "This procedure creates the weekly_inventory_aggregation table, an intermediate table for downstream calculation of weekly stock quantity / value snapshots and performance KPIs.")
BEGIN
  CREATE OR REPLACE TABLE
  `{{ project_id_tgt }}.{{ dataset_reporting_tgt }}.weekly_inventory_aggregation` AS
  SELECT
    src.mandt,
    src.werks,
    src.matnr,
    src.charg,
    src.lgort,
    src.bukrs,
    src.meins,
    src.waers,
    StockCharacteristicsConfig.StockCharacteristic AS stock_characteristic,
    EXTRACT(YEAR FROM datedim.weekEndDate) AS cal_year,
    EXTRACT(WEEK FROM datedim.weekEndDate) AS cal_week,
    datedim.WeekEndDate AS week_end_date,
    SUM(src.dmbtr_stock) AS total_weekly_movement_amount,
    SUM(src.stock_qty) AS total_weekly_movement_quantity
  FROM
    `{{ project_id_src }}.{{ dataset_cdc_processed }}.matdoc` AS src
  LEFT JOIN
    `{{ project_id_src }}.{{ k9_datasets_processing }}.calendar_date_dim` AS datedim
    ON
      src.budat = datedim.Date
  LEFT JOIN
    `{{ project_id_tgt }}.{{ dataset_reporting_tgt }}.StockCharacteristicsConfig` AS StockCharacteristicsConfig
    ON
      src.mandt = StockCharacteristicsConfig.Client_MANDT
      AND src.sobkz = StockCharacteristicsConfig.SpecialStockIndicator_SOBKZ
      AND src.bstaus_sg = StockCharacteristicsConfig.StockCharacteristic_BSTAUS_SG
  WHERE
    src.mandt = '{{ mandt }}'
  GROUP BY
    src.mandt,
    src.werks,
    src.matnr,
    src.charg,
    src.meins,
    src.waers,
    src.lgort,
    src.bukrs,
    StockCharacteristicsConfig.StockCharacteristic,
    datedim.WeekEndDate;

END;
