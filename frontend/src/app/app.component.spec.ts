import { ComponentFixture, TestBed } from '@angular/core/testing';
import { FormsModule } from '@angular/forms';
import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { AppComponent } from './app.component';
import { ProductService } from './product.service';

describe('Product catalog UI', () => {
  let component: AppComponent;
  let fixture: ComponentFixture<AppComponent>;
  let products: jasmine.SpyObj<ProductService>;

  beforeEach(async () => {
    products = jasmine.createSpyObj<ProductService>('ProductService', ['search', 'create', 'get', 'update', 'delete']);
    products.search.and.returnValue(of({
      code: 0, message: 'OK',
      data: { items: [], total: 0, page: 1, size: 10, totalPages: 0 }
    }));
    await TestBed.configureTestingModule({
      imports: [FormsModule], declarations: [AppComponent],
      providers: [{ provide: ProductService, useValue: products }]
    }).compileComponents();
    fixture = TestBed.createComponent(AppComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('renders a helpful empty state', () => {
    expect(fixture.nativeElement.textContent).toContain('No products found');
    expect(component.loading).toBeFalse();
  });

  it('starts a new search from page one', () => {
    component.filter.page = 7;
    component.filter.name = 'Lamp';
    component.search();
    expect(component.filter.page).toBe(1);
    expect(products.search.calls.mostRecent().args[0].name).toBe('Lamp');
  });

  it('resets every price filter including exact price zero', () => {
    component.filter.price = 0;
    component.filter.name = 'A';
    component.resetFilters();
    expect(component.filter.price).toBeNull();
    expect(component.filter.minPrice).toBeNull();
    expect(component.filter.maxPrice).toBeNull();
    expect(component.filter.name).toBe('');
  });

  it('shows API field errors without losing loaded products', () => {
    products.search.and.returnValue(throwError(new HttpErrorResponse({
      status: 400, error: { code: 400, message: 'Invalid input', data: { price: 'Price must be positive' } }
    })));
    component.load();
    fixture.detectChanges();
    expect(component.error).toContain('Price must be positive');
    expect(fixture.nativeElement.querySelector('[role="alert"]').textContent).toContain('Invalid input');
    expect(component.loading).toBeFalse();
  });

  it('shows connection failures and allows retry', () => {
    products.search.and.returnValue(throwError(new HttpErrorResponse({ status: 0 })));
    component.load();
    expect(component.error).toContain('Cannot reach the server');
    expect(component.loading).toBeFalse();
  });

  it('prevents navigation outside available pages', () => {
    const calls = products.search.calls.count();
    component.page(-1);
    component.page(1);
    expect(products.search.calls.count()).toBe(calls);
  });

  it('opens an accessible native dialog for creating a product', () => {
    component.openEditor();
    fixture.detectChanges();
    const dialog: HTMLDialogElement = fixture.nativeElement.querySelector('dialog');
    expect(dialog.open).toBeTrue();
    expect(dialog.getAttribute('aria-labelledby')).toBe('editorTitle');
    component.closeEditor();
    expect(dialog.open).toBeFalse();
  });

  it('does not close an editor while a write is in progress', () => {
    component.openEditor();
    component.saving = true;
    const event = new Event('cancel', { cancelable: true });
    component.closeEditor(event);
    expect(event.defaultPrevented).toBeTrue();
    expect(fixture.nativeElement.querySelector('dialog').open).toBeTrue();
  });
});
