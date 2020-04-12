CREATE DATABASE otus;
\c otus;
CREATE TABLE users (
  id int PRIMARY KEY,
  name varchar
);
CREATE TABLE products (
  id int PRIMARY KEY,
  name varchar,
  user_id int REFERENCES users (id)
);