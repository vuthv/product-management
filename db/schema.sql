BEGIN;

CREATE TABLE product (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(255) NOT NULL CHECK (length(btrim(name)) > 0),
    description VARCHAR(1000) NOT NULL DEFAULT '',
    price NUMERIC(12, 2) NOT NULL CHECK (price >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO product (name, description, price) VALUES
    ('Mechanical Keyboard', 'Compact keyboard with quiet switches', 89.90),
    ('Wireless Mouse', 'Rechargeable ergonomic mouse', 24.50),
    ('USB-C Hub', 'Connect your everyday essentials', 39.00),
    ('Desk Lamp', 'Adjustable warm and cool lighting', 45.00),
    ('Notebook', 'A5 dotted notebook, 160 pages', 8.50),
    ('Monitor Stand', 'Solid wood desktop riser', 54.00),
    ('Laptop Sleeve', 'Protective sleeve for 14-inch laptops', 19.90),
    ('Water Bottle', 'Insulated stainless steel, 500 ml', 18.00),
    ('Desk Mat', 'Large soft-touch workspace mat', 15.00),
    ('Cable Organizer', 'Keep cables tidy and within reach', 6.50),
    ('Webcam', 'Full HD camera with privacy shutter', 49.90),
    ('Headphones', 'Comfortable over-ear wired headphones', 65.00);

COMMIT;
