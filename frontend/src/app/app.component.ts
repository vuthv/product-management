import {
  Component,
  ElementRef,
  OnDestroy,
  OnInit,
  ViewChild,
} from "@angular/core";
import { HttpErrorResponse } from "@angular/common/http";
import { NgForm } from "@angular/forms";
import { finalize, switchMap, takeUntil } from "rxjs/operators";
import { of, Subject } from "rxjs";
import {
  Product,
  ProductInput,
  ProductPage,
  ProductSearch,
} from "./product.model";
import { ProductService } from "./product.service";

@Component({
  selector: "app-root",
  templateUrl: "./app.component.html",
})
export class AppComponent implements OnInit, OnDestroy {
  @ViewChild("editorDialog") editorDialog?: ElementRef<HTMLDialogElement>;
  @ViewChild("deleteDialog") deleteDialog?: ElementRef<HTMLDialogElement>;
  @ViewChild("nameInput") nameInput?: ElementRef<HTMLInputElement>;
  readonly Math = Math;
  readonly filter: ProductSearch = {
    name: "",
    price: null,
    minPrice: null,
    maxPrice: null,
    page: 1,
    size: 10,
  };
  result: ProductPage = {
    items: [],
    total: 0,
    page: 1,
    size: 10,
    totalPages: 0,
  };
  draft: { name: string; description: string; price: number | null } = {
    name: "",
    description: "",
    price: null,
  };
  selectedId: number | null = null;
  deleting: Product | null = null;
  loading = false;
  saving = false;
  deletingBusy = false;
  error = "";
  formError = "";
  deleteError = "";
  notice = "";
  private readonly destroyed = new Subject<void>();

  constructor(private readonly products: ProductService) {}

  ngOnInit(): void {
    this.load();
  }

  ngOnDestroy(): void {
    this.destroyed.next();
    this.destroyed.complete();
  }

  load(): void {
    this.loading = true;
    this.error = "";
    this.products
      .search(this.filter)
      .pipe(
        switchMap((response) => {
          if (this.filter.page > 1 && response.data.items.length === 0) {
            this.filter.page = Math.max(1, response.data.totalPages);
            return this.products.search(this.filter);
          }
          return of(response);
        }),
        takeUntil(this.destroyed),
        finalize(() => (this.loading = false)),
      )
      .subscribe({
        next: (response) => (this.result = response.data),
        error: (error) => (this.error = this.errorMessage(error)),
      });
  }

  search(): void {
    this.filter.page = 1;
    this.notice = "";
    this.load();
  }

  resetFilters(): void {
    Object.assign(this.filter, {
      name: "",
      price: null,
      minPrice: null,
      maxPrice: null,
      page: 1,
    });
    this.notice = "";
    this.load();
  }

  page(direction: number): void {
    const page = this.result.page + direction;
    if (this.loading || page < 1 || page > this.result.totalPages) {
      return;
    }
    this.filter.page = page;
    this.load();
  }

  openEditor(product?: Product): void {
    this.selectedId = product ? product.id : null;
    this.draft = product
      ? {
          name: product.name,
          description: product.description,
          price: product.price,
        }
      : { name: "", description: "", price: null };
    this.formError = "";
    this.editorDialog?.nativeElement.showModal();
    setTimeout(() => this.nameInput?.nativeElement.focus());
  }

  closeEditor(event?: Event): void {
    if (this.saving) {
      event?.preventDefault();
      return;
    }
    this.editorDialog?.nativeElement.close();
  }

  save(form: NgForm): void {
    if (form.invalid || this.saving || this.draft.price === null) {
      return;
    }
    const input: ProductInput = {
      name: this.draft.name.trim(),
      description: this.draft.description.trim(),
      price: this.draft.price ?? 0,
    };
    if (!input.name) {
      this.formError = "Please enter a product name.";
      return;
    }
    if (
      !Number.isFinite(input.price) ||
      Math.abs(input.price * 100 - Math.round(input.price * 100)) > 0.0001
    ) {
      this.formError = "Price must have at most two decimal places.";
      return;
    }
    this.saving = true;
    this.formError = "";
    const request =
      this.selectedId === null
        ? this.products.create(input)
        : this.products.update(this.selectedId, input);
    request
      .pipe(
        takeUntil(this.destroyed),
        finalize(() => (this.saving = false)),
      )
      .subscribe({
        next: (response) => {
          this.editorDialog?.nativeElement.close();
          this.notice = response.message;
          this.load();
        },
        error: (error) => (this.formError = this.errorMessage(error)),
      });
  }

  confirmDelete(product: Product): void {
    this.deleting = product;
    this.deleteError = "";
    this.deleteDialog?.nativeElement.showModal();
  }

  closeDelete(event?: Event): void {
    if (this.deletingBusy) {
      event?.preventDefault();
      return;
    }
    this.deleteDialog?.nativeElement.close();
  }

  remove(): void {
    if (!this.deleting || this.deletingBusy) {
      return;
    }
    this.deletingBusy = true;
    this.deleteError = "";
    this.products
      .delete(this.deleting.id)
      .pipe(
        takeUntil(this.destroyed),
        finalize(() => (this.deletingBusy = false)),
      )
      .subscribe({
        next: (response) => {
          this.deleteDialog?.nativeElement.close();
          this.notice = response.message;
          this.deleting = null;
          this.load();
        },
        error: (error) => (this.deleteError = this.errorMessage(error)),
      });
  }

  trackProduct(index: number, product: Product): number {
    return product.id;
  }

  private errorMessage(error: unknown): string {
    if (error instanceof HttpErrorResponse) {
      const body: unknown = error.error;
      if (this.isRecord(body)) {
        const message = body.message;
        const data = body.data;
        if (typeof message === "string") {
          const details = this.isRecord(data)
            ? Object.values(data)
                .filter((value): value is string => typeof value === "string")
                .join(". ")
            : "";
          return details ? `${message}: ${details}` : message;
        }
      }
      if (error.status === 0) {
        return "Cannot reach the server. Check that Tomcat is running and try again.";
      }
      return `Request failed (${error.status}). Please try again.`;
    }
    return "An unexpected error occurred. Please try again.";
  }

  private isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === "object" && value !== null;
  }
}
