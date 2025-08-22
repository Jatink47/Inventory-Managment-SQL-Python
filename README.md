## Inventory-Managment-SQL-Python

## Objective
- The objective of this analysis is to address ad-hoc business queries from management and uncover meaningful insights from the provided dataset to support decision-making.
- The goal of this representation is to transform raw data into clear insights, enabling management to make informed strategic and operational decisions.

## 📑 Table of Contents
1. [Dataset](#dataset)
2. [Tools & Technologies](#tools--technologies)
3. [Database Schema](#database-schema)
4. [Data Cleaning & Preparation](#data-cleaning--preparation)
5. [Exploratory Data Analysis (EDA)](#exploratory-data-analysis-eda)
6. [Analysis Report](#analysis-report)
7. [Final Recommendations](#final-recommendations)

## Dataset
Multiple CSV files (product, category, customer, warehouse, order_details, inventory) located in data

## Tools & Technologies
- Python(For Dayacleaning & insertion using Pandas, Matplotlib, pymysql)
- SQL (For main analysis of dataset using CTEs, JOINS, Filtering)
- MySQL(To the run the SQL query)
- PowerPoint(For making the presentation)

## Database Schema

![image](https://github.com/Jatink47/Inventory-Managment-SQL-Python/blob/main/ER%20Diagram.png) 


## Data Cleaning & Preparation
- Created Python script with embedded SQL queries to create database & tables by making connection with MySQL server.
- Corrected the format of order date column into  YY-MM-DD 

## Exploratory Data Analysis (EDA)


- **Retrieve all the product information, inluding its category & inventory levels**

```sql

WITH product_info AS (
    SELECT 
        PRODUCTID, 
        SUM(QuantityAvailable) AS QUANTITY 
    FROM 
        inventory
    GROUP BY 
        1
)
Select 
    p.productid,
    p.productname,
    c.categoryname, 
    i.QUANTITY
from 
    product as p
join 
    category c on c.CategoryID = p.CategoryID
join 
    product_info i on i.PRODUCTID = p.ProductID
order by QUANTITY desc;    

```
- **Get all orders placed by customers , showing product names , order date, and quantity ordered**

```sql
SELECT
  C.customername,
  p.productname,
  o.orderdate,
  o.QuantityOrdered
FROM
  order_details AS o
  JOIN customer AS c ON o.CustomerID = c.customerid
  JOIN product AS p ON p.productid = o.ProductID;
```
- **Products below their reorder level**
```sql
SELECT
  p.productname,
  p.ReorderLevel,
  i.QuantityAvailable
FROM
  product p
  JOIN inventory AS i ON i.ProductID = p.productid
WHERE
  p.ReorderLevel > i.QuantityAvailable;

```
- **Reorder alert for having shortage of quantity**
```sql
    SELECT
      p.productname,
      p.ReorderLevel,
      i.QuantityAvailable,
      (p.ReorderLevel - i.QuantityAvailable) AS Shortage
    FROM
      product p
      JOIN inventory AS i ON i.ProductID = p.productid
    WHERE
      p.ReorderLevel > i.QuantityAvailable
    ORDER BY Shortage DESC;
```
-  **List all the customer who placed an order along with thier contact information**
```sql
SELECT
  c.customerid,
  c.customername,
  c.phone,
  c.email,
  c.address,
  o.QuantityOrdered,
  o.OrderID,
  o.OrderDate
FROM
  customer AS c
  JOIN order_details o ON o.CustomerID = c.CustomerID;
```
- **Total quantity of poducts ordered per customer and month**
```sql
 SELECT
  monthname(orderdate) AS month,
  c.customername,
  sum(o.QuantityOrdered) AS quantity
FROM  customer AS c
JOIN order_details o ON o.CustomerID = c.CustomerID
GROUP BY 1,2;
 ```
 - **Stored function to automate searching**
 
**1.Monthwise**
 ```sql
 delimiter //
CREATE PROCEDURE month_quantity (IN months VARCHAR(50))
BEGIN
  SELECT
    monthname(orderdate) AS month,
    sum(o.QuantityOrdered) AS quantity
    FROM customer as c
  JOIN order_details o ON o.CustomerID = c.CustomerID
  WHERE
    monthname(orderdate) = months
  GROUP BY
    1;
END;
//
```

2.**Location wise**

```sql
delimiter //

CREATE PROCEDURE location_stock (IN locations VARCHAR(50))
BEGIN
  SELECT
    p.productname,
    i.QuantityAvailable,
    w.WarehouseName,
    w.location
  FROM warehouse w
    JOIN inventory AS i ON i.warehouseid = w.Warehouseid
    JOIN product AS p ON i.ProductID = p.ProductID
  WHERE w.location = locations;
END;
//
```

**3.ProductId wise** 

```sql
delimiter //

CREATE PROCEDURE product_location (IN productid VARCHAR(50))
BEGIN
  SELECT
    p.productname,
    i.QuantityAvailable,
    w.WarehouseName,
    w.location
  FROM warehouse w
    JOIN inventory AS i ON i.warehouseid = w.Warehouseid
    JOIN product AS p ON i.ProductID = p.ProductID
  WHERE p.productid = productid;
END;
//
```
- **Identify high-value customers who may be at risk of churning (no purchase in the last 6 months).**
```sql
WITH CustomerValueAndLastOrder AS (
  SELECT
    c.CustomerID,
    c.CustomerName,
    Round(SUM(od.QuantityOrdered * od.Price)/100000,2)AS TotalSpent,
    MAX(od.OrderDate) AS LastOrderDate
  FROM customer c
    JOIN order_details od ON c.CustomerID = od.CustomerID
  GROUP BY
    c.CustomerID,
    c.CustomerName
)
SELECT *
FROM CustomerValueAndLastOrder
WHERE LastOrderDate < (CURRENT_DATE - INTERVAL 6 MONTH);

 ```

 - **What is the average time between orders for repeat customers**?
 ```sql
 WITH OrderedDates AS (
  SELECT
    CustomerID,
    OrderDate,
    LAG(OrderDate, 1) OVER (
      PARTITION BY CustomerID
      ORDER BY OrderDate
    ) AS PreviousOrderDate
  FROM (
      SELECT DISTINCT CustomerID, OrderDate
      FROM Order_Details
  ) AS sub
)
SELECT
  c.CustomerName,
  ROUND(AVG(DATEDIFF(OrderDate, PreviousOrderDate))) AS AvgDaysBetweenOrders
FROM OrderedDates od
JOIN Customer c ON od.CustomerID = c.CustomerID
WHERE PreviousOrderDate IS NOT NULL
GROUP BY c.CustomerName
ORDER BY AvgDaysBetweenOrders;
```
- **Rank products within each category based on their total sales revenue.**
```sql
SELECT 
    c.CategoryName,
    p.ProductName,
   ROUND(SUM(od.QuantityOrdered * od.Price)/100000, 2) AS TotalRevenue,
    RANK() OVER (
        PARTITION BY c.CategoryName 
        ORDER BY SUM(od.QuantityOrdered * od.Price) DESC
    ) AS RankInCategory
FROM Product p
JOIN Order_Details od 
    ON p.ProductID = od.ProductID
JOIN Category c 
    ON p.CategoryID = c.CategoryID
GROUP BY 
    c.CategoryName, 
    p.ProductID, 
    p.ProductName
ORDER BY 
    c.CategoryName, 
    RankInCategory;
```
- **Monthly Growth Rate** 

```sql
WITH MonthlySales AS (
  SELECT
    DATE_FORMAT(OrderDate, '%Y-%m') AS SalesMonth,
    SUM(QuantityOrdered * Price) / 100000 AS MonthlyRevenue
  FROM Order_Details
  GROUP BY DATE_FORMAT(OrderDate, '%Y-%m')
)
SELECT
  SalesMonth,
   ROUND(MonthlyRevenue, 2) AS MonthlyRevenue,
  ROUND(
    ((MonthlyRevenue - LAG(MonthlyRevenue) OVER (ORDER BY SalesMonth)) 
     / LAG(MonthlyRevenue) OVER (ORDER BY SalesMonth)) * 100, 2
  ) AS GrowthRatePercent
FROM MonthlySales
ORDER BY SalesMonth;
```

- **CUSTOMER LIFE TIME VALUE** 

```sql
WITH CustomerSpending AS (
  SELECT
    c.CustomerID,
    c.CustomerName,
    CONCAT("Rs. ",ROUND(SUM(od.QuantityOrdered * od.Price)/100000,2)," Lakhs") AS TotalRevenue
  FROM
    Customer c
    JOIN Order_Details od ON c.CustomerID = od.CustomerID
  GROUP BY
    c.CustomerID,
    c.CustomerName
)
SELECT
  CustomerName,
  TotalRevenue AS CustomerLifetimeValue
FROM CustomerSpending
ORDER BY TotalRevenue DESC;

```

##  Analysis Report 

[Analysis Report](https://github.com/Jatink47/Inventory-Managment-SQL-Python/blob/main/Business_Report_Inventory_Management.pdf)

## Final Recommendations
- Promote product bundles to increase average order value and move inventory faster.
- Fix reorder strategy to avoid stockouts/overstocking and align with actual sales velocity.
- Focus on top-selling products and reduce inventory/marketing spend on underperforming ones.
- Segment customers by buying frequency and send targeted reminders/offers before expected repurchase.
- Protect high-value customers (e.g., Beth Miller, Stephanie Leon) through loyalty programs and account management.
- Launch win-back campaigns for 49 churned high-value clients and investigate Sept/Oct 2024 churn drivers.
- Investigate the 53% October revenue drop to identify root causes (pricing, service, competition).\
- Grow mid- and low-value customers by designing targeted strategies to move them into higher-value segments.
