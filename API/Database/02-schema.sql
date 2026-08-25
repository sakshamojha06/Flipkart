-- Run this script connected to the FlipkartDB database (run 01-create-database.sql first).
-- Defines the Products, Orders, and OrderItems tables plus the OrderItemTableType used
-- by the usp_CreateOrder stored procedure. Safe to re-run: existing objects are dropped first.

USE FlipkartDB;
GO

IF TYPE_ID(N'dbo.OrderItemTableType') IS NOT NULL
    DROP TYPE dbo.OrderItemTableType;
GO

IF OBJECT_ID(N'dbo.OrderItems', N'U') IS NOT NULL
    DROP TABLE dbo.OrderItems;
GO

IF OBJECT_ID(N'dbo.Orders', N'U') IS NOT NULL
    DROP TABLE dbo.Orders;
GO

IF OBJECT_ID(N'dbo.Products', N'U') IS NOT NULL
    DROP TABLE dbo.Products;
GO

CREATE TABLE dbo.Products
(
    Id          INT             NOT NULL PRIMARY KEY,
    Name        NVARCHAR(200)   NOT NULL,
    Category    NVARCHAR(30)    NOT NULL
        CONSTRAINT CK_Products_Category CHECK (Category IN (N'Audio', N'Home', N'Desk', N'Wellness')),
    Description NVARCHAR(500)   NOT NULL,
    Price       DECIMAL(10, 2)  NOT NULL CONSTRAINT CK_Products_Price CHECK (Price >= 0),
    Rating      DECIMAL(3, 2)   NOT NULL CONSTRAINT CK_Products_Rating CHECK (Rating BETWEEN 0 AND 5),
    Reviews     INT             NOT NULL CONSTRAINT CK_Products_Reviews CHECK (Reviews >= 0),
    Stock       INT             NOT NULL CONSTRAINT CK_Products_Stock CHECK (Stock >= 0),
    Color       NVARCHAR(20)    NOT NULL,
    Accent      NVARCHAR(20)    NOT NULL,
    Badge       NVARCHAR(50)    NULL,
    CreatedAt   DATETIME2       NOT NULL CONSTRAINT DF_Products_CreatedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE INDEX IX_Products_Category ON dbo.Products(Category);
GO

CREATE TABLE dbo.Orders
(
    Id          INT             IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    OrderNumber AS (N'FK-' + RIGHT(N'000000' + CAST(Id AS VARCHAR(6)), 6)) PERSISTED,
    Subtotal    DECIMAL(10, 2)  NOT NULL CONSTRAINT CK_Orders_Subtotal CHECK (Subtotal >= 0),
    CreatedAt   DATETIME2       NOT NULL CONSTRAINT DF_Orders_CreatedAt DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE dbo.OrderItems
(
    Id          INT             IDENTITY(1, 1) NOT NULL PRIMARY KEY,
    OrderId     INT             NOT NULL CONSTRAINT FK_OrderItems_Orders REFERENCES dbo.Orders(Id) ON DELETE CASCADE,
    ProductId   INT             NOT NULL CONSTRAINT FK_OrderItems_Products REFERENCES dbo.Products(Id),
    ProductName NVARCHAR(200)   NOT NULL,
    UnitPrice   DECIMAL(10, 2)  NOT NULL CONSTRAINT CK_OrderItems_UnitPrice CHECK (UnitPrice >= 0),
    Quantity    INT             NOT NULL CONSTRAINT CK_OrderItems_Quantity CHECK (Quantity > 0),
    LineTotal   AS (UnitPrice * Quantity) PERSISTED
);
GO

CREATE INDEX IX_OrderItems_OrderId ON dbo.OrderItems(OrderId);
GO

-- Table type used to pass cart lines into dbo.usp_CreateOrder as a single parameter.
CREATE TYPE dbo.OrderItemTableType AS TABLE
(
    ProductId INT NOT NULL,
    Quantity  INT NOT NULL
);
GO
