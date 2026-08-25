namespace API.Models;

public class ProductDto
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Category { get; set; } = string.Empty;
    public string Description { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public decimal Rating { get; set; }
    public int Reviews { get; set; }
    public int Stock { get; set; }
    public string Color { get; set; } = string.Empty;
    public string Accent { get; set; } = string.Empty;
    public string? Badge { get; set; }
}
