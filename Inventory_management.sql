use Inventory_db;

#Soutions to the ad hoc requests

-- retrieve all the product information, inluding its category & inventory levels

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


-- get all orders placed by customers , showing product names , order date, and quantity ordered

SELECT
  C.customername,
  p.productname,
  o.orderdate,
  o.QuantityOrdered
FROM
  order_details AS o
  JOIN customer AS c ON o.CustomerID = c.customerid
  JOIN product AS p ON p.productid = o.ProductID;

-- products below their reorder level 

SELECT
  p.productname,
  p.ReorderLevel,
  i.QuantityAvailable
FROM
  product p
  JOIN inventory AS i ON i.ProductID = p.productid
WHERE
  p.ReorderLevel > i.QuantityAvailable;


-- reorder alert 

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

#list all the customer who placed an order along with thier contact information

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

-- total quantity of poducts ordered per customer and month 

 SELECT
  monthname(orderdate) AS month,
  c.customername,
  sum(o.QuantityOrdered) AS quantity
FROM  customer AS c
JOIN order_details o ON o.CustomerID = c.CustomerID
GROUP BY 1,2;

 SELECT
  monthname(orderdate) AS month,
  sum(o.QuantityOrdered) AS quantity
FROM  customer AS c
JOIN order_details o ON o.CustomerID = c.CustomerID
GROUP BY 1
 
 -- stored function to automate searching 
 
#monthwise
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

-- location wise 
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

-- productid wise 
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
 
 -- Identify high-value customers who may be at risk of churning (no purchase in the last 6 months).

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

 
 -- What is the average time between orders for repeat customers?
 
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

-- Rank products within each category based on their total sales revenue.

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

-- monthly growth rate 
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

-- CUSTOMER LIFE TIME VALUE 
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





