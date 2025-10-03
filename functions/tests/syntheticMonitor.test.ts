import {describe, expect, it} from "vitest";
import {
  parseExpectedStatusCodes,
  parseSyntheticTimeout,
} from "../src/index.js";

describe("parseSyntheticTimeout", () => {
  it("returns fallback for invalid values", () => {
    expect(parseSyntheticTimeout(undefined, 3000)).toBe(3000);
    expect(parseSyntheticTimeout("", 2000)).toBe(2000);
    expect(parseSyntheticTimeout("abc", 1500)).toBe(1500);
    expect(parseSyntheticTimeout("-5", 1200)).toBe(1200);
  });

  it("clamps to the maximum allowed timeout", () => {
    expect(parseSyntheticTimeout("120000", 5000)).toBe(60000);
  });

  it("parses valid integers", () => {
    expect(parseSyntheticTimeout("4500", 5000)).toBe(4500);
  });
});

describe("parseExpectedStatusCodes", () => {
  it("returns null when the input is empty or invalid", () => {
    expect(parseExpectedStatusCodes()).toBeNull();
    expect(parseExpectedStatusCodes(" ")).toBeNull();
    expect(parseExpectedStatusCodes("foo,bar")).toBeNull();
  });

  it("extracts numeric status codes", () => {
    const result = parseExpectedStatusCodes("200, 204,500");
    expect(result).not.toBeNull();
    expect(Array.from(result!)).toEqual([200, 204, 500]);
  });

  it("ignores numbers outside the HTTP range", () => {
    const result = parseExpectedStatusCodes("99,600,200");
    expect(result).not.toBeNull();
    expect(Array.from(result!)).toEqual([200]);
  });
});
