import { describe, test, expect } from 'vitest';
import { E } from '../src/engine/E';
import { GridImpl } from '../src/engine/GridImpl';
import { LoadMode } from '../src/engine/Grid';

describe('inspect user level', () => {
    test('check level data', () => {
        const jsonStr = '{"0":2,"11":[{"4":-1,"5":0,"6":-1,"7":0},{"4":2,"5":0,"6":-1,"7":0},{"4":8,"5":0,"6":-1,"7":0},{"4":-1,"5":2,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0}],"12":[{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":2,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":2,"5":0,"6":-1,"7":0},{"4":-1,"5":2,"6":-1,"7":0},{"4":3,"5":0,"6":-1,"7":0}],"13":[[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11}],[{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11}],[{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11}],[{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11}]],"14":[[1,1,1,1,1,1,1,1,1],[0,0,1,1,1,1,1,0,0],[0,1,0,1,1,1,1,1,1],[1,0,0,0,0,1,0,1,1],[1,1,0,1,1,0,1,0,0],[1,1,0,0,0,1,1,1,0]],"15":[[0,1,0,0,1,0,1,0],[1,1,1,0,1,0,1,1],[1,1,1,1,0,0,1,1],[1,1,1,1,1,0,1,0],[0,1,1,1,1,1,1,0],[0,1,1,1,1,1,0,0],[0,1,1,1,0,1,0,1]],"16":{"8":-1,"9":0,"10":{}},"17":[],"22":[1]}';
        const data = JSON.parse(jsonStr);
        const g = GridImpl.import_data(data, LoadMode.SolutionNoClear);
        console.log("GRID:\n" + g.to_str());
        console.log("TS: are_hints_satisfied:", g.are_hints_satisfied());
        console.log("TS: all_hints_status:", g.all_hints_status());
        for (let i = 0; i < g.rows(); i++) {
            const st = g.get_row_hint_status(i, E.HintContent.Water);
            console.log(`Row ${i}: status=${st}, count=${g.count_water_row(i)}, hintCount=${g.row_hints()[i].water_count}, hintType=${g.row_hints()[i].water_count_type}`);
        }
        for (let j = 0; j < g.cols(); j++) {
            const st = g.get_col_hint_status(j, E.HintContent.Water);
            console.log(`Col ${j}: status=${st}, count=${g.count_water_col(j)}, hintCount=${g.col_hints()[j].water_count}, hintType=${g.col_hints()[j].water_count_type}`);
        }
        const DIRS = [[1, 0], [0, -1], [-1, 0], [0, 1]];
        function snake_nbhs(ij: [number, number]): number {
            let ct = 0;
            for (const d of DIRS) {
                const ni = ij[0] + d[0], nj = ij[1] + d[1];
                if (ni >= 0 && ni < g.rows() && nj >= 0 && nj < g.cols()) {
                    if (g.get_cell(ni, nj).water_full()) ct++;
                }
            }
            return ct;
        }
        function snake_dfs(ij: [number, number], pij: [number, number]): [number, number, number] {
            for (const d of DIRS) {
                const ni = ij[0] + d[0], nj = ij[1] + d[1];
                if ((ni !== pij[0] || nj !== pij[1]) && ni >= 0 && ni < g.rows() && nj >= 0 && nj < g.cols()) {
                    if (g.get_cell(ni, nj).water_full()) {
                        const r = snake_dfs([ni, nj], ij);
                        return [r[0] + 1, r[1], r[2]];
                    }
                }
            }
            return [1, ij[0], ij[1]];
        }
        const deg_1s: [number, number][] = [];
        let deg_0s = 0;
        let water_count = 0;
        for (let i = 0; i < g.rows(); i++) {
            for (let j = 0; j < g.cols(); j++) {
                if (g.get_cell(i, j).water_full()) {
                    water_count++;
                    const ct = snake_nbhs([i, j]);
                    if (ct === 0) deg_0s++;
                    else if (ct === 1) deg_1s.push([i, j]);
                    else if (ct > 2) console.log(`ct > 2 at (${i},${j}): ${ct}`);
                }
            }
        }
        console.log(`water_count: ${water_count}, deg_0s: ${deg_0s}, deg_1s: ${deg_1s.length} (${JSON.stringify(deg_1s)})`);
        let in_paths = 2 * deg_0s;
        for (const ij of deg_1s) {
            const r = snake_dfs(ij, ij);
            in_paths += r[0];
            console.log(`dfs from (${ij[0]},${ij[1]}): path length ${r[0]}, other end (${r[1]},${r[2]})`);
        }
        console.log(`in_paths: ${in_paths}, expected 2*water_count: ${water_count * 2}`);
    });
});
