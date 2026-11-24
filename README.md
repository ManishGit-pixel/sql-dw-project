# SQL Data Warehouse Project

Welcome! This project is a beginner-friendly guide to building a **SQL Server
data warehouse**. The basic idea is simple: take data from different places,
clean it up, and turn it into information people can use.

The data moves through these steps:

```text
Source data
    ↓
Bronze layer
    ↓
Silver layer
    ↓
Gold layer
    ↓
Reports and analytics
```

Along the way, we introduce some important data-engineering ideas:

- Loading data in small pieces instead of reloading everything every time.
- Keeping the original data safe in a **Bronze** layer.
- Cleaning and improving data in a **Silver** layer.
- Keeping history with **Slowly Changing Dimension (SCD) Type 2** logic.
- Creating fast, report-ready tables in a **Gold** layer.
- Recording what each pipeline run did.
- Checking whether the data looks correct.
- Using SQL queries to answer business questions.

> **Where things stand:** this repository currently contains the documentation
> only. It describes the warehouse design and workflow, but the SQL scripts,
> sample data, and deployment files still need to be added.

## What is a data warehouse?

A data warehouse is a database built for asking questions about data.

Imagine a shop has information in many places:

- Orders are in one file.
- Customers are in another file.
- Products are in a third system.
- Payments are in a separate application.

The warehouse brings all of this information together in one organized place.
That makes questions like these much easier to answer:

- How much money did we make this month?
- Which products sell the most?
- Which customers have not purchased recently?
- How have customer addresses changed over time?

An application database is usually built to save one transaction quickly. A
warehouse is built to read and compare lots of records quickly.

## What does “medallion architecture” mean?

**Medallion architecture** is simply a name for three layers. Each layer has a
different job.

### 1. Bronze: keep the original data

Think of the Bronze layer as the warehouse's **landing area**.

We copy data here with as little change as possible. Keeping the original
version is useful if a later transformation goes wrong and we need to check
where the problem started.

Typical Bronze columns include:

- The original business columns.
- The time the row was loaded.
- The name of the source file or system.
- A batch or pipeline-run identifier.

**In short:** Bronze should look like the source.

### 2. Silver: clean and organize the data

The Silver layer is where messy source data gets cleaned up and made
trustworthy.

Typical Silver work includes:

- Removing duplicate rows.
- Converting text dates into real date values.
- Standardizing names and categories.
- Handling missing values.
- Checking that required fields are present.
- Joining related source records.
- Applying business rules.

**In short:** Silver should be clean, consistent, and easy to understand.

### 3. Gold: make data easy to report

The Gold layer contains tables designed for dashboards, reports, and analysis.
These tables normally use business-friendly names and are arranged so that
queries do not need to perform the same complicated work repeatedly.

Gold usually contains:

- **Fact tables:** numbers we want to measure, such as sales amount or
  quantity.
- **Dimension tables:** descriptions of the things being measured, such as
  customers, products, dates, or stores.

**In short:** Gold should be fast and convenient for people writing reports.

## Example: answering a sales question

Imagine someone asks:

> “How much did each product sell last month?”

Here is how the warehouse helps:

1. The source system sends order data.
2. Bronze stores the incoming order data.
3. Silver checks dates, prices, quantities, and product identifiers.
4. Gold stores a sales fact table and a product dimension table.
5. An analyst joins those tables and adds the sales amounts.

The final query might look like this:

```sql
SELECT
    p.ProductName,
    SUM(f.Quantity * f.UnitPrice) AS TotalSales
FROM Gold.FactSales AS f
JOIN Gold.DimProduct AS p
    ON p.ProductKey = f.ProductKey
WHERE f.OrderDate >= '2025-01-01'
  AND f.OrderDate <  '2025-02-01'
GROUP BY p.ProductName
ORDER BY TotalSales DESC;
```

The table and column names may change when the real implementation is added.
The important idea is that facts hold measurements, while dimensions explain
what those measurements mean.

