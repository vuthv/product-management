package com.example.product.model;

import java.math.BigDecimal;

public class ProductFilter {
    private String name;
    private BigDecimal price;
    private BigDecimal minPrice;
    private BigDecimal maxPrice;
    private int page = 1;
    private int size = 10;

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getNamePattern() {
        return name == null ? null : "%" + name.replace("\\", "\\\\")
                .replace("%", "\\%").replace("_", "\\_") + "%";
    }
    public BigDecimal getPrice() { return price; }
    public void setPrice(BigDecimal price) { this.price = price; }
    public BigDecimal getMinPrice() { return minPrice; }
    public void setMinPrice(BigDecimal minPrice) { this.minPrice = minPrice; }
    public BigDecimal getMaxPrice() { return maxPrice; }
    public void setMaxPrice(BigDecimal maxPrice) { this.maxPrice = maxPrice; }
    public int getPage() { return page; }
    public void setPage(int page) { this.page = page; }
    public int getSize() { return size; }
    public void setSize(int size) { this.size = size; }
    public long getOffset() { return ((long) page - 1) * size; }
}
