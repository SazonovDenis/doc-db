CREATE TABLE customers (
    id    bigint PRIMARY KEY,
    name  varchar(100) NOT NULL,
    email varchar(100)
);

CREATE TABLE warehouses (
    id   bigint PRIMARY KEY,
    city varchar(50) NOT NULL
);

CREATE TABLE orders (
    id           bigint PRIMARY KEY,
    customer_id  bigint NOT NULL REFERENCES customers (id),
    warehouse_id bigint REFERENCES warehouses (id),
    status       varchar(20) NOT NULL,
    created_at   timestamptz NOT NULL
);

CREATE TABLE payments (
    id       bigint PRIMARY KEY,
    order_id bigint NOT NULL REFERENCES orders (id),
    method   varchar(10) NOT NULL,
    amount   numeric(10,2) NOT NULL
);
