import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { Observable } from 'rxjs';
import { API_BASE_URL } from './api-config';
import { Order } from './models';

export interface CreateOrderItem {
  productId: number;
  quantity: number;
}

@Injectable({ providedIn: 'root' })
export class OrderService {
  private readonly http = inject(HttpClient);

  createOrder(items: CreateOrderItem[]): Observable<Order> {
    return this.http.post<Order>(`${API_BASE_URL}/orders`, { items });
  }
}
