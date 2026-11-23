package calc

import (
	"testing"
	"time"
)

func TestAdd(t *testing.T) {
	got := Add(2, 3)
	if got != 5 {
		t.Fatalf("Add(2,3)=%d want 5", got)
	}
}

func TestSquareFails(t *testing.T) {
	got := Square(3)
	if got != 10 {
		t.Errorf("Square(3)=%d want 10", got)
	}
}

func TestTable(t *testing.T) {
	cases := []struct {
		name string
		a, b int
		want int
	}{
		{"small", 1, 2, 3},
		{"zero", 0, 0, 0},
		{"wrong", 2, 2, 5},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if got := Add(c.a, c.b); got != c.want {
				t.Errorf("got %d want %d", got, c.want)
			}
		})
	}
}

func TestNested(t *testing.T) {
	t.Run("outer", func(t *testing.T) {
		t.Run("inner", func(t *testing.T) {
			t.Log("inner log line")
		})
	})
}

func TestSkipped(t *testing.T) {
	t.Skip("not today")
}

func TestSlow(t *testing.T) {
	time.Sleep(1500 * time.Millisecond)
}

func TestPanics(t *testing.T) {
	_ = Div(1, 0)
}

func BenchmarkAdd(b *testing.B) {
	for i := 0; i < b.N; i++ {
		Add(i, i)
	}
}
