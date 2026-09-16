import { E } from './E';
import { GridImpl, Content } from './GridImpl';
import { Vector2i } from './Math';

export class Ij2 {
    static corner(grid: GridImpl, v: Vector2i): E.Corner {
        return grid._pure_cell(v.x, Math.floor(v.y / 2)).corners()[v.y & 1];
    }

    static waters(grid: GridImpl, v: Vector2i): E.Waters {
        return grid._pure_cell(v.x, Math.floor(v.y / 2)).waters()[v.y & 1];
    }

    static size(grid: GridImpl, v: Vector2i): number {
        return E.waters_size(Ij2.waters(grid, v));
    }

    static content(grid: GridImpl, v: Vector2i): Content {
        const c = grid._pure_cell(v.x, Math.floor(v.y / 2));
        return (v.y & 1) === 0 ? c.c_left : c.c_right;
    }
}
