Of course. As a Senior AWS Solutions Architect, I have consolidated our discussions into a comprehensive, actionable, and professional English plan. This document is designed to be shared with your team or used as a implementation guide.

---

Project Plan: Automated AWS Cost Management, Reporting, and Visualization

Document Version: 1.0
Date: October 26, 2023
Author: Senior AWS Solutions Architect

1. Executive Summary

    This document outlines a complete, serverless architecture to automate the generation, storage, distribution, and analysis of detailed AWS cost and usage reports. The solution is designed to provide granular cost visibility, particularly by application tags, with zero manual intervention for new applications. It leverages AWS's native cost management services and follows the AWS Well-Architected Framework principles for security, reliability, performance, and cost optimization.

    Core Objectives:
    Automated Monthly Reports: Generate detailed cost reports (e.g., for EC2, S3) at the beginning of each month.
    Application-Centric View: Categorize and report costs based on resource tags (e.g., `app-id`, `environment`).
    Secure Archival: Automatically store final reports in Hitachi Content Platform (HCP) for long-term retention.
    Proactive Distribution: Push reports via email to stakeholders upon generation.
    Trend Analysis: Enable visualization of cost data over time to identify trends.

2. Architectural Overview

    The solution is an event-driven, serverless pipeline. The key insight is the separation of concerns: using AWS Glue and Amazon Athena as the "analytics engine" to process complex raw data, and treating HCP as the "secure archive" for the final, refined reports.

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

3. Phase 1: Foundation - CUR and Data Catalog

    Objective: Establish the source of truth and make it queryable.

    1.  Enable AWS Cost and Usage Report (CUR):
        In the AWS Billing Console, create a new CUR.
        Settings:
            Report Content: Include resource IDs.
            Data Integration: Enable for Amazon Athena.
            Format: Parquet (recommended for cost-effectiveness and performance).
        Delivery Path: `s3://[YOUR-BUCKET]-cur-source/raw/`

    2.  Create AWS Glue Crawler:
        Create a crawler named `cur-crawler`.
        Data Source: The S3 path where the CUR is delivered (`s3://[YOUR-BUCKET]-cur-source/raw/`).
        IAM Role: A role with permissions to read from the S3 bucket.
        Target Database: Create a new Glue Database (e.g., `cost_db`). The crawler will create a table (e.g., `cur_table`).
        Schedule: Run the crawler periodically (e.g., weekly) to update the schema if needed.

4. Phase 2: Automation - Monthly Report Generation

    Objective: Automate the SQL-based aggregation of monthly costs.

    1.  Athena SQL Query (Example - Application Cost Summary):
        Save this query as an SQL file in an S3 bucket (e.g., `s3://[YOUR-BUCKET]-scripts/app-cost-report.sql`). This query dynamically groups costs by the `app-id` tag.

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

    2.  Lambda Function: `ReportGenerator`
        Runtime: Python 3.x
        Logic:
            Triggered by an EventBridge rule on the 1st of every month.
            Calculates the previous month's year and month (e.g., if triggered on Nov 1st, it processes October data).
            Fetches the SQL template from S3 and dynamically replaces `{year}` and `{month}`.
            Uses the AWS SDK (Boto3) to start an Athena query execution.
            Configures Athena to save the query result to a dedicated S3 bucket: `s3://[YOUR-BUCKET]-processed-reports/{year}/{month}/app-cost-report.csv`

    3.  EventBridge Rule: `MonthlyTrigger`
        Rule Type: Schedule (`cron(0 8 1 ? *)` - 08:00 AM UTC on the 1st day of every month).
        Target: The `ReportGenerator` Lambda function.

5. Phase 3: Distribution - Archival to HCP and Email Notification

    Objective: Securely archive the report and notify users.

    1.  Lambda Function: `ReportDistributor`
        Runtime: Python 3.x
        Trigger: An EventBridge rule that detects `PutObject` events in the `s3://[YOUR-BUCKET]-processed-reports/` bucket.
        Logic:
            Retrieves the newly created report file from the S3 event data.
            HCP Upload: Uses Boto3's S3 client to `put_object` to the HCP endpoint. Security Note: HCP credentials (Access Key/Secret Key) must be stored securely in AWS Secrets Manager. The Lambda function retrieves them at runtime.
            Email via SES:
                Composes an email with a subject (e.g., "AWS Cost Report - October 2023").
                Includes a brief summary text and a direct link to the file in HCP (if HCP supports object-level linking).
                Attaches the report file or includes it in the email body.
                Uses Amazon SES to send the email to a predefined distribution list.

    2.  EventBridge Rule: `NewReportTrigger`
        Rule Type: Event Pattern.
        Source: `aws.s3`
        Detail Type: "Object Created"
        Resources: `[S3-BUCKET-ARN]-processed-reports`
        Target: The `ReportDistributor` Lambda function.

