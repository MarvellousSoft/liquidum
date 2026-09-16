// src/engine/RandomLevelGenerator.ts

import { RandomNumberGenerator } from '../model/RandomNumberGenerator';
import { Vector2i } from './Math';
import { LoadMode } from './Grid';
import { GridImpl } from './GridImpl';
import { GeneratorOptions } from './Generator';
import { SolverModel, SolveResult } from './Solver';

export const MAX_TIME_PER_SOLVE = 30.0;

export class RandomLevelGenerator {
    cancel_gen: boolean = false;
    success_state: bigint = 0n;

    cancel(): void {
        this.cancel_gen = true;
    }

    _inner_gen_level(
        rng: RandomNumberGenerator,
        gen_size: (rng: RandomNumberGenerator) => Vector2i,
        apply_hints: (rng: RandomNumberGenerator, grid: GridImpl) => void,
        gen_options_builder: (rng: RandomNumberGenerator) => GeneratorOptions,
        strategies: string[],
        forced_strategies: string[],
        force_boats: boolean
    ): GridImpl | null {
        let g: GridImpl | null = null;
        const solver = new SolverModel();
        let found = false;
        let tries = 0;

        for (let i = 0; i < 1000; i++) {
            if (this.cancel_gen) {
                break;
            }
            this.success_state = rng.get_state();
            const sz = gen_size(rng);
            // In GDScript 4, arguments to .build(rng.randi()) are evaluated before the callee expression gen_options_builder.call(rng)
            const rseed = rng.randi();
            const opts = gen_options_builder(rng);
            g = opts.build(rseed).generate(sz.x, sz.y);
            if (force_boats && g.count_boats() === 0) {
                continue;
            }
            g.set_auto_update_hints(false);
            apply_hints(rng, g);
            tries += 1;

            if (forced_strategies && forced_strategies.length > 0) {
                const g2 = GridImpl.import_data(g.export_data(), LoadMode.Solution);
                if (solver.can_solve_with_strategies(g2, strategies, forced_strategies)) {
                    g2.force_editor_mode();
                    g2.clear_content();
                    solver.apply_strategies(g2, [...strategies, ...forced_strategies]);
                    g2.force_editor_mode(false);
                    g = g2;
                    found = true;
                    break;
                }
            } else {
                g.clear_content();
                const g2 = GridImpl.import_data(g.export_data(), LoadMode.Testing);
                const start_solve = Date.now();
                const cancel_fn = () => this.cancel_gen || (Date.now() - start_solve > MAX_TIME_PER_SOLVE * 1000);
                if (solver.full_solve(g2, strategies, cancel_fn) === SolveResult.SolvedUnique) {
                    g = GridImpl.import_data(g2.export_data(), LoadMode.SolutionNoClear);
                    found = true;
                    break;
                }
            }
        }
        return found ? g : null;
    }

    async generate(
        rng: RandomNumberGenerator,
        n: number,
        m: number,
        apply_hints: (rng: RandomNumberGenerator, grid: GridImpl) => void,
        gen_options_builder: (rng: RandomNumberGenerator) => GeneratorOptions,
        strategies: string[],
        forced_strategies: string[],
        force_boats: boolean = false
    ): Promise<GridImpl | null> {
        return this.generate_with_size(
            rng,
            () => new Vector2i(n, m),
            apply_hints,
            gen_options_builder,
            strategies,
            forced_strategies,
            force_boats
        );
    }

    async generate_with_size(
        rng: RandomNumberGenerator,
        gen_size: (rng: RandomNumberGenerator) => Vector2i,
        apply_hints: (rng: RandomNumberGenerator, grid: GridImpl) => void,
        gen_options_builder: (rng: RandomNumberGenerator) => GeneratorOptions,
        strategies: string[],
        forced_strategies: string[],
        force_boats: boolean = false
    ): Promise<GridImpl | null> {
        this.cancel_gen = false;
        return this._inner_gen_level(
            rng,
            gen_size,
            apply_hints,
            gen_options_builder,
            strategies,
            forced_strategies,
            force_boats
        );
    }
}
