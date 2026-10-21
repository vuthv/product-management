package com.example.product.exception;

import java.util.Map;

public class InvalidInputException extends RuntimeException {
    private final Map<String, String> errors;

    public InvalidInputException(Map<String, String> errors) {
        super("Invalid input");
        this.errors = errors;
    }

    public Map<String, String> getErrors() { return errors; }
}
