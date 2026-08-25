using System.Data;
using Dapper;
using Microsoft.Data.SqlClient;
using API.Models;

namespace API.Data;

public interface IOrderRepository
{
    Task<OrderResponse> CreateOrderAsync(IEnumerable<CreateOrderItemRequest> items);
}

/// <summary>Raised when dbo.usp_CreateOrder rejects the order (empty cart, bad quantity, unknown product, insufficient stock).</summary>
public class OrderValidationException : Exception
{
    public OrderValidationException(string message) : base(message)
    {
    }
}

public class OrderRepository : IOrderRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public OrderRepository(IDbConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<OrderResponse> CreateOrderAsync(IEnumerable<CreateOrderItemRequest> items)
    {
        var itemsTable = new DataTable();
        itemsTable.Columns.Add("ProductId", typeof(int));
        itemsTable.Columns.Add("Quantity", typeof(int));
        foreach (var item in items)
        {
            itemsTable.Rows.Add(item.ProductId, item.Quantity);
        }

        var parameters = new DynamicParameters();
        parameters.Add("@Items", itemsTable.AsTableValuedParameter("dbo.OrderItemTableType"));

        using var connection = _connectionFactory.CreateConnection();

        try
        {
            using var multi = await connection.QueryMultipleAsync(
                "dbo.usp_CreateOrder",
                parameters,
                commandType: CommandType.StoredProcedure);

            var order = await multi.ReadSingleAsync<OrderResponse>();
            order.Items = (await multi.ReadAsync<OrderItemResponse>()).ToList();
            return order;
        }
        catch (SqlException ex) when (ex.Number is >= 50000 and < 51000)
        {
            throw new OrderValidationException(ex.Message);
        }
    }
}
