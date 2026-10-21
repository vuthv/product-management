package com.example.product;

import com.example.product.controller.ProductController;
import com.example.product.exception.GlobalExceptionHandler;
import com.example.product.mapper.ProductMapper;
import com.example.product.model.*;
import com.example.product.service.ProductService;
import com.example.product.service.ProductValidation;
import com.fasterxml.jackson.databind.*;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import java.io.InputStream;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
import java.util.stream.Collectors;
import org.apache.ibatis.builder.xml.XMLMapperBuilder;
import org.apache.ibatis.mapping.BoundSql;
import org.apache.ibatis.session.Configuration;
import org.junit.*;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.MediaType;
import org.springframework.http.converter.json.MappingJackson2HttpMessageConverter;
import org.springframework.test.web.servlet.*;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import static org.junit.Assert.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

public class ProductApiTest {
    private MockMvc mvc;
    private MemoryMapper mapper;
    private ObjectMapper json;

    @Before
    public void setup() {
        mapper = new MemoryMapper();
        json = new ObjectMapper().registerModule(new JavaTimeModule())
                .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)
                .enable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES);
        mvc = MockMvcBuilders.standaloneSetup(new ProductController(new ProductService(mapper)))
                .setControllerAdvice(new GlobalExceptionHandler())
                .setMessageConverters(new MappingJackson2HttpMessageConverter(json))
                .addDispatcherServletCustomizer(servlet -> servlet.setThrowExceptionIfNoHandlerFound(true))
                .build();
    }

    @Test
    public void createReturns201EnvelopeAndLocation() throws Exception {
        MvcResult result = mvc.perform(post("/api/products").contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\" Keyboard \",\"price\":12.30}")).andExpect(status().isCreated()).andReturn();
        JsonNode body = body(result);
        assertEnvelope(body, 0);
        assertEquals("Keyboard", body.at("/data/name").asText());
        assertEquals(0, new BigDecimal("12.30").compareTo(body.at("/data/price").decimalValue()));
        assertEquals("", body.at("/data/description").asText());
        assertTrue(result.getResponse().getHeader("Location").endsWith("/api/products/1"));
        assertTrue(body.at("/data/createdAt").asText().endsWith("Z"));
    }

    @Test
    public void getUpdateDeleteRoundTrip() throws Exception {
        create("Mouse", "15.50");
        mvc.perform(get("/api/products/1")).andExpect(status().isOk());
        JsonNode updated = body(mvc.perform(put("/api/products/1").contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Mouse 2\",\"description\":\"Updated\",\"price\":0}"))
                .andExpect(status().isOk()).andReturn());
        assertEquals("Mouse 2", updated.at("/data/name").asText());
        assertEquals(0, updated.at("/data/price").intValue());
        JsonNode deleted = body(mvc.perform(delete("/api/products/1")).andExpect(status().isOk()).andReturn());
        assertEnvelope(deleted, 0);
        assertTrue(deleted.get("data").isNull());
        mvc.perform(get("/api/products/1")).andExpect(status().isNotFound());
    }

    @Test
    public void listReturnsCompletePaginationShape() throws Exception {
        create("Keyboard", "20");
        create("Mouse", "10");
        JsonNode page = body(mvc.perform(get("/api/products").param("page", "2").param("size", "1"))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertEquals(2, page.get("total").asInt());
        assertEquals(2, page.get("totalPages").asInt());
        assertEquals(2, page.get("page").asInt());
        assertEquals(1, page.get("size").asInt());
        assertEquals(1, page.get("items").size());
    }

    @Test
    public void emptyPageKeepsTotal() throws Exception {
        create("Mouse", "10");
        JsonNode data = body(mvc.perform(get("/api/products").param("page", "999"))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertEquals(1, data.get("total").asInt());
        assertEquals(0, data.get("items").size());
    }

    @Test
    public void combinedNameAndRangeFilter() throws Exception {
        create("Wireless Mouse", "10");
        create("Wireless Keyboard", "20");
        JsonNode data = body(mvc.perform(get("/api/products").param("name", "WIRELESS")
                .param("minPrice", "15").param("maxPrice", "25"))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertEquals(1, data.get("total").asInt());
        assertEquals("Wireless Keyboard", data.at("/items/0/name").asText());
    }

    @Test
    public void exactZeroPriceIsSupported() throws Exception {
        create("Free", "0");
        create("Paid", "1");
        JsonNode data = body(mvc.perform(get("/api/products").param("price", "0"))
                .andExpect(status().isOk()).andReturn()).get("data");
        assertEquals(1, data.get("total").asInt());
    }

    @Test
    public void missingProductsReturn404ForAllMethods() throws Exception {
        assertEnvelope(body(mvc.perform(get("/api/products/42")).andExpect(status().isNotFound()).andReturn()), 404);
        mvc.perform(put("/api/products/42").contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Missing\",\"price\":1}")).andExpect(status().isNotFound());
        mvc.perform(delete("/api/products/42")).andExpect(status().isNotFound());
    }

    @Test
    public void blankNameAndMissingPriceReturnFieldErrors() throws Exception {
        JsonNode body = body(mvc.perform(post("/api/products").contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"  \"}")).andExpect(status().isBadRequest()).andReturn());
        assertEnvelope(body, 400);
        assertTrue(body.get("data").has("name"));
        assertTrue(body.get("data").has("price"));
        assertTrue(mapper.rows.isEmpty());
    }

    @Test
    public void invalidPriceNeverWrites() throws Exception {
        for (String price : new String[]{"-1", "0.001", "10000000000"}) {
            mvc.perform(post("/api/products").contentType(MediaType.APPLICATION_JSON)
                    .content("{\"name\":\"Item\",\"price\":" + price + "}")).andExpect(status().isBadRequest());
        }
        assertTrue(mapper.rows.isEmpty());
    }

    @Test
    public void maximumPriceIsAcceptedWithoutRounding() throws Exception {
        create("Max", "9999999999.99");
        assertEquals(new BigDecimal("9999999999.99"), mapper.rows.get(1L).getPrice());
    }

    @Test
    public void controlCharactersAreRejected() throws Exception {
        mvc.perform(post("/api/products").contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"Injected\\nline\",\"price\":1}")).andExpect(status().isBadRequest());
    }

    @Test
    public void oversizedFieldsAreRejected() throws Exception {
        ProductInput input = new ProductInput();
        input.setName(String.join("", Collections.nCopies(256, "a")));
        input.setDescription(String.join("", Collections.nCopies(1001, "a")));
        input.setPrice(BigDecimal.ONE);
        JsonNode body = body(mvc.perform(post("/api/products").contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(input))).andExpect(status().isBadRequest()).andReturn());
        assertTrue(body.get("data").has("name"));
        assertTrue(body.get("data").has("description"));
    }

    @Test
    public void invalidQueryAndIdReturn400() throws Exception {
        mvc.perform(get("/api/products").param("page", "0")).andExpect(status().isBadRequest());
        mvc.perform(get("/api/products").param("size", "101")).andExpect(status().isBadRequest());
        mvc.perform(get("/api/products").param("price", "oops")).andExpect(status().isBadRequest());
        mvc.perform(get("/api/products/abc")).andExpect(status().isBadRequest());
        mvc.perform(delete("/api/products/0")).andExpect(status().isBadRequest());
    }

    @Test
    public void invalidPriceRangesReturn400() throws Exception {
        mvc.perform(get("/api/products").param("minPrice", "10").param("maxPrice", "1")).andExpect(status().isBadRequest());
        mvc.perform(get("/api/products").param("price", "1").param("minPrice", "1")).andExpect(status().isBadRequest());
    }

    @Test
    public void malformedAndUnknownJsonFieldsReturnEnvelope() throws Exception {
        for (String payload : new String[]{"{bad", "null", "{\"name\":\"A\",\"price\":1,\"id\":99}"}) {
            assertEnvelope(body(mvc.perform(post("/api/products").contentType(MediaType.APPLICATION_JSON)
                    .content(payload)).andExpect(status().isBadRequest()).andReturn()), 400);
        }
    }

    @Test
    public void wrongMethodMediaTypeAndRouteReturnEnvelope() throws Exception {
        assertEnvelope(body(mvc.perform(patch("/api/products/1")).andExpect(status().isMethodNotAllowed()).andReturn()), 405);
        assertEnvelope(body(mvc.perform(post("/api/products").contentType(MediaType.TEXT_PLAIN)
                .content("oops")).andExpect(status().isUnsupportedMediaType()).andReturn()), 415);
        assertEnvelope(body(mvc.perform(get("/api/missing")).andExpect(status().isNotFound()).andReturn()), 404);
    }

    @Test
    public void databaseFailureDoesNotLeakDetails() throws Exception {
        mapper.failure = new DataAccessResourceFailureException("sensitive database details");
        JsonNode body = body(mvc.perform(get("/api/products/1")).andExpect(status().isServiceUnavailable()).andReturn());
        assertEnvelope(body, 503);
        assertFalse(body.toString().contains("sensitive"));
    }

    @Test
    public void constraintViolationReturns409() throws Exception {
        mapper.failure = new DataIntegrityViolationException("private constraint");
        assertEnvelope(body(mvc.perform(get("/api/products/1")).andExpect(status().isConflict()).andReturn()), 409);
    }

    @Test
    public void unexpectedFailureReturns500() throws Exception {
        mapper.failure = new IllegalStateException("private stack information");
        JsonNode body = body(mvc.perform(get("/api/products/1")).andExpect(status().isInternalServerError()).andReturn());
        assertEnvelope(body, 500);
        assertFalse(body.toString().contains("private"));
    }

    @Test
    public void paginationOffsetDoesNotOverflowInt() {
        ProductFilter filter = new ProductFilter();
        filter.setPage(Integer.MAX_VALUE);
        filter.setSize(100);
        ProductValidation.filter(filter);
        assertEquals(214748364600L, filter.getOffset());
    }

    @Test
    public void mybatisDynamicSqlUsesBoundParametersAndSharedFilters() throws Exception {
        Configuration configuration = new Configuration();
        try (InputStream stream = getClass().getResourceAsStream("/mappers/ProductMapper.xml")) {
            new XMLMapperBuilder(stream, configuration, "mappers/ProductMapper.xml",
                    configuration.getSqlFragments()).parse();
        }
        ProductFilter filter = new ProductFilter();
        String statement = "com.example.product.mapper.ProductMapper.";
        BoundSql empty = configuration.getMappedStatement(statement + "search").getBoundSql(filter);
        assertFalse(empty.getSql().contains("WHERE"));
        filter.setName("x%' OR 1=1 --");
        filter.setMinPrice(BigDecimal.ONE);
        filter.setMaxPrice(BigDecimal.TEN);
        BoundSql search = configuration.getMappedStatement(statement + "search").getBoundSql(filter);
        BoundSql count = configuration.getMappedStatement(statement + "count").getBoundSql(filter);
        assertTrue(search.getSql().contains("WHERE"));
        assertTrue(search.getSql().contains("ILIKE ?"));
        assertFalse(search.getSql().contains(filter.getName()));
        assertEquals(5, search.getParameterMappings().size());
        assertEquals(3, count.getParameterMappings().size());
        assertEquals("%x\\%' OR 1=1 --%", filter.getNamePattern());
    }

    private void create(String name, String price) throws Exception {
        mvc.perform(post("/api/products").contentType(MediaType.APPLICATION_JSON)
                .content("{\"name\":\"" + name + "\",\"price\":" + price + "}")).andExpect(status().isCreated());
    }

    private JsonNode body(MvcResult result) throws Exception {
        return json.readTree(result.getResponse().getContentAsByteArray());
    }

    private void assertEnvelope(JsonNode body, int code) {
        assertEquals(3, body.size());
        assertEquals(code, body.get("code").asInt());
        assertTrue(body.get("message").isTextual());
        assertTrue(body.has("data"));
    }

    private static class MemoryMapper implements ProductMapper {
        private final Map<Long, Product> rows = new LinkedHashMap<>();
        private long sequence;
        private RuntimeException failure;

        @Override public Product findById(long id) {
            if (failure != null) { throw failure; }
            return rows.get(id);
        }
        private List<Product> matches(ProductFilter filter) {
            return rows.values().stream().filter(product ->
                (filter.getName() == null || product.getName().toLowerCase(Locale.ROOT)
                    .contains(filter.getName().toLowerCase(Locale.ROOT)))
                && (filter.getPrice() == null || product.getPrice().compareTo(filter.getPrice()) == 0)
                && (filter.getMinPrice() == null || product.getPrice().compareTo(filter.getMinPrice()) >= 0)
                && (filter.getMaxPrice() == null || product.getPrice().compareTo(filter.getMaxPrice()) <= 0))
                .sorted(Comparator.comparing(Product::getId).reversed()).collect(Collectors.toList());
        }
        @Override public List<Product> search(ProductFilter filter) {
            return matches(filter).stream().skip(filter.getOffset()).limit(filter.getSize()).collect(Collectors.toList());
        }
        @Override public long count(ProductFilter filter) { return matches(filter).size(); }
        @Override public int insert(Product product) {
            product.setId(++sequence);
            product.setCreatedAt(Instant.now());
            product.setUpdatedAt(Instant.now());
            rows.put(product.getId(), product);
            return 1;
        }
        @Override public int update(Product product) {
            if (!rows.containsKey(product.getId())) { return 0; }
            product.setCreatedAt(rows.get(product.getId()).getCreatedAt());
            product.setUpdatedAt(Instant.now());
            rows.put(product.getId(), product);
            return 1;
        }
        @Override public int delete(long id) { return rows.remove(id) == null ? 0 : 1; }
    }
}
