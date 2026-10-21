import { Injectable } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { ApiResponse, Product, ProductInput, ProductPage, ProductSearch } from './product.model';

@Injectable({ providedIn: 'root' })
export class ProductService {
  private readonly url = new URL('../api/products', document.baseURI).pathname;

  constructor(private readonly http: HttpClient) {}

  search(filter: ProductSearch): Observable<ApiResponse<ProductPage>> {
    let params = new HttpParams().set('page', String(filter.page)).set('size', String(filter.size));
    if (filter.name.trim()) { params = params.set('name', filter.name.trim()); }
    for (const key of ['price', 'minPrice', 'maxPrice'] as const) {
      if (filter[key] !== null) { params = params.set(key, String(filter[key])); }
    }
    return this.http.get<ApiResponse<ProductPage>>(this.url, { params });
  }

  get(id: number): Observable<ApiResponse<Product>> {
    return this.http.get<ApiResponse<Product>>(`${this.url}/${id}`);
  }

  create(input: ProductInput): Observable<ApiResponse<Product>> {
    return this.http.post<ApiResponse<Product>>(this.url, input);
  }

  update(id: number, input: ProductInput): Observable<ApiResponse<Product>> {
    return this.http.put<ApiResponse<Product>>(`${this.url}/${id}`, input);
  }

  delete(id: number): Observable<ApiResponse<null>> {
    return this.http.delete<ApiResponse<null>>(`${this.url}/${id}`);
  }
}
