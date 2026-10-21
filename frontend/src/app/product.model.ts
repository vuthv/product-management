export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

export interface ProductInput {
  name: string;
  description: string;
  price: number;
}

export interface Product extends ProductInput {
  id: number;
  createdAt: string;
  updatedAt: string;
}

export interface ProductPage {
  items: Product[];
  total: number;
  page: number;
  size: number;
  totalPages: number;
}

export interface ProductSearch {
  name: string;
  price: number | null;
  minPrice: number | null;
  maxPrice: number | null;
  page: number;
  size: number;
}
