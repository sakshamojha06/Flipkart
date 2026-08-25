-- Run this script connected to the FlipkartDB database (run 03-stored-procedures.sql first).
-- Seeds the catalog with the same six products the UI previously mocked. Idempotent: re-running
-- this script updates existing rows to match rather than duplicating or failing.

USE FlipkartDB;
GO

MERGE dbo.Products AS target
USING (VALUES
    (1, N'Moss Ceramic Speaker',  N'Audio',    N'Warm sound, soft-touch finish, and an all-day battery.',      89.00,  4.8, 124, 12, N'#c9d7c0', N'#355c4a', N'Staff pick'),
    (2, N'Cloud Desk Lamp',       N'Desk',     N'A calm pool of light with touch dimming and USB-C.',           64.00,  4.7, 88,  8,  N'#e8d9c9', N'#935c3d', NULL),
    (3, N'Linen Throw Blanket',   N'Home',     N'Textured natural linen for slow mornings and cool nights.',    72.00,  4.9, 51,  19, N'#d9d2c6', N'#6a6258', N'New'),
    (4, N'Daily Ritual Tumbler',  N'Wellness', N'Insulated steel, generous capacity, no-nonsense silhouette.',  28.00,  4.6, 203, 34, N'#c7dce0', N'#2e6872', NULL),
    (5, N'Oak Monitor Stand',     N'Desk',     N'Lift your setup with solid oak and hidden cable space.',       118.00, 4.8, 37,  5,  N'#e3c39f', N'#8b4e2e', NULL),
    (6, N'Pebble Headphones',     N'Audio',    N'Quiet focus with featherweight cushions and rich bass.',       146.00, 4.5, 76,  11, N'#d1cbd8', N'#5e4e75', NULL)
) AS source (Id, Name, Category, Description, Price, Rating, Reviews, Stock, Color, Accent, Badge)
ON target.Id = source.Id
WHEN MATCHED THEN
    UPDATE SET
        Name        = source.Name,
        Category    = source.Category,
        Description = source.Description,
        Price       = source.Price,
        Rating      = source.Rating,
        Reviews     = source.Reviews,
        Stock       = source.Stock,
        Color       = source.Color,
        Accent      = source.Accent,
        Badge       = source.Badge
WHEN NOT MATCHED BY TARGET THEN
    INSERT (Id, Name, Category, Description, Price, Rating, Reviews, Stock, Color, Accent, Badge)
    VALUES (source.Id, source.Name, source.Category, source.Description, source.Price, source.Rating, source.Reviews, source.Stock, source.Color, source.Accent, source.Badge);
GO
