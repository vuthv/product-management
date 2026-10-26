package com.example.product.exception;

import com.example.product.common.ApiResponse;
import javax.servlet.http.HttpServletRequest;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler;

@RestControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {
    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    @ExceptionHandler(InvalidInputException.class)
    public ResponseEntity<Object> validation(InvalidInputException ex) {
        log.warn("Rejected invalid input: {}", ex.getErrors().keySet());
        return response(HttpStatus.BAD_REQUEST, 400, ex.getMessage(), ex.getErrors());
    }

    @ExceptionHandler(ProductNotFoundException.class)
    public ResponseEntity<Object> notFound(ProductNotFoundException ex) {
        log.warn("{}", ex.getMessage());
        return response(HttpStatus.NOT_FOUND, 404, ex.getMessage(), null);
    }

    @ExceptionHandler(DataIntegrityViolationException.class)
    public ResponseEntity<Object> conflict(DataIntegrityViolationException ex) {
        log.error("Database constraint violation", ex);
        return response(HttpStatus.CONFLICT, 409, "Product conflicts with database constraints", null);
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Object> database(DataAccessException ex) {
        log.error("Database operation failed", ex);
        return response(HttpStatus.SERVICE_UNAVAILABLE, 503, "Database is temporarily unavailable", null);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<Object> unexpected(Exception ex, HttpServletRequest request) {
        log.error("Unexpected failure during {}", request.getMethod(), ex);
        return response(HttpStatus.INTERNAL_SERVER_ERROR, 500, "An unexpected error occurred", null);
    }

    @Override
    protected ResponseEntity<Object> handleExceptionInternal(Exception ex, Object body,
            HttpHeaders headers, HttpStatus status, WebRequest request) {
        log.warn("HTTP request rejected: status={}, exception={}", status.value(), ex.getClass().getSimpleName());
        return new ResponseEntity<>(new ApiResponse<>(status.value(), status.getReasonPhrase(), null), headers, status);
    }

    private ResponseEntity<Object> response(HttpStatus status, int code, String message, Object data) {
        return new ResponseEntity<>(new ApiResponse<>(code, message, data), status);
    }
}
