import { Injectable, computed, signal } from '@angular/core';
import { CartItem, Product } from './models';

@Injectable({ providedIn: 'root' })
export class CartService {
  private readonly items = signal<CartItem[]>([]);
  readonly cartItems = this.items.asReadonly();
  readonly itemCount = computed(() => this.items().reduce((total, item) => total + item.quantity, 0));
  readonly subtotal = computed(() => this.items().reduce((total, item) => total + item.product.price * item.quantity, 0));

  add(product: Product): void {
    this.items.update((items) => {
      const existing = items.find((item) => item.product.id === product.id);
      if (existing) {
        return items.map((item) => item.product.id === product.id
          ? { ...item, quantity: Math.min(item.quantity + 1, product.stock) }
          : item);
      }
      return [...items, { product, quantity: 1 }];
    });
  }

  update(productId: number, quantity: number): void {
    if (quantity < 1) {
      this.remove(productId);
      return;
    }
    this.items.update((items) => items.map((item) => item.product.id === productId
      ? { ...item, quantity: Math.min(quantity, item.product.stock) }
      : item));
  }

  remove(productId: number): void {
    this.items.update((items) => items.filter((item) => item.product.id !== productId));
  }

  clear(): void {
    this.items.set([]);
  }
}
