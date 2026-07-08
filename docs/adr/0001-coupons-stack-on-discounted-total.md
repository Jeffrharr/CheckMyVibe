# Coupons stack on top of the bulk discount, not the original subtotal

`Order.apply_coupon` applies a `Coupon`'s rate to `self.total()` — the
already-bulk-discounted amount — rather than to the raw subtotal. We decided
coupons should compound with the bulk discount instead of being mutually
exclusive or applying to pre-discount price, since this most benefits
loyal high-spend customers and matches how the two discount paths were built
independently. Rejected alternative: applying the coupon to the raw subtotal
and taking whichever discount is larger, which is simpler but caps total
savings and was judged less generous than intended.

## Discount threshold is inclusive

A subtotal of exactly `DISCOUNT_THRESHOLD` ($100) qualifies for the bulk
discount (`>=`, not `>`) — the threshold is a floor customers can reach, not
a strict minimum they must exceed.

## Subtotal is floored at $0

Subtotal is floored at `$0` before discounting, so refund-like negative
price/qty entries in `items` can't produce a negative subtotal that the
discount math would otherwise amplify.