6. Phase 4: Visualization - Trend Analysis with QuickSight

    Objective: Enable self-service exploration and trend visualization.

    1.  Connect Amazon QuickSight to Athena:
        In QuickSight, create a new dataset.
        Select Amazon Athena as the data source.
        Choose the Glue database and table (`cost_db.cur_table`).
    2.  Create Analyses and Dashboards:
        Build visualizations by dragging and dropping fields.
        Example - Monthly Cost Trend by Application:
            Visual Type: Line chart.
            X-axis: `line_item_usage_start_date` (group by Month).
            Y-axis: `sum(line_item_unblended_cost)`.
            Group/Color: `resource_tags ['app-id']`.
        Share the dashboard with stakeholders for ongoing visibility.

7. Key Advantages & Compliance with Your Requirements

  Automatic Detection of New Applications: The SQL `GROUP BY resource_tags ['app-id']` clause dynamically includes any new tag value. As soon as a new application is tagged and incurs costs, it will automatically appear in the next monthly report without any code changes.
  Cost Allocation by Tag: The architecture is fundamentally designed around tagging for precise cost allocation and showback/chargeback.
  Serverless and Scalable: All components (Lambda, Athena, EventBridge) scale automatically with usage, ensuring reliability during data growth.
  Secure: Uses IAM roles for least privilege access. HCP credentials are managed via Secrets Manager, not hardcoded.
  Cost-Optimized: You only pay for the resources when they are in use (e.g., when queries are run, when Lambda functions are invoked).

8. Prerequisites and Next Steps

    1.  Tagging Strategy: Enforce a mandatory tagging policy (e.g., `app-id`, `environment`) across your AWS resources using AWS Organizations.
    2.  HCP Configuration: Ensure the HCP instance is configured with a bucket for receiving reports and that its S3-compatible API endpoint is accessible from the Lambda function's VPC (if in a VPC) or from the public internet (with appropriate security).
    3.  SES Setup: Verify the email domain/address in Amazon SES that will be used to send reports.

This design provides a robust, enterprise-ready foundation for mastering your AWS costs. Implementation can begin immediately with Phase 1.

---



二、 核心服务选型与理由
数据源: AWS Cost and Usage Report (CUR)

理由: 这是AWS最详尽、最准确的账单数据来源。它提供了逐行的、包含所有资源的用量和成本信息（包括标签），并每小时更新一次。它直接满足了您对“EC2 instance, EC2 others等”详尽信息的需求。

存储 (中间 & 最终): Amazon S3

理由: S3是持久性、可用性极高的对象存储，是CUR报告输出的默认目的地，也是我们进行数据处理的中转站。成本低廉，非常适合存储海量账单数据。

数据处理: AWS Glue & Amazon Athena

AWS Glue (数据目录): 用于自动爬取CUR报告的Schema（结构），并在Glue Data Catalog中创建表，使其能够被Athena查询。

Amazon Athena: 无服务器的交互式查询服务，使用标准SQL即可直接分析S3中的数据。我们将使用它来按月分区查询和生成月度报告，避免使用脚本进行复杂的文本处理。

自动化与编排: AWS Lambda & Amazon EventBridge

AWS Lambda: 无服务器计算服务。我们将编写两个Lambda函数：

月度报告生成器 (Monthly Report Generator): 由EventBridge定时触发，执行Athena查询，将月度数据写入处理后的S3桶。

报告分发器 (Report Distributor): 被新报告生成的事件触发，负责将报告上传至HCP并发送邮件。

Amazon EventBridge: 无服务器事件总线。用于监听S3事件（如新CUR文件到达、新月度报告生成）和创建定时规则（如每月1号触发报告生成），是实现整个流程自动化的“中枢神经”。

推送与存储

邮件推送: Amazon Simple Email Service (SES)

理由: 安全、成本效益高的批量邮件发送服务，完美满足邮件推送需求。

对象存储: Hitachi Content Platform (HCP)

实现: HCP通常支持S3兼容的API。我们将在Lambda函数中使用AWS SDK for Python (Boto3) 或 Java，通过S3 API将生成的报告PUT到HCP的指定桶中。

趋势可视化: Amazon QuickSight

理由: 无服务器的BI服务，可直接连接到Athena或S3中的CUR数据，轻松拖拽即可创建丰富的仪表板和趋势线图表，成本低廉。
