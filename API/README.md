# Flipkart Catalog API — Reference & Interview Prep

This README documents the API project's architecture and ships with **100 real interview
questions with detailed answers** (50 C# / ASP.NET Core, 50 SQL Server) built around the
actual features used in this codebase — Dapper, stored procedures, table-valued parameters,
transactions, computed columns, dependency injection, and more. It's aimed at junior software
developer interview prep, so answers favor clarity and working examples over academic depth.

## Table of Contents

- [Project Overview](#project-overview)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [C# / .NET / ASP.NET Core Interview Questions (50)](#c--net--aspnet-core-interview-questions-50)
- [SQL Server Interview Questions (50)](#sql-server-interview-questions-50)

---

## Project Overview

The API is a small e-commerce backend (product catalog + order creation) that serves an
Angular front end. It exposes two resources:

- **Products** — `GET /api/products`, `GET /api/products/{id}` (read-only catalog)
- **Orders** — `POST /api/orders` (creates an order from a cart of product/quantity lines)

All data access goes through ADO.NET/Dapper calling **stored procedures** — there is no ORM
and no raw inline SQL in C#. Order creation, stock validation, and pricing all happen inside
a single SQL Server transaction (`dbo.usp_CreateOrder`), not in application code.

## Tech Stack

| Layer | Technology |
|---|---|
| API framework | ASP.NET Core (.NET 10), Minimal Hosting Model |
| Data access | Dapper 2.1.35 over `Microsoft.Data.SqlClient` 5.2.2 |
| Database | SQL Server (stored procedures, TVPs, transactions) |
| Docs | Swashbuckle (Swagger / OpenAPI) |
| Front end | Angular (consumes the API over CORS) |

## Architecture

```
Controllers (HTTP concerns only)
    ProductsController, OrdersController
        │
        ▼
Repositories (data access, behind interfaces)
    IProductRepository / ProductRepository
    IOrderRepository / OrderRepository
        │  Dapper (QueryAsync / QueryMultipleAsync)
        ▼
SQL Server (stored procedures own the business rules)
    dbo.usp_GetProducts, dbo.usp_GetProductById, dbo.usp_CreateOrder
```

Key files:
- [`Program.cs`](Program.cs) — DI container, CORS, Swagger, exception handling
- [`Data/ProductRepository.cs`](Data/ProductRepository.cs) — read-only catalog queries
- [`Data/OrderRepository.cs`](Data/OrderRepository.cs) — TVP-based order creation, custom exception translation
- [`Data/IDbConnectionFactory.cs`](Data/IDbConnectionFactory.cs) — connection creation abstraction
- [`Database/02-schema.sql`](Database/02-schema.sql) — tables, constraints, computed columns, the TVP type
- [`Database/03-stored-procedures.sql`](Database/03-stored-procedures.sql) — all business logic, incl. the order transaction
- [`Database/04-seed.sql`](Database/04-seed.sql) — idempotent `MERGE`-based seed data

---

## C# / .NET / ASP.NET Core Interview Questions (50)

### 1. What is .NET, and what role does the CLR play?
.NET is a managed runtime and framework for building applications. The **CLR** (Common
Language Runtime) is the engine that executes compiled IL (Intermediate Language) code: it
handles memory management (garbage collection), type safety, exception handling, and JIT
(Just-In-Time) compilation of IL to native machine code at runtime. When you run this API
with `dotnet run`, the CLR loads `API.dll`, JIT-compiles the methods as they're first called,
and manages the lifetime of every object — like the `SqlConnection` created in
`SqlConnectionFactory`.

### 2. What's the difference between value types and reference types?
Value types (`int`, `decimal`, `bool`, `struct`) are stored inline (on the stack or inline in
containing objects) and copied by value when assigned. Reference types (`class`, `string`,
arrays) store a reference to heap-allocated data; assignment copies the reference, not the
data. `ProductDto` is a class (reference type) — passing it around passes a pointer to one
object. Its `Price` and `Rating` properties are `decimal` (value types) — each `ProductDto`
has its own independent copy of those numbers.

```csharp
ProductDto a = new() { Price = 10 };
ProductDto b = a;      // b references the SAME object as a
b.Price = 20;
// a.Price is now 20 too — reference semantics

decimal p1 = a.Price;  // p1 is a COPY of the decimal value
decimal p2 = p1;
p2 = 30;                // p1 is unaffected — value semantics
```

### 3. What are nullable reference types, and how does this project use them?
Enabled via `<Nullable>enable</Nullable>` in [`API.csproj`](API.csproj), this compiler feature
makes reference types non-nullable by default and requires an explicit `?` to allow null,
giving you compile-time warnings for potential null dereferences. In `ProductDto`, `Badge` is
declared `string? Badge` because not every product has a badge, while `Name` is plain
`string` (non-nullable) because a product must always have a name.

```csharp
public string Name { get; set; } = string.Empty; // must never be null
public string? Badge { get; set; }               // null is a valid, expected value
```

### 4. Why does `ProductDto.Name` default to `= string.Empty` instead of being left null?
With nullable reference types enabled, a non-nullable `string` property must be guaranteed
non-null. Since Dapper will populate it from the query result before it's ever read, the
`= string.Empty` default just satisfies the compiler's definite-assignment analysis and gives
a safe fallback if a property were ever read before being set, avoiding `NullReferenceException`s
entirely for that field.

### 5. What is an auto-implemented property?
A property where the compiler generates the backing field for you — you just declare
`{ get; set; }` instead of writing a private field and accessor methods manually. Every
property on `ProductDto` and `OrderResponse` is auto-implemented.

```csharp
public class ProductDto
{
    public int Id { get; set; }          // compiler generates a hidden backing field
    public string Name { get; set; } = string.Empty;
}
```

### 6. What is an interface, and why does this project define `IProductRepository`?
An interface is a contract — a set of member signatures with no implementation — that a class
can promise to fulfill. `IProductRepository` declares `GetProductsAsync` and
`GetProductByIdAsync` without saying how they're implemented. `ProductsController` depends on
the interface, not the concrete `ProductRepository`, so the controller doesn't know or care
that Dapper/SQL Server is involved underneath — it could be swapped for an in-memory fake in a
test.

```csharp
public interface IProductRepository
{
    Task<IEnumerable<ProductDto>> GetProductsAsync();
    Task<ProductDto?> GetProductByIdAsync(int id);
}
```

### 7. Interface vs. abstract class — when would you use each?
An interface defines *what* a type can do with no shared implementation (a class can
implement many interfaces); an abstract class defines a partial *is-a* relationship and can
share code, fields, and constructors between derived classes (a class can inherit only one).
This project uses interfaces (`IProductRepository`, `IOrderRepository`,
`IDbConnectionFactory`) because the goal is swappable, testable contracts, not shared
implementation — there's no common base behavior to factor out between a product repository
and an order repository.

### 8. What is Dependency Injection, and how is it used in `Program.cs`?
Dependency Injection (DI) means a class receives its dependencies from the outside (usually
via its constructor) instead of creating them itself. ASP.NET Core has a built-in DI container
that you register services into and it resolves the object graph automatically.
`ProductRepository`'s constructor takes an `IDbConnectionFactory` — it never `new`s one up.

```csharp
builder.Services.AddSingleton<IDbConnectionFactory>(_ => new SqlConnectionFactory(connectionString));
builder.Services.AddScoped<IProductRepository, ProductRepository>();
builder.Services.AddScoped<IOrderRepository, OrderRepository>();
```
When a request comes in for `ProductsController`, the container builds a `ProductRepository`
and injects an `IDbConnectionFactory` into it automatically.

### 9. What's the difference between `AddSingleton`, `AddScoped`, and `AddTransient`?
- **Singleton**: one instance for the entire application lifetime. `SqlConnectionFactory` is
  a singleton — it holds only an immutable connection string, so it's safe to share.
- **Scoped**: one instance per HTTP request. `ProductRepository`/`OrderRepository` are scoped
  — a fresh instance per request, appropriate since they're cheap to create and stateless
  between requests.
- **Transient**: a new instance every time it's requested, even within the same request.

Using singleton for something request-specific (like a `DbContext`) would cause thread-safety
bugs; using transient for something expensive to build wastes resources.

### 10. What is `async`/`await`, and why do the repository methods return `Task<T>`?
`async`/`await` lets a method start an I/O-bound operation (like a database call) and yield
the thread back to the pool while waiting, instead of blocking it. `Task<T>` represents a
value that will be available in the future. `GetProductsAsync` returns
`Task<IEnumerable<ProductDto>>` so ASP.NET Core can free the request thread while SQL Server
processes `usp_GetProducts`, letting the same thread pool serve other requests concurrently —
critical for API scalability under load.

```csharp
public async Task<IEnumerable<ProductDto>> GetProductsAsync()
{
    using var connection = _connectionFactory.CreateConnection();
    return await connection.QueryAsync<ProductDto>(
        "dbo.usp_GetProducts", commandType: CommandType.StoredProcedure);
}
```

### 11. What happens if you call `.Result` or `.Wait()` on a `Task` instead of `await`ing it?
It synchronously blocks the calling thread until the task completes, defeating the purpose of
async I/O and risking **deadlocks** in contexts with a synchronization context (like older
ASP.NET, or UI apps) because the continuation may need the very thread that's blocked waiting.
The rule of thumb is "async all the way": once a method is async, everything that calls it
should `await` it, not synchronously block on it.

### 12. What's the difference between `IEnumerable<T>`, `ICollection<T>`, and `List<T>`?
`IEnumerable<T>` only guarantees you can iterate forward once (lazy, deferred execution
possible); `ICollection<T>` adds `Count`, `Add`, `Remove`; `List<T>` is a concrete,
indexable, resizable implementation. `GetProductsAsync` returns `IEnumerable<ProductDto>` —
the caller only needs to enumerate the results, so the repository exposes the narrowest useful
contract rather than forcing a concrete `List<T>`.

### 13. What is LINQ? Explain `request.Items.Any(item => item.Quantity <= 0)`.
LINQ (Language Integrated Query) lets you query in-memory collections (or databases, via
providers) with a consistent, declarative syntax. `Any` is a LINQ extension method that
returns `true` if at least one element satisfies a predicate, short-circuiting as soon as it
finds a match. In [`OrdersController.cs`](Controllers/OrdersController.cs), it's used to
validate the request before even touching the database:

```csharp
if (request.Items.Any(item => item.Quantity <= 0))
{
    return BadRequest(new { message = "Item quantity must be greater than zero." });
}
```

### 14. What's a lambda expression?
An inline, unnamed function — `item => item.Quantity <= 0` reads as "given `item`, evaluate
`item.Quantity <= 0`". Lambdas are used throughout for LINQ predicates and for DI factory
registrations, e.g. `_ => new SqlConnectionFactory(connectionString)` in `Program.cs`, where
the underscore signals an unused parameter (the `IServiceProvider`).

### 15. How does exception handling work in C# (`try`/`catch`/`finally`)?
Code that might throw goes in `try`; `catch` blocks handle specific exception types (most
specific first); `finally` always runs, whether or not an exception occurred, and is typically
used for cleanup. `OrderRepository.CreateOrderAsync` wraps the Dapper call in a `try`/`catch`
to translate a low-level `SqlException` into a domain-meaningful `OrderValidationException`
that the controller understands.

### 16. Why does this project define a custom exception, `OrderValidationException`?
Custom exceptions let you represent domain-specific failure conditions distinctly from
generic framework exceptions, so calling code can catch precisely what it expects without
inspecting error strings or numbers. `OrdersController` only needs to know "order validation
failed" — it doesn't need to know or care that this originated from a SQL `THROW` with error
number 50001–50004.

```csharp
public class OrderValidationException : Exception
{
    public OrderValidationException(string message) : base(message) { }
}
```

### 17. What is an exception filter — explain the `when` clause on the `catch`.
An exception filter (`catch (Type ex) when (condition)`) lets a `catch` block match not just
by exception type but also by a boolean condition, without unwinding the stack until the
condition is checked. `OrderRepository` uses this to only translate `SqlException`s in the
custom error-number range that `usp_CreateOrder` uses for validation failures — any other
`SqlException` (e.g. a connection timeout, or a genuine schema/constraint bug) is *not*
caught here and propagates up as an unhandled 500 error instead of being misreported as a
validation failure.

```csharp
catch (SqlException ex) when (ex.Number is >= 50000 and < 51000)
{
    throw new OrderValidationException(ex.Message);
}
```

### 18. What does the `using` statement do, and why is it used for `IDbConnection`?
`using` ensures `Dispose()` is called on an `IDisposable` object once it goes out of scope,
even if an exception is thrown — critical for releasing unmanaged resources like open database
connections/sockets promptly rather than waiting for garbage collection. Every repository
method opens a connection in a `using` block so the connection is always returned to the pool
after the query completes.

### 19. Using declaration vs. using statement — what's `using var connection = ...`?
`using var x = ...;` (C# 8+, a "using declaration") disposes `x` at the end of the *enclosing
block* (here, the method), without needing an extra nested `{ }` block — less indentation than
the older `using (var x = ...) { ... }` form, with identical disposal semantics. Every
repository method in this project uses the newer declaration form:
`using var connection = _connectionFactory.CreateConnection();`.

### 20. What does the `var` keyword do — is it dynamic typing?
`var` is *implicit, static* typing: the compiler infers the exact type at compile time from
the right-hand side, and that type is then fixed — it is **not** like `dynamic`, which defers
type resolution to runtime. `using var connection = _connectionFactory.CreateConnection();`
compiles exactly as if you'd written `using IDbConnection connection = ...;` — `var` is purely
a readability shorthand.

### 21. What is a namespace, and what's a "file-scoped" namespace?
A namespace groups related types to avoid naming collisions and organize code (`API.Data`,
`API.Models`, `API.Controllers`). C# 10 introduced file-scoped namespace declarations
(`namespace API.Data;` with a semicolon, no braces) that apply to the whole file, saving one
level of indentation compared to the older `namespace API.Data { ... }` block syntax. Every
file in this project uses the file-scoped form.

### 22. What access modifiers are available, and what does `readonly` mean?
`public`, `private`, `protected`, `internal` (and combinations like `protected internal`)
control visibility. `readonly` on a field means it can only be assigned in its declaration or
in the declaring type's constructor — never afterward. `ProductRepository`'s
`_connectionFactory` field is `private readonly`: it's only visible inside the class, and only
ever set once, in the constructor, guaranteeing it can't be reassigned later and helping
reason about thread-safety.

```csharp
private readonly IDbConnectionFactory _connectionFactory;
public ProductRepository(IDbConnectionFactory connectionFactory)
{
    _connectionFactory = connectionFactory; // only legal assignment point
}
```

### 23. What is a DTO, and how does `ProductDto` illustrate it?
A Data Transfer Object is a plain class whose only job is carrying data between layers/across
a boundary (e.g., API to client) — no business logic. `ProductDto` mirrors the shape of the
`Products` table/`usp_GetProducts` result set exactly, and Dapper maps each SQL column to a
same-named property automatically. Keeping DTOs separate from any hypothetical domain/entity
model keeps the API's public contract decoupled from internal persistence details.

### 24. What's the difference between a `class` and a `record`?
Both are reference types, but `record` gives you compiler-generated value-based equality
(`Equals`/`GetHashCode` compare property values, not references), a readable `ToString()`, and
`with`-expression non-destructive mutation — well suited to immutable data. This project uses
plain classes for its models (`ProductDto`, `OrderResponse`) since they're mutable, Dapper-
populated DTOs; a `record` would be a reasonable alternative for something like
`CreateOrderItemRequest` if immutability were desired.

```csharp
public record ProductSummary(int Id, string Name); // value equality, immutable by convention
```

### 25. What is the target-typed `new()` expression?
Introduced in C# 9, `new()` lets you omit the type name on the right-hand side when the
compiler can infer it from context (e.g., the declared property type). `CreateOrderRequest`
uses it: `public List<CreateOrderItemRequest> Items { get; set; } = new();` — the compiler
knows `Items` is `List<CreateOrderItemRequest>`, so `new()` alone suffices instead of
`new List<CreateOrderItemRequest>()`.

### 26. Explain the null-coalescing (`??`) and null-conditional (`?.`) operators via `Program.cs`.
`??` returns the left operand if it's non-null, otherwise the right; `?.` short-circuits a
member access to `null` if the receiver is `null` instead of throwing. `Program.cs` combines
`??` with `throw` to fail fast at startup if configuration is missing:

```csharp
var connectionString = builder.Configuration.GetConnectionString("FlipkartDB")
    ?? throw new InvalidOperationException("Missing 'ConnectionStrings:FlipkartDB' configuration.");
```
This is a "throw expression" — `throw` used as an expression, valid on the right side of `??`.

### 27. What is an extension method? How does Dapper use them?
An extension method adds a new method to an existing type without modifying its source, via a
`static` method in a `static` class whose first parameter is prefixed with `this`. Dapper is
implemented entirely as extension methods on `IDbConnection` — `QueryAsync<T>`,
`QueryFirstOrDefaultAsync<T>`, `QueryMultipleAsync` are not members of `SqlConnection` itself;
they're Dapper's extensions that call `ExecuteReader` under the hood and map rows onto `T`.

```csharp
// simplified sketch of how Dapper's extension is declared
public static class SqlMapper
{
    public static Task<IEnumerable<T>> QueryAsync<T>(this IDbConnection cnn, string sql, ...) { ... }
}
```

### 28. What are generics, and why is `Task<IEnumerable<ProductDto>>` generic?
Generics let a type or method be parameterized over another type, giving compile-time type
safety and avoiding boxing/casting that would be needed with `object`. `Task<T>` is generic
over its result type; `IEnumerable<T>` is generic over its element type. Nesting them as
`Task<IEnumerable<ProductDto>>` precisely describes "an asynchronous operation that will
eventually produce a sequence of `ProductDto`" — no casts needed anywhere the method is called.

### 29. How is polymorphism demonstrated by injecting `IProductRepository`?
Polymorphism lets code operate on an abstraction (the interface) while the concrete behavior
varies by the object actually supplied at runtime. `ProductsController` is coded entirely
against `IProductRepository` — it calls `GetProductsAsync()` without knowing (or needing to
know) that the runtime type is `ProductRepository` talking to SQL Server. In a unit test, you
could inject a fake `IProductRepository` implementation instead, and the controller's code
wouldn't need to change at all.

### 30. Explain the Dependency Inversion Principle using `IDbConnectionFactory`.
Dependency Inversion says high-level modules shouldn't depend on low-level modules — both
should depend on abstractions. `ProductRepository` (higher-level: "get me products") doesn't
depend on `SqlConnectionFactory` (lower-level: "how to open a SQL connection") directly; both
depend on the `IDbConnectionFactory` abstraction. This means swapping the concrete connection
strategy, or substituting a test double, never requires touching `ProductRepository`.

### 31. Explain the Single Responsibility Principle using the Controller/Repository split.
Each class should have one reason to change. `ProductsController` handles only HTTP concerns
(routing, status codes, request/response shaping); `ProductRepository` handles only data
access (talking to SQL Server via Dapper). If the database technology changed, only the
repository changes; if the API's URL scheme changed, only the controller changes — neither
change ripples into the other class.

### 32. What is ASP.NET Core middleware, and why does order matter?
Middleware components form a pipeline that each incoming HTTP request passes through in
registration order (and back out in reverse). Registering `UseCors` before `MapControllers`
in `Program.cs` matters: CORS headers must be evaluated/applied before the request reaches
routing/controller execution, otherwise cross-origin requests from the Angular app (running on
`localhost:4200`) would be rejected by the browser before controller logic ever runs.

```csharp
app.UseExceptionHandler();
app.UseCors("AngularClient");
app.MapControllers();
```

### 33. How does attribute routing work — explain `[Route("api/[controller]")]` and `[HttpGet("{id:int}")]`.
Attribute routing defines routes declaratively on controllers/actions rather than in a central
route table. `[controller]` is a token that's replaced with the controller's name minus the
"Controller" suffix, so `ProductsController` → `api/products`. `[HttpGet("{id:int}")]` on
`GetProduct` maps `GET /api/products/{id}` to that specific action, combined with the
controller's base route.

### 34. What is a route constraint, and what does `{id:int}` enforce?
A route constraint restricts what values a route parameter will match, so requests that don't
match fall through to routing failure (typically a 404) instead of reaching the action with an
invalid value. `{id:int}` on `GetProduct(int id)` means only numeric segments match this route
— a request to `GET /api/products/abc` never invokes this action.

### 35. What is model binding, and what does `[FromBody]` do?
Model binding automatically populates action method parameters from parts of the HTTP request
(route values, query string, headers, or body) by matching names/types. `[FromBody]` tells
ASP.NET Core to deserialize the entire request body (JSON) into the parameter.
`CreateOrder([FromBody] CreateOrderRequest request)` in `OrdersController` deserializes the
POSTed JSON cart directly into a `CreateOrderRequest` object.

### 36. What are `IActionResult` and the common results used in this project?
`IActionResult` is the abstraction that lets an action method return different HTTP responses
(status code + optional body) through a common return type. `Ok(products)` returns 200 with a
body; `NotFound()` returns 404; `BadRequest(new { message = ... })` returns 400 with a JSON
error; `CreatedAtAction(nameof(CreateOrder), new { id = order.Id }, order)` returns 201 with a
`Location` header pointing back to the created resource plus the resource in the body.

### 37. What does the `[ApiController]` attribute do automatically?
It opts a controller into several conveniences: automatic HTTP 400 responses when model
validation fails (before the action even runs), requiring attribute routing, inferring binding
sources (e.g., complex types from the body by default), and returning `ProblemDetails` for
error responses. Both `ProductsController` and `OrdersController` are decorated with it.

### 38. What is CORS, and why is it needed here?
CORS (Cross-Origin Resource Sharing) is a browser security mechanism that blocks a web page
from calling an API on a different origin (scheme+host+port) unless the server explicitly
allows it via response headers. The Angular app runs on `http://localhost:4200` while the API
runs on a different port, so `Program.cs` defines and applies a named CORS policy whose
allowed origins come from configuration:

```csharp
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? Array.Empty<string>();
builder.Services.AddCors(options =>
    options.AddPolicy("AngularClient", policy => policy.WithOrigins(allowedOrigins).AllowAnyHeader().AllowAnyMethod()));
```

### 39. What is Swagger/OpenAPI, and what do `AddSwaggerGen`/`UseSwaggerUI` do?
Swagger/OpenAPI is a specification for describing a REST API's shape (endpoints, parameters,
responses) in a machine-readable document, which tooling can then render as interactive
documentation. `AddEndpointsApiExplorer` + `AddSwaggerGen` generate that document from the
controllers' attributes/types at startup; `UseSwaggerUI` serves an interactive browser page for
it. Both are gated to `Development` in `Program.cs` so this exploratory UI isn't exposed in
production.

### 40. How does ASP.NET Core configuration work — explain `appsettings.json` and `IConfiguration`.
ASP.NET Core builds a layered configuration from multiple sources (`appsettings.json`,
`appsettings.{Environment}.json`, environment variables, command line, etc.), with later
sources overriding earlier ones, all exposed through `IConfiguration`/`builder.Configuration`.
`GetConnectionString("FlipkartDB")` is shorthand for reading
`ConnectionStrings:FlipkartDB` from that merged configuration.

### 41. What are environment-specific settings files, and what does `IsDevelopment()` do?
`appsettings.Development.json` overlays `appsettings.json` only when the
`ASPNETCORE_ENVIRONMENT` variable is set to `Development`, letting you keep different logging
levels, connection strings, etc. per environment without branching code. `Program.cs` checks
`app.Environment.IsDevelopment()` to decide whether to expose Swagger — a good example of
gating a feature by environment rather than by a manual flag.

### 42. How does global exception handling work via `AddProblemDetails()` + `UseExceptionHandler()`?
`AddProblemDetails()` registers RFC 7807-compliant error response formatting; `app.UseExceptionHandler()`
(with no parameters, in .NET 8+) adds middleware that catches unhandled exceptions anywhere
later in the pipeline and turns them into a standardized JSON problem response (500 by
default) instead of letting a raw stack trace or a hard-crashed connection reach the client.
This is the safety net behind any exception that isn't explicitly caught, e.g. a database
outage.

### 43. What is Dapper, and how does it differ from Entity Framework Core?
Dapper is a lightweight "micro-ORM": you write the SQL (or call a stored procedure) yourself,
and Dapper's job is only to map the resulting rows onto your C# objects efficiently via
reflection — it doesn't track entities, generate SQL, manage migrations, or offer change
tracking/LINQ-to-SQL like EF Core does. This project uses Dapper because all business logic
intentionally lives in stored procedures (`usp_GetProducts`, `usp_CreateOrder`); Dapper's job
is just to invoke them and shape the results, which keeps the C# layer thin.

### 44. How does Dapper prevent SQL injection?
By always using parameterized queries — you pass parameter values as a separate object/dictionary,
and Dapper (via `SqlCommand.Parameters`) sends them to SQL Server independently of the SQL
text, so user input is never concatenated into the query string and can't be interpreted as
SQL syntax.

```csharp
return await connection.QueryFirstOrDefaultAsync<ProductDto>(
    "dbo.usp_GetProductById",
    new { Id = id },                          // safely parameterized, not string-concatenated
    commandType: CommandType.StoredProcedure);
```

### 45. What is a Table-Valued Parameter from the C# side, and how does `AsTableValuedParameter` work?
A TVP lets you pass an entire set of rows to SQL Server as a single strongly-typed parameter,
matching a user-defined table type on the server (`dbo.OrderItemTableType`). On the C# side,
`OrderRepository` builds an in-memory `DataTable` whose columns match the SQL type's columns,
then calls `.AsTableValuedParameter("dbo.OrderItemTableType")` to wrap it as a Dapper-compatible
parameter — this sends the whole cart in one round trip instead of looping over items.

```csharp
var itemsTable = new DataTable();
itemsTable.Columns.Add("ProductId", typeof(int));
itemsTable.Columns.Add("Quantity", typeof(int));
foreach (var item in items)
    itemsTable.Rows.Add(item.ProductId, item.Quantity);

var parameters = new DynamicParameters();
parameters.Add("@Items", itemsTable.AsTableValuedParameter("dbo.OrderItemTableType"));
```

### 46. What is `DynamicParameters` in Dapper, and when do you need it?
`DynamicParameters` is a builder for a parameter set that you assemble programmatically
(rather than passing a single anonymous object), useful when a parameter needs special
handling — like a TVP, an output parameter, or an explicit `DbType`/size — that an anonymous
object can't express. `OrderRepository` uses it because a `DataTable`-backed TVP can't be
passed as a plain anonymous-object property.

### 47. What's the difference between `QueryAsync`, `QueryFirstOrDefaultAsync`, and `QuerySingleAsync`?
- `QueryAsync<T>` returns all matching rows as `IEnumerable<T>` (used by `GetProductsAsync`).
- `QueryFirstOrDefaultAsync<T>` returns the first row, or `default(T)` (`null` for a reference
  type) if there are none — used by `GetProductByIdAsync` so a missing product yields `null`
  rather than throwing.
- `QuerySingleAsync<T>` requires *exactly one* row and throws if there are zero or more than
  one — useful when "not exactly one" itself signals a bug.

### 48. What does `QueryMultipleAsync` do, and why does `CreateOrderAsync` use it?
`QueryMultipleAsync` executes a command that returns several result sets in one round trip and
lets you read each with `ReadAsync<T>`/`ReadSingleAsync<T>` in order. `usp_CreateOrder` returns
two result sets — the order header, then its line items — so Dapper reads them sequentially
into one combined `OrderResponse`:

```csharp
using var multi = await connection.QueryMultipleAsync("dbo.usp_CreateOrder", parameters,
    commandType: CommandType.StoredProcedure);

var order = await multi.ReadSingleAsync<OrderResponse>();       // first result set
order.Items = (await multi.ReadAsync<OrderItemResponse>()).ToList(); // second result set
```

### 49. What are boxing and unboxing, and why do they matter for performance?
Boxing wraps a value type in a heap-allocated object (implicitly, when a value type is used
where `object` is expected); unboxing extracts it back out. Both incur allocation and copying
overhead, and unboxing to the wrong type throws `InvalidCastException`. It's most relevant when
using non-generic collections (`ArrayList`) or `object`-typed APIs; generic collections/methods
like `List<int>` or `Task<IEnumerable<ProductDto>>` avoid boxing entirely because the type is
known at compile time.

### 50. What's the difference between `==` and `.Equals()` in C#?
For reference types, `==` by default compares references (identity) unless the type overloads
the `==` operator; `.Equals()` is virtual and can be overridden for value-based comparison —
`string` overrides both, so `==` and `.Equals()` both compare content for strings. For value
types (structs), `==` isn't defined by default unless the type provides it, while `.Equals()`
(inherited from `ValueType`) does a reflection-based field comparison. `record` types generate
both to compare by value automatically, unlike a plain `class` where `==`/`Equals` default to
reference identity.

---

## SQL Server Interview Questions (50)

### 1. What is SQL Server, and what does T-SQL add on top of standard SQL?
SQL Server is Microsoft's relational database management system. T-SQL (Transact-SQL) is its
SQL dialect, extending standard SQL with procedural constructs (`IF`, `WHILE`, variables),
error handling (`TRY`/`CATCH`, `THROW`), stored procedures, and SQL Server-specific functions
(`SYSUTCDATETIME()`, `SCOPE_IDENTITY()`). Every script in [`Database/`](Database) is T-SQL.

### 2. DDL vs. DML vs. DCL — give examples from this project's scripts.
- **DDL** (Data Definition Language) defines structure: `CREATE TABLE`, `CREATE TYPE`,
  `CREATE INDEX`, `DROP TABLE` — all of [`02-schema.sql`](Database/02-schema.sql).
- **DML** (Data Manipulation Language) manipulates data: `SELECT`, `INSERT`, `UPDATE`,
  `MERGE` — the body of `usp_CreateOrder` and all of [`04-seed.sql`](Database/04-seed.sql).
- **DCL** (Data Control Language) manages permissions: `GRANT`, `REVOKE`, `DENY` — not used in
  this project, but would appear for controlling who can execute the stored procedures.

### 3. What's the difference between `CHAR`, `VARCHAR`, and `NVARCHAR`? Why does the schema use `NVARCHAR`?
`CHAR(n)` is fixed-length (padded with spaces); `VARCHAR(n)` is variable-length but only stores
single-byte (non-Unicode) characters; `NVARCHAR(n)` is variable-length and stores Unicode
(2 bytes/char), able to represent any language's characters. `02-schema.sql` uses `NVARCHAR`
for every text column (`Name`, `Category`, `Description`, etc.) so product names/descriptions
can safely contain any Unicode text, at roughly double the storage cost per character versus
`VARCHAR`.

### 4. What's a `PRIMARY KEY`, and how is it defined on `Products.Id`?
A primary key uniquely identifies each row in a table; it's implicitly `NOT NULL` and unique,
and SQL Server creates a unique clustered index for it by default (unless you specify
non-clustered). `Products.Id INT NOT NULL PRIMARY KEY` — note it's *not* `IDENTITY` here,
because product IDs are assigned explicitly by the seed script rather than auto-generated.

### 5. What's a `FOREIGN KEY`, and what does `ON DELETE CASCADE` do?
A foreign key enforces referential integrity — a value in the child column must exist in the
referenced parent table's key column. `OrderItems.OrderId` references `Orders.Id` with
`ON DELETE CASCADE`: deleting an `Orders` row automatically deletes its related `OrderItems`
rows too, so you can never be left with orphaned line items.

```sql
OrderId INT NOT NULL CONSTRAINT FK_OrderItems_Orders REFERENCES dbo.Orders(Id) ON DELETE CASCADE,
ProductId INT NOT NULL CONSTRAINT FK_OrderItems_Products REFERENCES dbo.Products(Id) -- no cascade: products aren't deleted this way
```

### 6. What's a `CHECK` constraint? What do `CK_Products_Price`/`CK_Products_Category` enforce?
A `CHECK` constraint enforces a boolean condition on every row, rejecting any `INSERT`/`UPDATE`
that violates it. `CK_Products_Price` requires `Price >= 0`; `CK_Products_Category` restricts
`Category` to one of four allowed values (`Audio`, `Home`, `Desk`, `Wellness`) — effectively an
enum enforced at the database layer, without needing a separate lookup table.

```sql
Category NVARCHAR(30) NOT NULL
    CONSTRAINT CK_Products_Category CHECK (Category IN (N'Audio', N'Home', N'Desk', N'Wellness')),
Price DECIMAL(10, 2) NOT NULL CONSTRAINT CK_Products_Price CHECK (Price >= 0),
```

### 7. What's a `DEFAULT` constraint?
It supplies a value automatically when a column is omitted from an `INSERT`. `Products.CreatedAt`
and `Orders.CreatedAt` both default to `SYSUTCDATETIME()`, so every insert automatically gets a
UTC timestamp without the application having to supply "now" itself.

```sql
CreatedAt DATETIME2 NOT NULL CONSTRAINT DF_Products_CreatedAt DEFAULT SYSUTCDATETIME()
```

### 8. What is `IDENTITY`, and how does `IDENTITY(1, 1)` work on `Orders.Id`?
`IDENTITY(seed, increment)` makes SQL Server auto-generate sequential values for a column on
insert — `IDENTITY(1, 1)` starts at 1 and increases by 1 each row. `Orders.Id` and
`OrderItems.Id` both use it so the database, not the application, is the single source of
truth for order/line numbering — unlike `Products.Id`, which is supplied explicitly.

### 9. What is `SCOPE_IDENTITY()`, and why prefer it over `@@IDENTITY`?
`SCOPE_IDENTITY()` returns the last identity value generated in the *current session and
current scope* (e.g., this stored procedure or batch); `@@IDENTITY` returns the last identity
value generated in the current session *regardless of scope*, which can return the wrong value
if a trigger on the table also inserts into another identity-having table. `usp_CreateOrder`
uses the safer `SCOPE_IDENTITY()` right after inserting into `Orders` to reliably capture the
new order's ID:

```sql
INSERT INTO dbo.Orders (Subtotal) VALUES (@Subtotal);
SET @OrderId = SCOPE_IDENTITY();
```

### 10. What is a computed column, and what does `PERSISTED` mean?
A computed column's value is derived from an expression over other columns in the same row
rather than being stored directly by an `INSERT`/`UPDATE`. By default it's computed on every
read; marking it `PERSISTED` tells SQL Server to physically store the computed value and
recompute it only when a dependent column changes — trading a little storage for faster reads
and the ability to index the column. `Orders.OrderNumber` and `OrderItems.LineTotal` are both
persisted computed columns.

```sql
OrderNumber AS (N'FK-' + RIGHT(N'000000' + CAST(Id AS VARCHAR(6)), 6)) PERSISTED,
...
LineTotal AS (UnitPrice * Quantity) PERSISTED
```

### 11. What's the difference between a persisted and non-persisted computed column?
Non-persisted: recalculated on every `SELECT` that references it, costs no storage, but can't
be used in certain contexts (e.g., some index scenarios) without extra requirements. Persisted:
physically stored like a regular column, automatically kept in sync, can be indexed directly,
and read performance is essentially identical to a regular column. `LineTotal` is persisted
precisely because `usp_CreateOrder`'s final `SELECT` reads it back immediately — recomputing
`UnitPrice * Quantity` per read would be cheap here, but persisting keeps the derived value
consistent with the stored inputs by construction.

### 12. What is an index, and why was `IX_Products_Category` created?
An index is a separate data structure (typically a B-tree) that lets SQL Server locate rows
matching a predicate without scanning the whole table, at the cost of extra storage and slightly
slower writes (the index must be maintained). `IX_Products_Category` speeds up any query that
filters or sorts by `Category` — e.g., a future "browse by category" endpoint — turning what
would be a full table scan into an index seek.

```sql
CREATE INDEX IX_Products_Category ON dbo.Products(Category);
```

### 13. Clustered vs. non-clustered index — which is the primary key by default?
A clustered index determines the *physical order* rows are stored in on disk — a table can
have only one. A non-clustered index is a separate structure with pointers back to the data
rows — a table can have many. By default, `PRIMARY KEY` creates a *clustered* index (so
`Products.Id`'s primary key physically orders the table by `Id`), while
`CREATE INDEX IX_Products_Category` creates a non-clustered index alongside it.

### 14. What is a stored procedure, and why does this project use them exclusively?
A stored procedure is a named, precompiled batch of T-SQL stored in the database, callable
with parameters and capable of returning one or more result sets. This project puts all data
access — even simple reads like `usp_GetProducts` — behind stored procedures so that: SQL is
centralized and reviewable in one place, execution plans can be cached and reused, and
business rules (like order validation/pricing) are guaranteed to run consistently regardless
of which application calls them, rather than being duplicated in every client.

### 15. What does `SET NOCOUNT ON` do, and why is it in every procedure here?
By default, SQL Server sends a "N rows affected" message after each DML statement. `SET
NOCOUNT ON` suppresses those messages, reducing network chatter and — more importantly for
Dapper/ADO.NET — preventing those extra "done" messages from interfering with reading the
actual result set(s) you asked for. It's standard practice to put it at the top of essentially
every stored procedure.

### 16. What is a Table-Valued Parameter (TVP)? Explain `dbo.OrderItemTableType`.
A TVP is a user-defined table type that a stored procedure can accept as a single parameter,
letting you pass a whole set of rows in one call instead of one scalar value per call.
`OrderItemTableType` defines the shape of a cart line (`ProductId`, `Quantity`); `usp_CreateOrder`
declares `@Items dbo.OrderItemTableType READONLY` and can then `JOIN`/`SELECT` against it just
like a regular table.

```sql
CREATE TYPE dbo.OrderItemTableType AS TABLE
(
    ProductId INT NOT NULL,
    Quantity  INT NOT NULL
);
```

### 17. Why use a TVP instead of a comma-separated string or calling the procedure in a loop?
A comma-separated string requires fragile, injection-prone string-splitting logic inside the
procedure; calling the procedure once per cart item means N separate round trips and N separate
transactions, making it impossible to validate/price/commit the whole order atomically. A TVP
sends the entire cart in a single strongly-typed round trip, so `usp_CreateOrder` can validate
stock and compute the subtotal for *all* lines together inside one transaction.

### 18. What does `READONLY` mean for a TVP parameter?
TVP parameters must be declared `READONLY` — you cannot `UPDATE`, `DELETE`, or `INSERT` into
the TVP itself inside the procedure (only read/join against it). This is a SQL Server
requirement, not just a style choice: `@Items dbo.OrderItemTableType READONLY` would fail to
compile without `READONLY`.

### 19. What is a transaction, and what do the ACID properties mean?
A transaction is a unit of work that's either fully applied or fully undone. **ACID**:
**Atomicity** (all-or-nothing), **Consistency** (moves the database from one valid state to
another, respecting constraints), **Isolation** (concurrent transactions don't see each
other's uncommitted changes), **Durability** (once committed, changes survive a crash).
`usp_CreateOrder` needs atomicity in particular: inserting the order, inserting its items, and
decrementing stock must either all happen or none happen.

### 20. Explain `BEGIN TRANSACTION` / `COMMIT TRANSACTION` / `ROLLBACK TRANSACTION` in `usp_CreateOrder`.
`BEGIN TRANSACTION` starts an explicit transaction; `COMMIT TRANSACTION` makes all its changes
permanent; `ROLLBACK TRANSACTION` undoes everything since `BEGIN`. In `usp_CreateOrder`, if the
stock check inside the transaction fails, it explicitly rolls back before throwing, so no
partial order/stock changes are ever left behind:

```sql
BEGIN TRANSACTION;
IF EXISTS (SELECT 1 FROM @Items i JOIN dbo.Products p WITH (UPDLOCK, ROWLOCK) ON p.Id = i.ProductId WHERE p.Stock < i.Quantity)
BEGIN
    ROLLBACK TRANSACTION;
    THROW 50004, 'One or more products do not have enough stock.', 1;
END
-- ... inserts and stock update ...
COMMIT TRANSACTION;
```

### 21. What does `SET XACT_ABORT ON` do, and why is it important here?
Normally, a runtime error inside a transaction doesn't automatically roll it back — the
transaction can be left open and uncommittable ("doomed") unless you handle it explicitly.
`SET XACT_ABORT ON` makes any runtime error automatically roll back the entire transaction and
terminate the batch. `usp_CreateOrder` sets it at the top precisely because it doesn't wrap the
transaction body in `TRY`/`CATCH` — `XACT_ABORT` is what guarantees an unexpected error (e.g.,
a constraint violation) still leaves the database in a clean, non-doomed state.

### 22. What is `THROW`, and how does it differ from `RAISERROR`?
`THROW` (SQL Server 2012+) raises an error, immediately halting execution (unless caught by
`TRY`/`CATCH`) and propagating the message/severity/state to the caller; used with no arguments
inside a `CATCH` block, it re-throws the original error unmodified. `RAISERROR` is the older
mechanism with more complex formatting rules and, critically, does *not* by default set
`XACT_ABORT`-style unconditional rollback behavior. `usp_CreateOrder` uses `THROW <number>, <message>, <state>`
for each validation failure, e.g. `THROW 50001, 'Order must contain at least one item.', 1;`.

### 23. Why does `usp_CreateOrder` use custom error numbers 50001–50004, and how does C# interpret them?
User-defined error numbers must be ≥ 50000 (numbers below that are reserved for SQL Server's
own system errors). Each validation rule gets a distinct number (empty cart, bad quantity,
unknown product, insufficient stock) so the caller can distinguish *which* validation failed if
needed. On the C# side, `OrderRepository` catches any `SqlException` whose `Number` falls in
`[50000, 51000)` and rewraps it as an `OrderValidationException`, which `OrdersController`
turns into a 400 Bad Request — any other SQL error number (a real infrastructure/data problem)
is left to propagate as an unhandled 500 instead.

### 24. What is a locking hint, and what do `WITH (UPDLOCK, ROWLOCK)` do?
A locking hint overrides SQL Server's default locking behavior for a specific table reference
in a query. `UPDLOCK` takes an update lock (rather than a shared lock) on the rows it reads,
preventing another transaction from also taking an update/exclusive lock on the same rows until
this transaction finishes; `ROWLOCK` requests row-level (rather than page/table-level) locking
granularity to minimize contention with unrelated rows.

```sql
JOIN dbo.Products p WITH (UPDLOCK, ROWLOCK) ON p.Id = i.ProductId
WHERE p.Stock < i.Quantity
```

### 25. What race condition does `UPDLOCK` prevent in the stock-check query?
Without `UPDLOCK`, two concurrent orders for the same product could both read `Stock = 1`
(under a plain shared lock, both reads succeed since shared locks don't block other shared
locks), both conclude "enough stock," and both proceed to decrement — a classic **lost update**
that results in overselling. `UPDLOCK` ensures the *first* transaction to read a product row
for the stock check holds a lock that blocks a second transaction's `UPDLOCK` read on the same
row until the first transaction commits or rolls back, so the second transaction sees the
already-decremented stock.

### 26. What is deadlocking, and how do locking hints/short transactions reduce the risk?
A deadlock happens when two transactions each hold a lock the other needs, so neither can
proceed — SQL Server detects this and kills one transaction (the "deadlock victim") to break
the cycle. Risk is reduced by keeping transactions short (less time holding locks), accessing
tables/rows in a consistent order across all procedures, and using precise locking hints
(`ROWLOCK`) to avoid unnecessarily broad locks. `usp_CreateOrder` keeps its transaction tight —
validation happens *before* `BEGIN TRANSACTION` wherever possible, minimizing time spent
holding locks.

### 27. What are SQL Server's transaction isolation levels?
From least to most isolated: **Read Uncommitted** (dirty reads allowed), **Read Committed**
(the default — never reads uncommitted data, but non-repeatable reads/phantoms possible),
**Repeatable Read** (locks read rows so they can't change until commit, but phantom rows can
still appear), **Serializable** (fully isolated, as if transactions ran one at a time — most
locking/blocking), and **Snapshot** (row-versioning-based, no read locks, but write conflicts
detected at commit). `usp_CreateOrder` runs under the default Read Committed isolation but
compensates with explicit `UPDLOCK` hints rather than raising the isolation level for the whole
transaction.

### 28. INNER JOIN vs. LEFT JOIN — explain the existence check in `usp_CreateOrder`.
`INNER JOIN` returns only rows with a match in both tables; `LEFT JOIN` returns every row from
the left table, with `NULL`s for any unmatched right-table columns. To detect cart items whose
`ProductId` doesn't exist, `usp_CreateOrder` uses a `LEFT JOIN` and checks for `NULL`:

```sql
IF EXISTS (
    SELECT 1 FROM @Items i
    LEFT JOIN dbo.Products p ON p.Id = i.ProductId
    WHERE p.Id IS NULL
)
BEGIN
    THROW 50003, 'One or more products do not exist.', 1;
END
```

### 29. Why use `LEFT JOIN ... WHERE p.Id IS NULL` instead of `NOT IN`?
`NOT IN` against a subquery silently returns **no rows at all** (not an error, and not "all
rows") if the subquery result contains even a single `NULL` — a well-known correctness trap.
`LEFT JOIN`/`IS NULL` (an "anti-join" pattern) has no such `NULL` pitfall and is also typically
optimized better by the query planner than a correlated `NOT IN` subquery.

### 30. What is `EXISTS`, and why is `IF EXISTS (SELECT 1 FROM ...)` preferred over `COUNT(*) > 0`?
`EXISTS` returns `true` as soon as the subquery produces at least one row, without needing to
count or materialize all matches — SQL Server can short-circuit on the first hit. `COUNT(*) > 0`
forces scanning/counting every matching row even though only "at least one" matters. Every
validation check in `usp_CreateOrder` uses `IF EXISTS (SELECT 1 FROM ...)` for this reason —
`SELECT 1` (rather than `SELECT *`) is a convention signaling "we only care about row
existence, not any particular column."

### 31. What is `MERGE`, and how does `04-seed.sql` use it to make seeding idempotent?
`MERGE` compares a target table against a source row set and lets you specify different
actions for matched vs. unmatched rows in one statement — effectively an "upsert." `04-seed.sql`
merges a `VALUES` list of six products into `dbo.Products`: existing rows (matched by `Id`) are
updated to match the seed data exactly, and missing rows are inserted — so the script can be
re-run any number of times without erroring or duplicating rows.

### 32. What are the risks of `MERGE`, and what alternatives exist?
`MERGE` has had documented edge-case bugs around concurrency (race conditions between the
match check and the action) and can produce surprising behavior with triggers or when the
`ON` clause matches multiple source rows to one target row. A simpler and often safer
alternative for a single-row upsert is an explicit `IF EXISTS (...) UPDATE ... ELSE INSERT ...`,
which is exactly the pattern `usp_CreateOrder` uses for its own existence checks, just applied
to an upsert rather than a validation. For a small, static, script-driven seed like this one,
`MERGE` is a reasonable, low-risk fit.

### 33. What do `WHEN MATCHED` and `WHEN NOT MATCHED BY TARGET` mean in `04-seed.sql`'s `MERGE`?
`WHEN MATCHED` fires when a source row's key matches an existing target row — here, it
`UPDATE`s every column to the seed value. `WHEN NOT MATCHED BY TARGET` fires when a source row
has no corresponding target row — here, it `INSERT`s a new row. (A third clause,
`WHEN NOT MATCHED BY SOURCE`, would fire for target rows with no matching source row — not used
here, since the seed never deletes products.)

```sql
MERGE dbo.Products AS target
USING (VALUES (1, N'Moss Ceramic Speaker', ...)) AS source (Id, Name, ...)
ON target.Id = source.Id
WHEN MATCHED THEN UPDATE SET Name = source.Name, ...
WHEN NOT MATCHED BY TARGET THEN INSERT (Id, Name, ...) VALUES (source.Id, source.Name, ...);
```

### 34. What is a user-defined table type (UDT), and how is `dbo.OrderItemTableType` created?
A user-defined table type is a reusable, named schema for a table shape that can be used to
declare TVP parameters. It's created with `CREATE TYPE ... AS TABLE (...)`, listing columns
just like a regular table definition (constraints and even a primary key are allowed, though
this one keeps it minimal — just two `NOT NULL` columns).

### 35. What do `DB_ID()`/`OBJECT_ID()` do, and why does `02-schema.sql` guard drops with them?
`DB_ID('name')` returns a database's internal ID (or `NULL` if it doesn't exist);
`OBJECT_ID('schema.name', 'U')` returns an object's ID if it exists as the given type
(`'U'` = user table) or `NULL` otherwise. Guarding `DROP TABLE` with
`IF OBJECT_ID(N'dbo.Products', N'U') IS NOT NULL` makes the script safely re-runnable — dropping
a table that doesn't exist yet would otherwise throw an error and halt the script.

```sql
IF OBJECT_ID(N'dbo.OrderItems', N'U') IS NOT NULL
    DROP TABLE dbo.OrderItems;
```

### 36. What is `TYPE_ID()`, and why is it checked before `DROP TYPE`?
`TYPE_ID('name')` returns a type's internal ID if it exists, or `NULL` otherwise — the type
analog of `OBJECT_ID`. `02-schema.sql` checks `TYPE_ID(N'dbo.OrderItemTableType') IS NOT NULL`
before dropping it, for the same idempotency reason as the table drops: a fresh database
wouldn't have the type yet, and an unguarded `DROP TYPE` would error out.

### 37. What does `CREATE OR ALTER PROCEDURE` do, and why not `DROP` then `CREATE`?
`CREATE OR ALTER` (SQL Server 2016 SP1+) creates the procedure if it doesn't exist, or replaces
its definition in place if it does — in a single statement, atomically, and without needing to
first drop it (which would also transiently drop any permissions granted on it). All three
procedures in [`03-stored-procedures.sql`](Database/03-stored-procedures.sql) use it, making the
script safely re-runnable to deploy updated procedure logic.

### 38. What is `GO`, and why is it used between statements in these scripts?
`GO` is not T-SQL itself — it's a batch separator recognized by client tools (SSMS, `sqlcmd`),
telling the tool to send everything since the last `GO` to the server as one batch. Some
statements (like `CREATE PROCEDURE`) must be the first/only statement in their batch, and
`USE` needs its own batch to take effect for subsequent statements — hence `GO` after nearly
every statement in these scripts.

### 39. What does `USE FlipkartDB;` do, and why does each script start with it?
`USE` switches the current session's database context so subsequent unqualified object
references resolve against that database. Each script after `01-create-database.sql` opens
with `USE FlipkartDB; GO` to guarantee it operates against the right database regardless of
what database the connection/tool happened to default to.

### 40. What is `DECIMAL(10, 2)`, and why is money stored as `DECIMAL` rather than `FLOAT`?
`DECIMAL(precision, scale)` stores an exact fixed-point number — `DECIMAL(10, 2)` allows up to
10 total digits, 2 after the decimal point, e.g. `12345678.90`. `FLOAT`/`REAL` are
floating-point and can introduce small rounding errors that are unacceptable for currency
(`0.1 + 0.2` not exactly equaling `0.3` in binary floating point is the classic example).
`Price`, `Subtotal`, `UnitPrice`, and `LineTotal` are all `DECIMAL(10, 2)` for exact,
predictable arithmetic.

### 41. What is `DATETIME2`, and why is it preferred over `DATETIME`?
`DATETIME2` has a larger date range, higher fractional-second precision (up to 100ns vs.
~3ms), and is generally more storage-efficient than the legacy `DATETIME` type — it's
Microsoft's recommended type for new development. `CreatedAt` on both `Products` and `Orders`
uses `DATETIME2`.

### 42. What does `SYSUTCDATETIME()` do, and why store UTC instead of local time?
`SYSUTCDATETIME()` returns the current UTC date/time with high precision. Storing timestamps in
UTC avoids ambiguity and bugs from time zones/daylight saving changes — the API server, the
database server, and clients could all be in different time zones, but a UTC timestamp means
exactly one unambiguous instant regardless of where it's read. Any local-time display is then a
presentation-layer conversion, not a storage decision.

### 43. What is normalization, and how do `Products`, `Orders`, `OrderItems` reflect 3NF?
Normalization organizes data to minimize redundancy and avoid update anomalies, typically by
ensuring every non-key column depends only on the whole primary key (3NF: no transitive
dependencies on non-key columns). Splitting the schema into `Products` (catalog),
`Orders` (order headers), and `OrderItems` (line items, one row per product per order) avoids,
e.g., repeating a product's full description on every order line — `OrderItems` only stores a
foreign key plus the order-specific facts (quantity, and the price/name *at the time of
purchase*).

### 44. Why does `OrderItems` store `ProductName`/`UnitPrice` redundantly instead of just joining to `Products`?
This is intentional, deliberate denormalization for historical accuracy: a product's name or
price can change after an order is placed (or the product could later be deleted/renumbered),
but the order's record of what was actually purchased and at what price must stay fixed forever.
`usp_CreateOrder` copies `ProductName`/`Price` into `OrderItems` at order-creation time
precisely so a historical order's total can never silently change if the catalog changes later.

### 45. What's the difference between `DELETE` and `TRUNCATE`?
`DELETE` removes rows one at a time (optionally filtered by `WHERE`), is fully logged (so it's
rollback-able mid-transaction and fires triggers), and doesn't reset an `IDENTITY` seed.
`TRUNCATE TABLE` deallocates entire data pages at once (unconditionally, no `WHERE`), is
minimally logged, is much faster on large tables, and resets any `IDENTITY` seed back to its
original value. `TRUNCATE` is also blocked by an active foreign key relationship in some cases,
so `OrderItems`/`Orders` (linked by `FK_OrderItems_Orders`) would need care about deletion
order if truncating.

### 46. How is `@Subtotal` calculated in `usp_CreateOrder`?
By joining the TVP against `Products` to get each line's current price, multiplying by
quantity, and aggregating with `SUM()` — computed entirely from the *current* database price,
never trusting a client-supplied total:

```sql
DECLARE @Subtotal DECIMAL(10, 2);
SELECT @Subtotal = SUM(p.Price * i.Quantity)
FROM @Items i
JOIN dbo.Products p ON p.Id = i.ProductId;
```
This assignment form (`SELECT @variable = expression`) is a common T-SQL pattern for pulling an
aggregate straight into a variable without a separate result set.

### 47. Subquery vs. JOIN — when would you use each?
A `JOIN` combines rows from two (or more) tables into a single result set based on a
relationship, and is generally what you want when you need columns from both tables. A
subquery is a query nested inside another, often used for existence checks (`EXISTS`/`IN`) or
to compute a single scalar value used elsewhere. `usp_CreateOrder`'s existence/stock checks use
correlated joins inside `EXISTS`, while the subtotal calculation uses a `JOIN` because it needs
both the quantity (from `@Items`) and the price (from `Products`) together.

### 48. What is SQL injection, and how do parameterized stored procedure calls prevent it?
SQL injection is an attack where untrusted input is concatenated directly into SQL text,
letting an attacker inject their own SQL logic (e.g., `'; DROP TABLE Products; --`). Because
this project always calls stored procedures with parameters (via Dapper's anonymous objects or
`DynamicParameters`, never string concatenation), user input is transmitted as data, never as
part of the SQL text itself, so it can never be interpreted as executable SQL regardless of its
content.

### 49. Scalar function vs. stored procedure vs. table-valued function — what's the difference?
A **scalar function** returns a single value and can be used inline in a `SELECT`/`WHERE`
expression, but (in SQL Server, pre-"scalar UDF inlining" improvements) is historically
expensive if invoked per-row. A **stored procedure** can return multiple result sets, use
transactions (`BEGIN TRAN`/`COMMIT`), and have output parameters, but can't be used inline
inside a `SELECT`. A **table-valued function** returns a table and *can* be used inline (e.g.,
`FROM dbo.SomeFunction(...)`) like a view with parameters. This project uses stored procedures
exclusively because it needs multiple result sets (`usp_CreateOrder`) and transactional control
— neither of which a function can provide.

### 50. How would you troubleshoot a slow stored procedure?
Start by capturing its **actual execution plan** (not estimated) to see where time/rows go —
look for table scans where an index seek was expected, missing index suggestions, or a
significant estimated-vs-actual row-count mismatch (often a sign of stale statistics — fixable
with `UPDATE STATISTICS`). Check for parameter sniffing (a cached plan optimized for one
parameter value performing badly for another), missing indexes on join/filter columns (e.g., if
`OrderItems.ProductId` had no supporting index, the `usp_CreateOrder` joins against `Products`
would degrade as `OrderItems` grows), and blocking/lock contention via
`sys.dm_exec_requests`/`sys.dm_tran_locks`. Tools: `SET STATISTICS IO, TIME ON`, the
"Include Actual Execution Plan" option in SSMS, and Extended Events/Query Store for
production diagnosis over time.
