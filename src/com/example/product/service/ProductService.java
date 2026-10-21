package com.example.product.service;

import com.example.product.common.PageResult;
import com.example.product.exception.ProductNotFoundException;
import com.example.product.mapper.ProductMapper;
import com.example.product.model.Product;
import com.example.product.model.ProductFilter;
import com.example.product.model.ProductInput;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ProductService {
    private final ProductMapper mapper;

    public ProductService(ProductMapper mapper) { this.mapper = mapper; }

    @Transactional(readOnly = true)
    public Product get(long id) {
        ProductValidation.id(id);
        return requireProduct(id);
    }

    @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
    public PageResult<Product> search(ProductFilter filter) {
        ProductValidation.filter(filter);
        long total = mapper.count(filter);
        return new PageResult<>(mapper.search(filter), total, filter.getPage(), filter.getSize());
    }

    @Transactional
    public Product create(ProductInput input) {
        ProductValidation.input(input);
        Product product = product(null, input);
        if (mapper.insert(product) != 1) { throw new IllegalStateException("Insert affected an unexpected row count"); }
        return requireProduct(product.getId());
    }

    @Transactional
    public Product update(long id, ProductInput input) {
        ProductValidation.id(id);
        ProductValidation.input(input);
        if (mapper.update(product(id, input)) == 0) { throw new ProductNotFoundException(id); }
        return requireProduct(id);
    }

    @Transactional
    public void delete(long id) {
        ProductValidation.id(id);
        if (mapper.delete(id) == 0) { throw new ProductNotFoundException(id); }
    }

    private Product requireProduct(long id) {
        Product product = mapper.findById(id);
        if (product == null) { throw new ProductNotFoundException(id); }
        return product;
    }

    private Product product(Long id, ProductInput input) {
        Product product = new Product();
        product.setId(id);
        product.setName(input.getName());
        product.setDescription(input.getDescription());
        product.setPrice(input.getPrice());
        return product;
    }
}
