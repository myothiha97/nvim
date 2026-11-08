package main

import (
	"errors"
	"strings"
	"testing"
)

// Code under test lives in this file so it works in any package main folder.
// Delete the file when you're done.

var errInsufficientFunds = errors.New("insufficient funds")

func applyDebit(balance, amount int64) (int64, error) {
	if amount <= 0 {
		return balance, errors.New("amount must be positive")
	}
	if amount > balance {
		return balance, errInsufficientFunds
	}
	return balance - amount, nil
}

func normalizeCurrency(code string) string {
	return strings.ToUpper(strings.TrimSpace(code))
}

// Passes. Table-driven with subtests: each case is its own node in the summary.
func TestApplyDebit(t *testing.T) {
	tests := []struct {
		name    string
		balance int64
		amount  int64
		want    int64
		wantErr error
	}{
		{"normal debit", 1000, 250, 750, nil},
		{"exact balance", 500, 500, 0, nil},
		{"insufficient funds", 100, 101, 100, errInsufficientFunds},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := applyDebit(tt.balance, tt.amount)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("err = %v, want %v", err, tt.wantErr)
			}
			if got != tt.want {
				t.Errorf("balance = %d, want %d", got, tt.want)
			}
		})
	}
}

// Fails on purpose in ONE subtest ("lowercase with spaces" expects the wrong value).
// Use it for Rerun Failed: fix the expected value to "USD" and press <leader>tF again.
func TestNormalizeCurrency(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{"already upper", "EUR", "EUR"},
		{"lowercase with spaces", "  usd ", "usd"}, // wrong on purpose: should be "USD"
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := normalizeCurrency(tt.in); got != tt.want {
				t.Errorf("normalizeCurrency(%q) = %q, want %q", tt.in, got, tt.want)
			}
		})
	}
}

// Fails on purpose (top-level, no subtests).
func TestRejectsZeroAmount(t *testing.T) {
	_, err := applyDebit(1000, 0)
	if err != nil { // wrong on purpose: should be err == nil
		t.Fatalf("expected an error for zero amount, got %v", err)
	}
}

// Skipped: shows the skipped icon.
func TestSlowIntegration(t *testing.T) {
	t.Skip("needs a database")
}

// Good for Debug Test: set a breakpoint on the `total +=` line and step.
func TestSumDebits(t *testing.T) {
	balance := int64(1000)
	total := int64(0)
	for _, amount := range []int64{100, 200, 300} {
		var err error
		balance, err = applyDebit(balance, amount)
		if err != nil {
			t.Fatal(err)
		}
		total += amount
	}
	if balance != 400 || total != 600 {
		t.Errorf("balance=%d total=%d, want 400 and 600", balance, total)
	}
}
