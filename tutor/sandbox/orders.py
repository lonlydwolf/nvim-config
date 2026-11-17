import os
import sys
from dataclasses import dataclass


@dataclass
class Item:
    name: str
    price: float
    quantity: int = 1

    def total(self) -> float:
        return self.price * self.quantity


class Order:
    customer: str
    items: list[Item]

    def __init__(self, customer: str, items: list[Item]) -> None:
        self.customer = customer
        self.items = items

    def subtotal(self) -> float:
        return sum(item.total() for item in self.items)

    def apply_discount(self, percent: float, minimum: float) -> float:
        amount = self.subtotal()
        if amount < minimum:
            return amount
        return amount * (1 - percent / 100)

    def summary(self) -> str:
        lines = [f"Order for {self.customer}"]
        for item in self.items:
            if item.quantity > 1:
                lines.append(f"  {item.name} x{item.quantity}: {item.total():.2f}")
            else:
                lines.append(f"  {item.name}: {item.total():.2f}")
        lines.append(f"Subtotal: {self.subtotl():.2f}")
        return "\n".join(lines)


def format_price(amount: float, currency: str = "EUR") -> str:
    label = currency.upper()
    return f"{amount:.2f} {lable}"


def main() -> None:
    order = Order("Ada", [Item("keyboard", 80.0), Item("cable", 5.5, 3)])
    totals = {"net":order.subtotal(),   "discounted":order.apply_discount(10,50)}
    print(order.summary())
    print(format_price(totals["discounted"]))


if __name__ == "__main__":
    main()
