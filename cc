方案一：使用AWS Cost Explorer API和Lambda的步骤
1. 准备阶段
确定需要监控的AWS账户和区域。

确保所有需要监控的AWS资源都已打上正确的标签（如Application、Environment、BatchId等）。

2. 配置IAM权限
创建一个IAM角色，供Lambda函数使用。

为该角色附加策略，允许其调用Cost Explorer API和向CloudWatch发布指标。

3. 创建Lambda函数
编写Lambda函数代码（使用Python或Node.js等），实现以下功能：

调用Cost Explorer API，按标签和时间范围（例如前一天）获取成本数据。

处理API返回的数据，将其转换为CloudWatch指标。

将指标发布到CloudWatch。

设置Lambda函数的执行超时时间和内存大小（建议至少300秒和256MB）。

4. 设置定时触发
使用CloudWatch Events（EventBridge）规则，按预定计划（例如每天UTC时间2:00）触发Lambda函数。

5. 配置Grafana
在Grafana中配置CloudWatch数据源。

创建仪表板，使用Time Series图表等可视化组件，查询CloudWatch中的成本指标。

6. 设置告警和报告（可选）
在Grafana中设置告警规则，当成本超过阈值时通知。

使用Grafana的报告功能或通过API生成定期报告。

方案二：使用AWS CUR和Athena的步骤
1. 启用Cost and Usage Report (CUR)
在AWS成本管理控制台中创建CUR报告。

选择报告格式（推荐Parquet）、时间粒度（每小时/每天）和包含的资源ID。

指定S3存储桶以存储报告。

2. 配置Glue Data Catalog（可选但推荐）
使用AWS Glue Crawler自动发现CUR报告的结构并创建表。

设置Crawler定期运行以更新表结构。

3. 使用Athena查询数据
在Athena中创建数据库（如果尚未存在）。

运行Glue Crawler后，将在Data Catalog中创建表，可在Athena中查询。

编写SQL查询，按标签分组和过滤成本数据。

4. 构建Grafana仪表板
在Grafana中配置Athena数据源。

使用Athena数据源创建仪表板，编写SQL查询来获取成本数据。

使用Time Series等图表类型展示成本趋势。

5. 自动化数据更新
由于CUR报告会定期更新，需要确保Athena表的分区同步。可以设置一个Lambda函数，在CUR报告更新后自动运行MSCK REPAIR TABLE来更新分区。

6. 设置告警和报告（可选）
在Grafana中设置告警，或者使用Athena查询结果触发告警。

生成定期报告。

# Solution 1: Steps Using AWS Cost Explorer API and Lambda

## 1. Preparation Phase
- Identify AWS accounts and regions to be monitored
- Ensure all AWS resources to be monitored have proper tags (e.g., Application, Environment, BatchId, etc.)

## 2. Configure IAM Permissions
- Create an IAM role for the Lambda function
- Attach policies to the role allowing it to call Cost Explorer API and publish metrics to CloudWatch

## 3. Create Lambda Function
- Write Lambda function code (using Python, Node.js, etc.) to:
  - Call Cost Explorer API to retrieve cost data by tags and time range (e.g., previous day)
  - Process API response data and transform it into CloudWatch metrics
  - Publish metrics to CloudWatch
- Set Lambda function timeout and memory size (recommended at least 300 seconds and 256MB)

## 4. Set Up Scheduled Trigger
- Use CloudWatch Events (EventBridge) rules to trigger the Lambda function on a schedule (e.g., daily at 02:00 UTC)

## 5. Configure Grafana
- Configure CloudWatch data source in Grafana
- Create dashboards using Time Series charts and other visualization components to query cost metrics from CloudWatch

## 6. Set Up Alerts and Reporting (Optional)
- Configure alert rules in Grafana to notify when costs exceed thresholds
- Use Grafana reporting features or API to generate periodic reports

---

# Solution 2: Steps Using AWS CUR and Athena

## 1. Enable Cost and Usage Report (CUR)
- Create CUR report in AWS Cost Management console
- Select report format (recommended: Parquet), time granularity (hourly/daily), and include resource IDs
- Specify S3 bucket for report storage

## 2. Configure Glue Data Catalog (Optional but Recommended)
- Use AWS Glue Crawler to automatically discover CUR report structure and create tables
- Set up Crawler to run periodically to update table structure

## 3. Query Data Using Athena
- Create database in Athena (if not already exists)
- After running Glue Crawler, tables will be created in Data Catalog and can be queried in Athena
- Write SQL queries to group and filter cost data by tags

## 4. Build Grafana Dashboards
- Configure Athena data source in Grafana
- Create dashboards using Athena data source, writing SQL queries to retrieve cost data
- Use Time Series and other chart types to display cost trends

## 5. Automate Data Updates
- Since CUR reports are updated periodically, ensure Athena table partitions are synchronized
- Set up a Lambda function to automatically run `MSCK REPAIR TABLE` to update partitions after CUR report updates
- Set up a Lambda function that listens for S3 event notifications and automatically triggers when new CUR reports are delivered. This Lambda will start a Glue Crawler to discover and register new partitions, making fresh cost data immediately queryable in Athena.



## 6. Set Up Alerts and Reporting (Optional)
- Configure alerts in Grafana, or use Athena query results to trigger alerts
- Generate periodic reports