## Slowly Changing Dimension Type 2

A customer might move to a new address. If we simply overwrite the old address,
we lose the ability to answer questions about old orders.

**SCD Type 2** solves this by keeping the old row and creating a new version
for the customer.

For example:

| CustomerKey | CustomerId | Address       | IsCurrent | ValidFrom  | ValidTo    |
|---:|---|---|---:|---|---|
| 101 | C-10 | 12 Green Road | 0 | 2024-01-01 | 2025-03-14 |
| 205 | C-10 | 88 Blue Street | 1 | 2025-03-15 | 9999-12-31 |

Here, `CustomerId` identifies the real customer. `CustomerKey` identifies a
particular version of that customer in the warehouse.

Common SCD Type 2 columns are:

- `CustomerKey`: unique key for one historical version.
- `CustomerId`: identifier from the source system.
- `ValidFrom`: when this version started being true.
- `ValidTo`: when this version stopped being true.
- `IsCurrent`: `1` for the latest version and `0` for older versions.

When a tracked value changes, the pipeline normally:

1. Closes the old row by setting `ValidTo` and `IsCurrent = 0`.
2. Inserts a new row with the new values.
3. Sets the new row's `IsCurrent` value to `1`.

This means a report can use today's customer information or the information
that was true when an old order was placed.

## Incremental loading

An incremental load processes only data that is new or changed. Instead of
reading every source record on every run, it picks up where the last run
finished.

A common process is:

1. Remember the last successful load time or source-watermark value.
2. Ask the source for rows newer than that value.
3. Load those rows into Bronze.
4. Transform only the affected rows into Silver and Gold.
5. Save the new watermark after the load succeeds.

This is usually faster and uses fewer resources than loading everything again.

An incremental process must also handle:

- A row that is inserted for the first time.
- A row that is updated after it was already loaded.
- A row that is deleted in the source.
- A failed run that needs to be safely retried.
- Late-arriving data that has an older business date.

The watermark should only move forward after the related work has completed
successfully. Otherwise, a failure could make the pipeline skip data.

## Pipeline logging

Every load should leave a clear trail explaining what happened. A pipeline log can
record information such as:

| Field | Meaning |
|---|---|
| Run ID | Unique name for this pipeline run |
| Pipeline name | Which process was executed |
| Start time | When the run began |
| End time | When the run finished |
| Status | `Started`, `Succeeded`, or `Failed` |
| Rows read | Number of source rows examined |
| Rows inserted | Number of new rows written |
| Rows updated | Number of existing rows changed |
| Error message | Details when something failed |

Logging makes the warehouse easier to look after. If a report is missing data,
the log can help us work out whether the problem came from the source, a
transformation, or the load itself.

## Data quality checks

Data quality checks are small tests that protect the warehouse from bad data.
Think of them as safety checks before data is used in a report.
Examples include:

- A required customer ID must not be empty.
- A product price must not be negative.
- An order quantity must be greater than zero.
- A customer should not have two current SCD Type 2 rows.
- A fact row should have a matching product key.
- A date should be a valid date.
- Duplicate business keys should be detected.

A good check should clearly tell us:

1. What rule was tested.
2. How many rows failed.
3. Whether the pipeline should stop or continue.
4. Where the bad rows can be investigated.

## Columnstore indexes

Gold fact tables can become very large. SQL Server **columnstore indexes**
store data by column instead of by row. This is often helpful for analytics
because a report may need only a few columns from millions of rows.

For example, a sales report may need only these columns:

- Sale date.
- Product key.
- Quantity.
- Sales amount.

A columnstore index can read those columns without reading every other column.
It can make analytical queries faster and use less storage. However, test it
with real data and real queries before adding it everywhere.

## Suggested database layout

The intended schema layout is:

```text
Bronze   Original source-shaped tables
Silver   Cleaned and historically managed tables
Gold     Reporting facts and dimensions
Control  Pipeline runs, watermarks, and data-quality results
```

