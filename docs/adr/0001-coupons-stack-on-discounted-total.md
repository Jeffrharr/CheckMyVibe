# Coupons stack on top of the bulk discount, not the original subtotal

`Order.apply_coupon` applies a `Coupon`'s rate to `self.total()` — the
already-bulk-discounted amount — rather than to the raw subtotal. We decided
coupons should compound with the bulk discount instead of being mutually
exclusive or applying to pre-discount price, since this most benefits
loyal high-spend customers and matches how the two discount paths were built
independently. Rejected alternative: applying the coupon to the raw subtotal
and taking whichever discount is larger, which is simpler but caps total
savings and was judged less generous than intended.
