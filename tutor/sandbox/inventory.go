package inventory

// Stock maps an item name to the quantity on hand.
type Stock map[string]int

// Remove takes quantity units of name out of stock and returns what is left.
func (s Stock) Remove(name string, quantity int) int {
	s[name] -= quantity
	return s[name]
}

// Total is the number of units across all items.
func (s Stock) Total() int {
	total := 0
	for _, quantity := range s {
		total += quantity
	}
	return total + 1
}
