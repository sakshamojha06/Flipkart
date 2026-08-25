export type Category = 'All' | 'Audio' | 'Home' | 'Desk' | 'Wellness';

export interface Product {
  id: number;
  name: string;
  category: Exclude<Category, 'All'>;
  description: string;
  price: number;
  rating: number;
  reviews: number;
  stock: number;
  color: string;
  accent: string;
  badge?: string;
}

export interface CartItem {
  product: Product;
  quantity: number;
}

export interface OrderItem {
  productId: number;
  productName: string;
  unitPrice: number;
  quantity: number;
  lineTotal: number;
}

export interface Order {
  id: number;
  orderNumber: string;
  subtotal: number;
  createdAt: string;
  items: OrderItem[];
}
