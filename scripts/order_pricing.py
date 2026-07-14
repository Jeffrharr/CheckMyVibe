"""Order pricing for the checkout flow."""

DISCOUNT_THRESHOLD = 100
DISCOUNT_RATE = 0.1


class Order:
    def __init__(self, items):
        self.items = items  # list of (name, price, qty)
        self.status = "pending"

    def subtotal(self):
        return max(sum(price * qty for _, price, qty in self.items), 0)

    def total(self):
        subtotal = self.subtotal()
        if subtotal >= DISCOUNT_THRESHOLD:
            subtotal -= subtotal * DISCOUNT_RATE
        return subtotal


class Coupon:
    def __init__(self, code, rate):
        self.code = code
        self.rate = rate
        self.total = None


def price_order(order, coupon=None):
    """Pure business logic: bulk discount, then coupon stacked on top. No side effects."""
    total = order.total()
    if coupon is not None:
        total *= 1 - coupon.rate
    return total


def checkout(order, coupon=None):
    price = price_order(order, coupon)
    if coupon is not None:
        coupon.total = price
    order.status = "paid"
    return price
