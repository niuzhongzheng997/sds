Of course. As a Senior AWS Solutions Architect, I have consolidated our discussions into a comprehensive, actionable, and professional English plan. This document is designed to be shared with your team or used as a implementation guide.

---

### **Project Plan: Automated AWS Cost Management, Reporting, and Visualization**

**Document Version:** 1.0
**Date:** October 26, 2023
**Author:** Senior AWS Solutions Architect

#### **1. Executive Summary**

This document outlines a complete, serverless architecture to automate the generation, storage, distribution, and analysis of detailed AWS cost and usage reports. The solution is designed to provide granular cost visibility, particularly by application tags, with zero manual intervention for new applications. It leverages AWS's native cost management services and follows the AWS Well-Architected Framework principles for security, reliability, performance, and cost optimization.

**Core Objectives:**
*   **Automated Monthly Reports:** Generate detailed cost reports (e.g., for EC2, S3) at the beginning of each month.
*   **Application-Centric View:** Categorize and report costs based on resource tags (e.g., `app-id`, `environment`).
*   **Secure Archival:** Automatically store final reports in Hitachi Content Platform (HCP) for long-term retention.
*   **Proactive Distribution:** Push reports via email to stakeholders upon generation.
*   **Trend Analysis:** Enable visualization of cost data over time to identify trends.

#### **2. Architectural Overview**

The solution is an event-driven, serverless pipeline. The key insight is the separation of concerns: using **AWS Glue** and **Amazon Athena** as the "analytics engine" to process complex raw data, and treating **HCP** as the "secure archive" for the final, refined reports.

```mermaid
flowchart TD
    A[AWS Cost &<br>Usage Report<br>CUR] -->|Raw data delivery| B[S3 Bucket<br>'cur-source']
    B -->|Schema discovery| C[Glue Crawler]
    C -->|Creates/Updates| D[Glue Data Catalog<br>'cost_db.cur_table']
    E[Scheduled Event<br>1st of month] -->|Triggers| F[Lambda: ReportGenerator]
    F -->|Executes SQL| G[Amazon Athena]
    G -->|Reads from| D
    G -->|Writes result to| H[S3 Bucket<br>'processed-reports']
    H -->|ObjectCreated Event| I[Lambda: Distributor]
    I -->|S3 API PUT| J[Hitachi Content Platform<br>HCP]
    I -->|Send Email| K[Amazon SES]
    L[Amazon QuickSight] -->|Connects to| G
    L -->|Visualizes| M[Trend Lines & Dashboards]
```

#### **3. Phase 1: Foundation - CUR and Data Catalog**

**Objective:** Establish the source of truth and make it queryable.

1.  **Enable AWS Cost and Usage Report (CUR):**
    *   In the AWS Billing Console, create a new CUR.
    *   **Settings:**
        *   **Report Content:** Include resource IDs.
        *   **Data Integration:** Enable for **Amazon Athena**.
        *   **Format:** **Parquet** (recommended for cost-effectiveness and performance).
    *   **Delivery Path:** `s3://[YOUR-BUCKET]-cur-source/raw/`

2.  **Create AWS Glue Crawler:**
    *   Create a crawler named `cur-crawler`.
    *   **Data Source:** The S3 path where the CUR is delivered (`s3://[YOUR-BUCKET]-cur-source/raw/`).
    *   **IAM Role:** A role with permissions to read from the S3 bucket.
    *   **Target Database:** Create a new Glue Database (e.g., `cost_db`). The crawler will create a table (e.g., `cur_table`).
    *   **Schedule:** Run the crawler periodically (e.g., weekly) to update the schema if needed.

#### **4. Phase 2: Automation - Monthly Report Generation**

**Objective:** Automate the SQL-based aggregation of monthly costs.

1.  **Athena SQL Query (Example - Application Cost Summary):**
    *   Save this query as an SQL file in an S3 bucket (e.g., `s3://[YOUR-BUCKET]-scripts/app-cost-report.sql`). This query dynamically groups costs by the `app-id` tag.

    ```sql
    -- Purpose: Monthly cost breakdown by application tag
    SELECT
        resource_tags ['app-id'] as application,
        line_item_product_code as service,
        sum(line_item_unblended_cost) as monthly_cost
    FROM
        cost_db.cur_table
    WHERE
        year = '{year}' AND month = '{month}'
        AND resource_tags ['app-id'] IS NOT NULL
    GROUP BY
        resource_tags ['app-id'],
        line_item_product_code
    ORDER BY
        application, monthly_cost DESC;
    ```

