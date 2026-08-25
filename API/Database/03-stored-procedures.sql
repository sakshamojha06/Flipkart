-- Run this script connected to the FlipkartDB database (run 02-schema.sql first).
-- Stored procedures used by the API's repository layer. All input is parameterized.

USE FlipkartDB;
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetProducts
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Name, Category, Description, Price, Rating, Reviews, Stock, Color, Accent, Badge
    FROM dbo.Products
    ORDER BY Id;
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_GetProductById
    @Id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, Name, Category, Description, Price, Rating, Reviews, Stock, Color, Accent, Badge
    FROM dbo.Products
    WHERE Id = @Id;
END
GO

-- Creates an order from a set of (ProductId, Quantity) lines, pricing every line from the
-- current Products.Price rather than trusting any client-supplied price, validating stock,
-- and decrementing stock, all inside one transaction. Returns two result sets: the order
-- header, then its line items.
CREATE OR ALTER PROCEDURE dbo.usp_CreateOrder
    @Items dbo.OrderItemTableType READONLY
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM @Items)
    BEGIN
        THROW 50001, 'Order must contain at least one item.', 1;
    END

    IF EXISTS (SELECT 1 FROM @Items WHERE Quantity <= 0)
    BEGIN
        THROW 50002, 'Item quantity must be greater than zero.', 1;
    END

    IF EXISTS (
        SELECT 1
        FROM @Items i
        LEFT JOIN dbo.Products p ON p.Id = i.ProductId
        WHERE p.Id IS NULL
    )
    BEGIN
        THROW 50003, 'One or more products do not exist.', 1;
    END

    BEGIN TRANSACTION;

    IF EXISTS (
        SELECT 1
        FROM @Items i
        JOIN dbo.Products p WITH (UPDLOCK, ROWLOCK) ON p.Id = i.ProductId
        WHERE p.Stock < i.Quantity
    )
    BEGIN
        ROLLBACK TRANSACTION;
        THROW 50004, 'One or more products do not have enough stock.', 1;
    END

    DECLARE @Subtotal DECIMAL(10, 2);
    SELECT @Subtotal = SUM(p.Price * i.Quantity)
    FROM @Items i
    JOIN dbo.Products p ON p.Id = i.ProductId;

    DECLARE @OrderId INT;

    INSERT INTO dbo.Orders (Subtotal)
    VALUES (@Subtotal);

    SET @OrderId = SCOPE_IDENTITY();

    INSERT INTO dbo.OrderItems (OrderId, ProductId, ProductName, UnitPrice, Quantity)
    SELECT @OrderId, p.Id, p.Name, p.Price, i.Quantity
    FROM @Items i
    JOIN dbo.Products p ON p.Id = i.ProductId;

    UPDATE p
    SET p.Stock = p.Stock - i.Quantity
    FROM dbo.Products p
    JOIN @Items i ON i.ProductId = p.Id;

    COMMIT TRANSACTION;

    SELECT Id, OrderNumber, Subtotal, CreatedAt
    FROM dbo.Orders
    WHERE Id = @OrderId;

    SELECT Id, OrderId, ProductId, ProductName, UnitPrice, Quantity, LineTotal
    FROM dbo.OrderItems
    WHERE OrderId = @OrderId;
END
GO
