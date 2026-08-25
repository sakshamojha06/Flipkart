-- Run this script connected to the `master` database.
-- Creates the FlipkartDB database if it does not already exist.

IF DB_ID(N'FlipkartDB') IS NULL
BEGIN
    CREATE DATABASE FlipkartDB;
END
GO

SELECT DB_ID('FlipkartDB');
