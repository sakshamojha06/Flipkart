using API.Data;
using API.Models;
using Microsoft.AspNetCore.Mvc;

namespace API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly IOrderRepository _orderRepository;

    public OrdersController(IOrderRepository orderRepository)
    {
        _orderRepository = orderRepository;
    }

    [HttpPost]
    public async Task<IActionResult> CreateOrder([FromBody] CreateOrderRequest request)
    {
        if (request.Items.Count == 0)
        {
            return BadRequest(new { message = "Order must contain at least one item." });
        }

        if (request.Items.Any(item => item.Quantity <= 0))
        {
            return BadRequest(new { message = "Item quantity must be greater than zero." });
        }

        try
        {
            var order = await _orderRepository.CreateOrderAsync(request.Items);
            return CreatedAtAction(nameof(CreateOrder), new { id = order.Id }, order);
        }
        catch (OrderValidationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }
}
