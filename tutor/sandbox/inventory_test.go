package inventory

import "testing"

func TestRemove(t *testing.T) {
	stock := Stock{"cable": 5}
	if left := stock.Remove("cable", 2); left != 3 {
		t.Errorf("Remove left %d, want 3", left)
	}
}

func TestTotal(t *testing.T) {
	stock := Stock{"cable": 5, "keyboard": 2}
	if got := stock.Total(); got != 7 {
		t.Errorf("Total() = %d, want 7", got)
	}
}
