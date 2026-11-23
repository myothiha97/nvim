const { mul } = require("./calc");
describe("calc", () => {
  test("mul ok", () => {
    expect(mul(2, 3)).toBe(6);
  });
  test("mul fails", () => {
    expect(mul(2, 2)).toBe(5);
  });
});