2.  **Lambda Function: `ReportGenerator`**
    *   **Runtime:** Python 3.x
    *   **Logic:**
        *   Triggered by an EventBridge rule on the 1st of every month.
        *   Calculates the previous month's year and month (e.g., if triggered on Nov 1st, it processes October data).
        *   Fetches the SQL template from S3 and dynamically replaces `{year}` and `{month}`.
        *   Uses the AWS SDK (Boto3) to start an Athena query execution.
        *   Configures Athena to save the query result to a dedicated S3 bucket: `s3://[YOUR-BUCKET]-processed-reports/{year}/{month}/app-cost-report.csv`

3.  **EventBridge Rule: `MonthlyTrigger`**
    *   **Rule Type:** Schedule (`cron(0 8 1 * ? *)` - 08:00 AM UTC on the 1st day of every month).
    *   **Target:** The `ReportGenerator` Lambda function.

#### **5. Phase 3: Distribution - Archival to HCP and Email Notification**

**Objective:** Securely archive the report and notify users.

1.  **Lambda Function: `ReportDistributor`**
    *   **Runtime:** Python 3.x
    *   **Trigger:** An EventBridge rule that detects `PutObject` events in the `s3://[YOUR-BUCKET]-processed-reports/` bucket.
    *   **Logic:**
        *   Retrieves the newly created report file from the S3 event data.
        *   **HCP Upload:** Uses Boto3's S3 client to `put_object` to the HCP endpoint. **Security Note:** HCP credentials (Access Key/Secret Key) must be stored securely in **AWS Secrets Manager**. The Lambda function retrieves them at runtime.
        *   **Email via SES:**
            *   Composes an email with a subject (e.g., "AWS Cost Report - October 2023").
            *   Includes a brief summary text and a direct link to the file in HCP (if HCP supports object-level linking).
            *   Attaches the report file or includes it in the email body.
            *   Uses Amazon SES to send the email to a predefined distribution list.

2.  **EventBridge Rule: `NewReportTrigger`**
    *   **Rule Type:** Event Pattern.
    *   **Source:** `aws.s3`
    *   **Detail Type:** "Object Created"
    *   **Resources:** `[S3-BUCKET-ARN]-processed-reports`
    *   **Target:** The `ReportDistributor` Lambda function.

#### **6. Phase 4: Visualization - Trend Analysis with QuickSight**

**Objective:** Enable self-service exploration and trend visualization.

1.  **Connect Amazon QuickSight to Athena:**
    *   In QuickSight, create a new dataset.
    *   Select **Amazon Athena** as the data source.
    *   Choose the Glue database and table (`cost_db.cur_table`).
2.  **Create Analyses and Dashboards:**
    *   Build visualizations by dragging and dropping fields.
    *   **Example - Monthly Cost Trend by Application:**
        *   **Visual Type:** Line chart.
        *   **X-axis:** `line_item_usage_start_date` (group by Month).
        *   **Y-axis:** `sum(line_item_unblended_cost)`.
        *   **Group/Color:** `resource_tags ['app-id']`.
    *   Share the dashboard with stakeholders for ongoing visibility.

#### **7. Key Advantages & Compliance with Your Requirements**

*   **Automatic Detection of New Applications:** The SQL `GROUP BY resource_tags ['app-id']` clause dynamically includes any new tag value. As soon as a new application is tagged and incurs costs, it will automatically appear in the next monthly report without any code changes.
*   **Cost Allocation by Tag:** The architecture is fundamentally designed around tagging for precise cost allocation and showback/chargeback.
*   **Serverless and Scalable:** All components (Lambda, Athena, EventBridge) scale automatically with usage, ensuring reliability during data growth.
*   **Secure:** Uses IAM roles for least privilege access. HCP credentials are managed via Secrets Manager, not hardcoded.
*   **Cost-Optimized:** You only pay for the resources when they are in use (e.g., when queries are run, when Lambda functions are invoked).

#### **8. Prerequisites and Next Steps**

1.  **Tagging Strategy:** Enforce a mandatory tagging policy (e.g., `app-id`, `environment`) across your AWS resources using AWS Organizations.
2.  **HCP Configuration:** Ensure the HCP instance is configured with a bucket for receiving reports and that its S3-compatible API endpoint is accessible from the Lambda function's VPC (if in a VPC) or from the public internet (with appropriate security).
3.  **SES Setup:** Verify the email domain/address in Amazon SES that will be used to send reports.

This design provides a robust, enterprise-ready foundation for mastering your AWS costs. Implementation can begin immediately with Phase 1.

---
