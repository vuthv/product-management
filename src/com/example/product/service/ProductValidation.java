package com.example.product.service;

import com.example.product.exception.InvalidInputException;
import com.example.product.model.ProductFilter;
import com.example.product.model.ProductInput;
import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;

public final class ProductValidation {
    public static final BigDecimal MAX_PRICE = new BigDecimal("9999999999.99");

    private ProductValidation() {}

    public static void input(ProductInput input) {
        Map<String, String> errors = new LinkedHashMap<>();
        if (input.getName() == null || input.getName().trim().isEmpty()) {
            errors.put("name", "Name is required");
        } else if (input.getName().trim().length() > 255
                || input.getName().chars().anyMatch(Character::isISOControl)) {
            errors.put("name", "Name must contain 1-255 characters, without control characters");
        }
        if (input.getDescription() != null && (input.getDescription().length() > 1000
                || input.getDescription().indexOf('\0') >= 0)) {
            errors.put("description", "Description must have at most 1000 characters and no NUL");
        }
        if (input.getPrice() == null) {
            errors.put("price", "Price is required");
        } else {
            price("price", input.getPrice(), errors);
        }
        failIfInvalid(errors);
        input.setName(input.getName().trim());
        input.setDescription(input.getDescription() == null ? "" : input.getDescription().trim());
    }

    public static void filter(ProductFilter filter) {
        Map<String, String> errors = new LinkedHashMap<>();
        if (filter.getPage() < 1) { errors.put("page", "Page must be at least 1"); }
        if (filter.getSize() < 1 || filter.getSize() > 100) {
            errors.put("size", "Size must be between 1 and 100");
        }
        if (filter.getName() != null) {
            filter.setName(filter.getName().trim());
            if (filter.getName().length() > 255
                    || filter.getName().chars().anyMatch(Character::isISOControl)) {
                errors.put("name", "Name must have at most 255 characters, without control characters");
            }
        }
        price("price", filter.getPrice(), errors);
        price("minPrice", filter.getMinPrice(), errors);
        price("maxPrice", filter.getMaxPrice(), errors);
        if (filter.getPrice() != null && (filter.getMinPrice() != null || filter.getMaxPrice() != null)) {
            errors.put("price", "Use either price or minPrice/maxPrice, not both");
        }
        if (filter.getMinPrice() != null && filter.getMaxPrice() != null
                && filter.getMinPrice().compareTo(filter.getMaxPrice()) > 0) {
            errors.put("maxPrice", "Max price must be greater than or equal to min price");
        }
        failIfInvalid(errors);
    }

    public static void id(long id) {
        if (id < 1) {
            Map<String, String> errors = new LinkedHashMap<>();
            errors.put("id", "ID must be positive");
            throw new InvalidInputException(errors);
        }
    }

    private static void price(String field, BigDecimal value, Map<String, String> errors) {
        if (value != null && (value.signum() < 0 || value.compareTo(MAX_PRICE) > 0
                || value.stripTrailingZeros().scale() > 2)) {
            errors.put(field, "Price must be 0-9999999999.99 with at most 2 decimal places");
        }
    }

    private static void failIfInvalid(Map<String, String> errors) {
        if (!errors.isEmpty()) { throw new InvalidInputException(errors); }
    }
}
