import { describe, it, expect } from 'vitest';
import fs from 'node:fs';
import path from 'node:path';

describe('E2E Test Architecture Safeguards', () => {
  const e2eDir = path.resolve(__dirname, '../e2e');

  it('ensures all e2e test files import test from ./fixtures to guarantee PlayFab blocking', () => {
    const files = fs.readdirSync(e2eDir).filter((file) => file.endsWith('.spec.ts'));
    expect(files.length).toBeGreaterThan(0);

    const violations: string[] = [];

    for (const file of files) {
      const fullPath = path.join(e2eDir, file);
      const content = fs.readFileSync(fullPath, 'utf-8');

      // Check if file imports test directly from @playwright/test
      if (/import\s+{[^}]*\btest\b[^}]*}\s+from\s+['"]@playwright\/test['"]/.test(content)) {
        violations.push(
          `${file} imports "test" from "@playwright/test". It must import from "./fixtures" to ensure PlayFab access is safely blocked.`
        );
      }

      // Check that it imports from ./fixtures
      if (!/from\s+['"]\.\/fixtures['"]/.test(content)) {
        violations.push(
          `${file} must import { test, expect } from "./fixtures" to guarantee automatic PlayFab network interception.`
        );
      }
    }

    expect(violations).toEqual([]);
  });
});
