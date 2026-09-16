import { describe, test, expect } from 'vitest';
import { E } from '../src/engine/E';
import { GridImpl, Content } from '../src/engine/GridImpl';
import { LoadMode } from '../src/engine/Grid';

const TopLeft = E.Corner.TopLeft;
const TopRight = E.Corner.TopRight;
const BottomLeft = E.Corner.BottomLeft;
const BottomRight = E.Corner.BottomRight;

function cleanGridStr(s: string): string {
    const lines = s.replace(/\r/g, '').split('\n');
    while (lines.length > 0 && lines[0].trim() === '') lines.shift();
    while (lines.length > 0 && lines[lines.length - 1].trim() === '') lines.pop();
    if (lines.length === 0) return '';
    const indents = lines.filter(l => l.length > 0).map(l => l.match(/^(\s*)/)![1].length);
    const minIndent = Math.min(...indents);
    return lines.map(l => l.slice(minIndent).trimEnd()).join('\n');
}

function assert_grid_eq(a: string, b: string): void {
    expect(cleanGridStr(a)).toBe(cleanGridStr(b));
}

function str_grid(s: string): GridImpl {
    const g = GridImpl.from_str(s, LoadMode.Testing);
    return g;
}

describe('Undo / Redo System', () => {
    test('initial state has can_undo=false and can_redo=false', () => {
        const g = str_grid("..\nL╲");
        expect(g.can_undo()).toBe(false);
        expect(g.can_redo()).toBe(false);
        expect(g.undo()).toBe(false);
        expect(g.redo()).toBe(false);
    });

    test('water put, undo and redo updates can_undo and can_redo', () => {
        const initial = "..\nL╲";
        const g = str_grid(initial);
        g.get_cell(0, 0).put_water(TopRight);
        expect(g.can_undo()).toBe(true);
        expect(g.can_redo()).toBe(false);
        assert_grid_eq(g.to_str(), ".w\nL╲");

        // Undo
        expect(g.undo()).toBe(true);
        assert_grid_eq(g.to_str(), initial);
        expect(g.can_undo()).toBe(false);
        expect(g.can_redo()).toBe(true);

        // Redo
        expect(g.redo()).toBe(true);
        expect(g.can_undo()).toBe(true);
        expect(g.can_redo()).toBe(false);
        assert_grid_eq(g.to_str(), ".w\nL╲");
    });

    test('new action invalidates redo stack', () => {
        const g = str_grid("..\nL╲");
        g.get_cell(0, 0).put_water(TopRight);
        g.undo();
        expect(g.can_redo()).toBe(true);

        // Placing air clears redo stack
        g.get_cell(0, 0).put_nowater(BottomLeft);
        expect(g.can_redo()).toBe(false);
        expect(g.redo()).toBe(false);
    });

    test('drag stroke grouping undoes multiple cells in a single undo step', () => {
        const initial = "....\nL._.";
        const g = str_grid(initial);

        // Start stroke: push_empty_undo
        g.push_empty_undo();
        // Drag cell 0,0 then cell 0,1 with flush_undo=false
        g.get_cell(0, 0).put_nowater(BottomLeft, false);
        g.get_cell(0, 1).put_nowater(BottomLeft, false);

        expect(g.can_undo()).toBe(true);
        assert_grid_eq(g.to_str(), "xxxx\nL._.");

        // Single undo reverts BOTH cells
        expect(g.undo()).toBe(true);
        assert_grid_eq(g.to_str(), initial);
        expect(g.can_undo()).toBe(false);
        expect(g.can_redo()).toBe(true);

        // Redo restores both cells
        expect(g.redo()).toBe(true);
        assert_grid_eq(g.to_str(), "xxxx\nL._.");
    });

    test('multiple sequential moves can be undone and redone in order', () => {
        const initial = "..\nL╲";
        const g = str_grid(initial);

        // Move 1
        g.get_cell(0, 0).put_water(TopRight);
        assert_grid_eq(g.to_str(), ".w\nL╲");

        // Move 2
        g.get_cell(0, 0).put_water(BottomLeft);
        assert_grid_eq(g.to_str(), "ww\nL╲");

        expect(g.can_undo()).toBe(true);
        // Undo move 2
        expect(g.undo()).toBe(true);
        assert_grid_eq(g.to_str(), ".w\nL╲");

        // Undo move 1
        expect(g.undo()).toBe(true);
        assert_grid_eq(g.to_str(), initial);
        expect(g.can_undo()).toBe(false);

        // Redo move 1
        expect(g.redo()).toBe(true);
        assert_grid_eq(g.to_str(), ".w\nL╲");

        // Redo move 2
        expect(g.redo()).toBe(true);
        assert_grid_eq(g.to_str(), "ww\nL╲");
        expect(g.can_redo()).toBe(false);
    });

    test('boat placement undo and redo', () => {
        const g = str_grid(`
+boats=1
B.......
.h......
1.......
........
.6......
......_.
........
........
`);
        expect(g.get_cell(0, 1).put_boat()).toBe(true);
        expect(g.get_cell(0, 1).has_boat()).toBe(true);
        expect(g.can_undo()).toBe(true);

        g.undo();
        expect(g.get_cell(0, 1).has_boat()).toBe(false);
        expect(g.can_redo()).toBe(true);

        g.redo();
        expect(g.get_cell(0, 1).has_boat()).toBe(true);
    });
});
