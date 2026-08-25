import { CommonModule } from '@angular/common';
import { Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CartService } from './cart.service';
import { Category, Order, Product } from './models';
import { OrderService } from './order.service';
import { ProductService } from './product.service';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class AppComponent implements OnInit {
  private readonly productService = inject(ProductService);
  private readonly orderService = inject(OrderService);
  readonly cart = inject(CartService);

  readonly products = signal<Product[]>([]);
  readonly isLoadingProducts = signal(false);
  readonly productsError = signal<string | null>(null);

  readonly searchTerm = signal('');
  readonly activeCategory = signal<Category>('All');
  readonly isCartOpen = signal(false);
  readonly lastOrder = signal<Order | null>(null);
  readonly isCheckingOut = signal(false);
  readonly checkoutError = signal<string | null>(null);
  readonly categories: Category[] = ['All', 'Audio', 'Home', 'Desk', 'Wellness'];

  readonly filteredProducts = computed(() => {
    const term = this.searchTerm().trim().toLowerCase();
    const category = this.activeCategory();
    return this.products().filter((product) => {
      const matchesCategory = category === 'All' || product.category === category;
      const matchesSearch = !term || `${product.name} ${product.description} ${product.category}`.toLowerCase().includes(term);
      return matchesCategory && matchesSearch;
    });
  });

  ngOnInit(): void {
    this.loadProducts();
  }

  loadProducts(): void {
    this.isLoadingProducts.set(true);
    this.productsError.set(null);
    this.productService.getProducts().subscribe({
      next: (products) => {
        this.products.set(products);
        this.isLoadingProducts.set(false);
      },
      error: () => {
        this.productsError.set('Could not load products. Is the API running?');
        this.isLoadingProducts.set(false);
      }
    });
  }

  setCategory(category: Category): void {
    this.activeCategory.set(category);
  }

  addToCart(product: Product): void {
    this.cart.add(product);
    this.isCartOpen.set(true);
  }

  checkout(): void {
    if (this.isCheckingOut() || !this.cart.cartItems().length) {
      return;
    }
    this.isCheckingOut.set(true);
    this.checkoutError.set(null);
    const items = this.cart.cartItems().map((item) => ({ productId: item.product.id, quantity: item.quantity }));
    this.orderService.createOrder(items).subscribe({
      next: (order) => {
        this.lastOrder.set(order);
        this.cart.clear();
        this.isCheckingOut.set(false);
        this.isCartOpen.set(false);
        this.loadProducts();
      },
      error: (err) => {
        this.checkoutError.set(err?.error?.message ?? 'Checkout failed. Please try again.');
        this.isCheckingOut.set(false);
      }
    });
  }

  closeSuccess(): void {
    this.lastOrder.set(null);
  }

  formatPrice(price: number): string {
    return `$${price.toFixed(2)}`;
  }
}
