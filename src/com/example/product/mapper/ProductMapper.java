package com.example.product.mapper;

import com.example.product.model.Product;
import com.example.product.model.ProductFilter;
import java.util.List;
import org.apache.ibatis.annotations.Param;

public interface ProductMapper {
    Product findById(@Param("id") long id);
    List<Product> search(ProductFilter filter);
    long count(ProductFilter filter);
    int insert(Product product);
    int update(Product product);
    int delete(@Param("id") long id);
}
