package com.example.product.controller;

import com.example.product.common.ApiResponse;
import com.example.product.common.PageResult;
import com.example.product.model.Product;
import com.example.product.model.ProductFilter;
import com.example.product.model.ProductInput;
import com.example.product.service.ProductService;
import java.math.BigDecimal;
import java.net.URI;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping("/api/products")
public class ProductController {
    private static final Logger log = LoggerFactory.getLogger(ProductController.class);
    private final ProductService service;

    public ProductController(ProductService service) { this.service = service; }

    @GetMapping("/{id}")
    public ApiResponse<Product> get(@PathVariable("id") long id) {
        return ApiResponse.ok("OK", service.get(id));
    }

    @GetMapping
    public ApiResponse<PageResult<Product>> search(
            @RequestParam(value = "name", required = false) String name,
            @RequestParam(value = "price", required = false) BigDecimal price,
            @RequestParam(value = "minPrice", required = false) BigDecimal minPrice,
            @RequestParam(value = "maxPrice", required = false) BigDecimal maxPrice,
            @RequestParam(value = "page", defaultValue = "1") int page,
            @RequestParam(value = "size", defaultValue = "10") int size) {
        ProductFilter filter = new ProductFilter();
        filter.setName(name);
        filter.setPrice(price);
        filter.setMinPrice(minPrice);
        filter.setMaxPrice(maxPrice);
        filter.setPage(page);
        filter.setSize(size);
        return ApiResponse.ok("OK", service.search(filter));
    }

    @PostMapping(consumes = "application/json")
    public ResponseEntity<ApiResponse<Product>> create(@RequestBody ProductInput input) {
        Product product = service.create(input);
        log.info("Tạo sản phẩm mới tên {} (ID {})", product.getName(), product.getId());
        URI location = ServletUriComponentsBuilder.fromCurrentRequest()
                .path("/{id}").buildAndExpand(product.getId()).toUri();
        return ResponseEntity.created(location).body(ApiResponse.ok("Product created", product));
    }

    @PutMapping(value = "/{id}", consumes = "application/json")
    public ApiResponse<Product> update(@PathVariable("id") long id, @RequestBody ProductInput input) {
        Product product = service.update(id, input);
        log.info("Cập nhật sản phẩm ID {}", id);
        return ApiResponse.ok("Product updated", product);
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Void> delete(@PathVariable("id") long id) {
        service.delete(id);
        log.info("Xóa sản phẩm ID {}", id);
        return ApiResponse.ok("Product deleted", null);
    }
}
