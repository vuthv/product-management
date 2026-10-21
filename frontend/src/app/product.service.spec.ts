import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { ProductSearch } from './product.model';
import { ProductService } from './product.service';

describe('ProductService HTTP contract', () => {
  let service: ProductService;
  let http: HttpTestingController;
  const url = new URL('../api/products', document.baseURI).pathname;
  const filter: ProductSearch = { name: '', price: null, minPrice: null, maxPrice: null, page: 1, size: 10 };

  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [HttpClientTestingModule] });
    service = TestBed.inject(ProductService);
    http = TestBed.inject(HttpTestingController);
  });
  afterEach(() => http.verify());

  it('sends GET paging without empty optional filters', () => {
    service.search(filter).subscribe();
    const request = http.expectOne(req => req.url === url);
    expect(request.request.method).toBe('GET');
    expect(request.request.params.keys().sort()).toEqual(['page', 'size']);
    expect(request.request.params.get('page')).toBe('1');
    request.flush({ code: 0, message: 'OK', data: { items: [] } });
  });

  it('keeps zero prices and trims names', () => {
    service.search({ ...filter, name: '  Mouse  ', price: 0 }).subscribe();
    const request = http.expectOne(req => req.url === url);
    expect(request.request.params.get('name')).toBe('Mouse');
    expect(request.request.params.get('price')).toBe('0');
    request.flush({});
  });

  it('sends both price boundaries and requested page', () => {
    service.search({ ...filter, minPrice: 0, maxPrice: 10, page: 3 }).subscribe();
    const request = http.expectOne(req => req.url === url);
    expect(request.request.params.get('minPrice')).toBe('0');
    expect(request.request.params.get('maxPrice')).toBe('10');
    expect(request.request.params.get('page')).toBe('3');
    request.flush({});
  });

  it('gets a single product', () => {
    service.get(12).subscribe();
    const request = http.expectOne(`${url}/12`);
    expect(request.request.method).toBe('GET');
    request.flush({});
  });

  it('posts only editable fields', () => {
    const input = { name: 'Desk', description: '', price: 12.30 };
    service.create(input).subscribe();
    const request = http.expectOne(url);
    expect(request.request.method).toBe('POST');
    expect(request.request.body).toEqual(input);
    request.flush({});
  });

  it('puts edited product to the ID route', () => {
    service.update(4, { name: 'Lamp', description: 'Updated', price: 5 }).subscribe();
    const request = http.expectOne(`${url}/4`);
    expect(request.request.method).toBe('PUT');
    request.flush({});
  });

  it('deletes a product', () => {
    service.delete(4).subscribe();
    const request = http.expectOne(`${url}/4`);
    expect(request.request.method).toBe('DELETE');
    request.flush({ code: 0, message: 'Product deleted', data: null });
  });

  it('propagates API errors rather than returning empty success', () => {
    const failure = jasmine.createSpy('failure');
    service.get(99).subscribe({ error: failure });
    http.expectOne(`${url}/99`).flush({ code: 404, message: 'Missing', data: null },
      { status: 404, statusText: 'Not Found' });
    expect(failure).toHaveBeenCalled();
  });
});
