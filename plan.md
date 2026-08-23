## Plan: Mini Catalog Shopping Cart

Build a greenfield Angular SPA and ASP.NET Core Web API backed by SQL Server. Use JWT bearer authentication, parameterized SQL/stored procedures through a small repository layer, and a client-side cart whose checkout is validated and persisted by the API.

**Steps**
1. **Scaffold and configure the workspace**
   - Create the Angular application in `/Users/sakshamojha/Codes/Flipkart/UI` using standalone components, routing, reactive forms, and an environment-based API URL.
   - Create the ASP.NET Core Web API in `/Users/sakshamojha/Codes/Flipkart/API` using the current supported .NET LTS, controllers, configuration, dependency injection, and CORS for the Angular development origin.
   - Add a solution file and a root README covering prerequisites, SQL Server connection setup, API/UI startup commands, and test credentials or seed behavior.

2. **Define the SQL Server schema and seed data**
   - Add `/Users/sakshamojha/Codes/Flipkart/API/Database/schema.sql` defining `Users`, `Products`, `Orders`, and `OrderItems` with primary/foreign keys, unique user email, nonnegative product price/stock constraints, order status, timestamps, and useful indexes.
   - Add `/Users/sakshamojha/Codes/Flipkart/API/Database/stored-procedures.sql` for user lookup/insert, product listing/detail lookup, and transactional order creation support. All inputs must be parameterized; the order procedure must use current database product prices rather than trusting client prices.
   - Add `/Users/sakshamojha/Codes/Flipkart/API/Database/seed.sql` with a small deterministic product catalog. Keep database setup scripts idempotent where practical.

3. **Implement API foundations**
   - Add configuration models for SQL Server and JWT settings, with secrets read from user secrets or environment variables rather than committed files.
   - Add domain/DTO types under `/Users/sakshamojha/Codes/Flipkart/API/Models` for registration, login, user identity, product responses, cart line input, and order responses.
   - Add a Dapper-based or equivalent ADO.NET repository layer under `/Users/sakshamojha/Codes/Flipkart/API/Data` that calls the stored procedures, maps results, and keeps SQL out of controllers.
   - Add password hashing using the ASP.NET Core password hasher, JWT issuance with user ID/email claims, validation configuration, global exception handling, request validation, and consistent error responses.

4. **Implement API endpoints**
   - Add an authentication controller with `POST /api/auth/register` and `POST /api/auth/login`; normalize email, reject duplicates, never return password data, and return a token plus basic user information.
   - Add a products controller with `GET /api/products` and optional `GET /api/products/{id}`; return only active products and support basic search/filtering only if it stays small and well-tested.
   - Add an orders controller with authenticated `POST /api/orders`; validate non-empty items, positive quantities, product existence, and stock, then create the order and order items in one SQL transaction and return the order summary.
   - Keep payment processing, shipping, admin product management, persistent carts, and order history out of this first release.

5. **Build Angular application shell and authentication**
   - Add routes for registration, login, products, cart, and checkout under `/Users/sakshamojha/Codes/Flipkart/UI/src/app`.
   - Create typed API services for auth, products, and orders; an auth state service backed by session/local storage; an HTTP interceptor for the bearer token; and route guards for checkout/authenticated routes.
   - Build registration and login components with reactive forms, field-level validation, loading states, API error display, logout, and redirect behavior.

6. **Build catalog, cart, and checkout flows**
   - Create product list/card components that show image placeholder or product image, name, description, price, availability, and add-to-cart behavior.
   - Create a cart service using an observable state model and local storage persistence. Support quantity changes, removal, empty-cart state, subtotal calculation, and stock-aware quantity limits.
   - Create checkout UI that requires authentication, summarizes items, submits only product IDs and quantities, disables duplicate submission, handles API failures, clears the cart after success, and shows the created order number/total.
   - Apply a small responsive layout with accessible labels, keyboard-friendly controls, and clear loading/empty/error/success states.

7. **Add focused automated tests and integration checks**
   - API unit tests for password/auth behavior, duplicate registration, JWT claims, input validation, and order total/stock rules.
   - API integration tests for registration, login, product retrieval, unauthorized order creation, and successful/invalid checkout. Use a test database strategy that does not affect the developer database.
   - Angular tests for auth form validation, interceptor/guard behavior, product loading, cart quantity/subtotal logic, and checkout success/failure handling.

8. **Document and verify local execution**
   - Document SQL Server database creation and script order, connection string/JWT configuration, API migration-free setup, CORS origin, and commands to run API and UI.
   - Verify the happy path manually: register, log in, browse seeded products, add/update/remove cart items, checkout, and confirm the order in SQL Server.
   - Verify negative paths: duplicate email, invalid login, expired/missing token, empty cart, invalid quantity, out-of-stock item, and database/API failure presentation.

**Relevant files**
- `/Users/sakshamojha/Codes/Flipkart/API/Program.cs` — service registration, JWT, CORS, controllers, exception handling, and configuration binding.
- `/Users/sakshamojha/Codes/Flipkart/API/Controllers/AuthController.cs` — registration and login HTTP contract.
- `/Users/sakshamojha/Codes/Flipkart/API/Controllers/ProductsController.cs` — catalog retrieval.
- `/Users/sakshamojha/Codes/Flipkart/API/Controllers/OrdersController.cs` — authenticated checkout orchestration.
- `/Users/sakshamojha/Codes/Flipkart/API/Data/*` — connection factory, repositories, and stored-procedure calls.
- `/Users/sakshamojha/Codes/Flipkart/API/Database/schema.sql`, `stored-procedures.sql`, `seed.sql` — database contract and initial catalog.
- `/Users/sakshamojha/Codes/Flipkart/UI/src/app/*` — routes, services, guards/interceptor, models, and standalone components.
- `/Users/sakshamojha/Codes/Flipkart/README.md` — setup, configuration, runbook, and scope.

**Verification**
1. Build and test the API with the repository's chosen .NET commands; run the focused API unit/integration test projects against an isolated SQL Server database.
2. Run Angular unit tests and a production build to catch template, typing, routing, and configuration errors.
3. Exercise the documented end-to-end flow locally with SQL Server running and confirm that order totals are calculated from database prices.
4. Inspect API responses to ensure passwords and sensitive configuration are never returned or committed.

**Decisions**
- Greenfield workspace: both `API` and `UI` are currently empty.
- Authentication: JWT bearer tokens.
- Database access: raw SQL/stored procedures via a repository abstraction; no EF Core migrations.
- Cart: client-side state persisted in browser storage; the API receives checkout lines and owns final pricing/stock validation.
- First release scope: core catalog, registration/login, cart, and checkout only.
- Explicitly excluded: payment gateway, shipping address/payment details, admin product management, persistent server-side cart, order history, refresh-token rotation, and production deployment.

**Further Considerations**
1. For production, replace browser storage for long-lived tokens with a stronger token lifecycle and add refresh-token rotation or a BFF pattern.
2. Add rate limiting, email verification, audit logging, and stricter inventory reservation before exposing checkout publicly.
3. Add an image storage/CDN strategy once the product catalog needs real media rather than seeded image URLs/placeholders.
