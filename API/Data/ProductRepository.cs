using System.Data;
using Dapper;
using API.Models;

namespace API.Data;

public interface IProductRepository
{
    Task<IEnumerable<ProductDto>> GetProductsAsync();
    Task<ProductDto?> GetProductByIdAsync(int id);
}

public class ProductRepository : IProductRepository
{
    private readonly IDbConnectionFactory _connectionFactory;

    public ProductRepository(IDbConnectionFactory connectionFactory)
    {
        _connectionFactory = connectionFactory;
    }

    public async Task<IEnumerable<ProductDto>> GetProductsAsync()
    {
        using var connection = _connectionFactory.CreateConnection();
        return await connection.QueryAsync<ProductDto>(
            "dbo.usp_GetProducts",
            commandType: CommandType.StoredProcedure);
    }

    public async Task<ProductDto?> GetProductByIdAsync(int id)
    {
        using var connection = _connectionFactory.CreateConnection();
        return await connection.QueryFirstOrDefaultAsync<ProductDto>(
            "dbo.usp_GetProductById",
            new { Id = id },
            commandType: CommandType.StoredProcedure);
    }
}
