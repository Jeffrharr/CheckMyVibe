# Checkout Pricing

Domain language for order pricing and discounts.

## Language

**Order**: a cart of items being priced and paid for. Owns its own subtotal, bulk discount, and coupon logic.
_Avoid_: Cart, Purchase

**Coupon**: a named, single-rate discount applied on top of an Order's already-bulk-discounted total (see [ADR-0001](./docs/adr/0001-coupons-stack-on-discounted-total.md)).
_Avoid_: Promo, Voucher

**Bulk discount**: the automatic percentage reduction applied once subtotal crosses `DISCOUNT_THRESHOLD`. Distinct from a Coupon — it requires no code and cannot be combined with a second bulk discount.
