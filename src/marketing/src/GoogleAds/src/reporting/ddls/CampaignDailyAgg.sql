# -- Copyright 2024 Google LLC
# --
# -- Licensed under the Apache License, Version 2.0 (the "License");
# -- you may not use this file except in compliance with the License.
# -- You may obtain a copy of the License at
# --
# --     https://www.apache.org/licenses/LICENSE-2.0
# --
# -- Unless required by applicable law or agreed to in writing, software
# -- distributed under the License is distributed on an "AS IS" BASIS,
# -- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# -- See the License for the specific language governing permissions and
# -- limitations under the License.

/* CampaignStats and CampaignStatsByUserCountry metrics with daily granularity. */

WITH
  StatsByUserCountry AS (
    SELECT
      CampaignStatsByUserCountry.segments.date,
      CampaignStatsByUserCountry.campaign.id,
      ARRAY_AGG(
        STRUCT(
          GeoTargetConstant.country_code,
          CampaignStatsByUserCountry.user_location_view.targeting_location AS is_location_targeted,
          CampaignStatsByUserCountry.metrics.impressions,
          CampaignStatsByUserCountry.metrics.clicks,
          CampaignStatsByUserCountry.metrics.cost_micros / 1000000 AS cost
        )
      ) AS user_country_stats
    FROM
      `{{ project_id_tgt }}.{{ marketing_googleads_datasets_reporting }}.CampaignStatsByUserCountry`
        AS CampaignStatsByUserCountry
    INNER JOIN
      `{{ project_id_tgt }}.{{ marketing_googleads_datasets_reporting }}.GeoTargetConstant`
        AS GeoTargetConstant
      ON CampaignStatsByUserCountry.user_location_view.country_criterion_id = GeoTargetConstant.id
    GROUP BY
      segments.date, campaign.id
  )
SELECT
  CampaignStats.segments.date AS report_date,
  CampaignStats.campaign.id AS campaign_id,
  Campaigns.name AS campaign_name,
  Campaigns.start_date AS campaign_start_date,
  Campaigns.end_date AS campaign_end_date,
  Campaigns.status AS campaign_status,
  Campaigns.campaign_budget,
  Campaigns.campaign_group,
  Campaigns.optimization_score AS campaign_optimization_score,
  Campaigns.customer_id,
  Customers.descriptive_name AS customer_name,
  Customers.status AS customer_status,
  Customers.currency_code,
  Customers.time_zone AS customer_time_zone,
  Customers.has_partners_badge AS customer_has_partners_badge,
  Customers.manager AS customer_manager,
  Customers.optimization_score AS customer_optimization_score,
  CampaignStats.metrics.impressions,
  CampaignStats.metrics.clicks,
  CampaignStats.metrics.cost_micros / 1000000 AS cost,
  StatsByUserCountry.user_country_stats
FROM
  `{{ project_id_tgt }}.{{ marketing_googleads_datasets_reporting }}.CampaignStats`
    AS CampaignStats
LEFT JOIN
  StatsByUserCountry
  ON CampaignStats.campaign.id = StatsByUserCountry.id
    AND CampaignStats.segments.date = StatsByUserCountry.date
INNER JOIN
  `{{ project_id_tgt }}.{{ marketing_googleads_datasets_reporting }}.Campaigns`
    AS Campaigns
  ON CampaignStats.campaign.id = Campaigns.campaign_id
INNER JOIN
  `{{ project_id_tgt }}.{{ marketing_googleads_datasets_reporting }}.Customers`
    AS Customers
  ON Campaigns.customer_id = Customers.customer_id
