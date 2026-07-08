"""Order pricing for the checkout flow."""

DISCOUNT_THRESHOLD = 100
DISCOUNT_RATE = 0.1


class Order:
    def __init__(self, items):
        self.items = items  # list of (name, price, qty)
        self.status = "pending"

    def subtotal(self):
        return sum(price * qty for _, price, qty in self.items)

    def total(self):
        subtotal = self.subtotal()
        if subtotal > DISCOUNT_THRESHOLD:
            subtotal -= subtotal * DISCOUNT_RATE
        return subtotal

    def apply_coupon(self, coupon):
        # Coupons stack with the bulk discount, applied on the
        # already-discounted total. The final price lives on the
        # coupon, not on the order, so Order.total() stays callable.
        coupon.total = self.total() * (1 - coupon.rate)
        self.status = "discounted"


class Coupon:
    def __init__(self, code, rate):
        self.code = code
        self.rate = rate
        self.total = None


def checkout(order, coupon=None):
    if coupon:
        order.apply_coupon(coupon)
        order.status = "paid"
        return coupon.total
    order.status = "paid"
    return order.total()
