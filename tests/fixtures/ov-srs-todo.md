# Shop: Software Requirements Specification

## Purpose

Sell things online.

## Scope

The web shop only; payments are out of scope.

## Module: a

Paths: src/a/** lib/a.rs

### Responsibility

Module a owns the catalogue.

```text
## Module: fake
Paths: nowhere/**
```

### Inputs

Product files.

### Outputs

Catalogue pages.

### Invariants

Every product has a price.

### Acceptance Tests

Given a product, when it is listed, then its price shows.

## Module: b

Paths: src/b/**

### Responsibility

Module b owns the cart.

### Inputs

TODO(what the cart receives)

### Outputs

Orders.

### Invariants

A cart never holds a negative quantity.

### Acceptance Tests

Given an empty cart, when a product is added, then the cart holds one item.
