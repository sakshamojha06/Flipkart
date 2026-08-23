import { CommonModule } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { CartService } from './cart.service';
import { MOCK_PRODUCTS } from './mock-data';
import { Category, Product } from './models';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class AppComponent {
  readonly cart = inject(CartService);
  readonly products = MOCK_PRODUCTS;
  readonly searchTerm = signal('');
  readonly activeCategory = signal<Category>('All');
  readonly isCartOpen = signal(false);
  readonly showSuccess = signal(false);
  readonly categories: Category[] = ['All', 'Audio', 'Home', 'Desk', 'Wellness'];

  readonly filteredProducts = computed(() => {
    const term = this.searchTerm().trim().toLowerCase();
    const category = this.activeCategory();
    return this.products.filter((product) => {
      const matchesCategory = category === 'All' || product.category === category;
      const matchesSearch = !term || `${product.name} ${product.description} ${product.category}`.toLowerCase().includes(term);
      return matchesCategory && matchesSearch;
    });
  });

  setCategory(category: Category): void {
    this.activeCategory.set(category);
  }

  addToCart(product: Product): void {
    this.cart.add(product);
    this.isCartOpen.set(true);
  }

  checkout(): void {
    this.showSuccess.set(true);
    this.cart.clear();
  }

  closeSuccess(): void {
    this.showSuccess.set(false);
  }

  formatPrice(price: number): string {
    return `$${price.toFixed(2)}`;
  }
}
