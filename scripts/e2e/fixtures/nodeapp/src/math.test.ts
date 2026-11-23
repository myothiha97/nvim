import { describe, it, expect } from "vitest";
import { square, sum } from "./math";

describe("math", () => {
  it("squares", () => {
    expect(square(3)).toBe(9);
  });
  it("fails on purpose", () => {
    expect(square(3)).toBe(10);
  });
  describe("nested", () => {
    it.each([[1, 1], [2, 4]])("square(%i) = %i", (a, b) => {
      expect(square(a)).toBe(b);
    });
  });
  it.skip("skipped", () => {});
});

it("sums top-level", () => {
  expect(sum([1, 2, 3])).toBe(6);
});