Keeping these areas separate makes it easier to understand where a row came
from and what has happened to it.

## Getting started

### Prerequisites

You will need:

- SQL Server or an SQL Server-compatible environment.
- A tool for running SQL, such as SQL Server Management Studio or Azure Data
  Studio.
- Permission to create databases, schemas, tables, procedures, and indexes.
- Source data to load.

### Setup steps

Once the scripts are available, the setup will look like this:

1. Create or choose a SQL Server database for the warehouse.
2. Create the `Bronze`, `Silver`, `Gold`, and `Control` schemas.
3. Create control tables for pipeline runs and incremental-load watermarks.
4. Create Bronze tables that match the source data.
5. Load a small sample into Bronze.
6. Run Silver transformations and data-quality checks.
7. Build Gold dimensions and fact tables.
8. Add indexes after checking query performance.
9. Run an analytics query against Gold.
10. Review the pipeline log and quality results.

Start with a small sample. It is much easier to understand and debug a
warehouse with 20 rows than with 20 million rows.

## Recommended load order

Run the steps in this order so each layer has what it needs:

```text
1. Start a pipeline run
2. Read the source watermark
3. Load new or changed rows into Bronze
4. Validate Bronze row counts and required fields
5. Transform Bronze into Silver
6. Apply SCD Type 2 changes
7. Build or update Gold dimensions
8. Build or update Gold facts
9. Run data-quality checks
10. Save the new watermark
11. Mark the pipeline run as succeeded
```

If a step fails, record the error and leave the run marked as failed. Do not
pretend it succeeded.

## Project structure

As the project grows, the files should be organized roughly like this:

```text
sql-dw-project/
├── README.md
├── datasets/          # Small sample source files
├── scripts/
│   ├── 01-create-schemas.sql
│   ├── 02-create-control-tables.sql
│   ├── 03-create-bronze-tables.sql
│   ├── 04-create-silver-tables.sql
│   ├── 05-create-gold-tables.sql
│   ├── 06-load-bronze.sql
│   ├── 07-load-silver.sql
│   ├── 08-load-gold.sql
│   └── 09-quality-checks.sql
└── queries/            # Example business and analytics queries
```

This is the planned layout. These folders and files are not in the repository
yet.

## How to check that the warehouse works

After a test load, take a few minutes to check:

- Bronze has the expected number of source rows.
- Silver has no unexpected duplicates.
- Each current dimension member has exactly one current row.
- Gold facts have valid dimension keys.
- Totals in Gold agree with the trusted source totals.
- A second run does not create duplicate rows.
- An updated customer creates a new SCD Type 2 version.
- A failed run is logged as failed and can be retried.

The most important incremental-load test is simple: run the same load twice.
The second run should not duplicate data that has not changed.

## Beginner glossary

| Word | Simple meaning |
|---|---|
| Source | The system where data originally comes from |
| Schema | A named folder-like area inside a database |
| Pipeline | A set of steps that moves and changes data |
| Batch | One group of rows processed together |
| Watermark | A value showing how far a load has progressed |
| Fact | A number or event we want to measure |
| Dimension | Information that describes a fact |
| Business key | An ID used by the source system |
| Surrogate key | A warehouse-created ID |
| Transformation | Changing data into a useful shape |
| Data quality | Whether data follows agreed rules |
| Columnstore | A storage format optimized for analytical queries |

## Design principles

The project is guided by a few simple rules:

1. **Keep the original data.** Bronze helps us investigate problems.
2. **Make changes traceable.** Logs and run IDs explain what happened.
3. **Do not lose history.** SCD Type 2 preserves important changes.
4. **Load only what is needed.** Incremental processing saves time.
5. **Test the data.** A successful SQL command does not always mean the data
   is correct.
6. **Keep reporting simple.** Gold should be easy for analysts to query.
7. **Prefer small, repeatable steps.** Small steps are easier to test and fix.

## License

No license has been selected for this repository yet.
