import { describe, test, expect } from 'vitest';
import { RandomNumberGenerator } from '../src/model/RandomNumberGenerator';

/* Generated with this Godot Script. New script, save this a press Ctrl+Shift+X
@tool
extends EditorScript

func _run() -> void:
	var rng = RandomNumberGenerator.new()
	var seeds = [0, 1, 42, 123456789]
	var output = "const EXPECTED_RNG_OUTPUTS: Record<number, { randi: number[], randf: number[], randi_range: number[], randf_range: number[], more_randi: number[] }> = {\n"
	for s in seeds:
		rng.seed = s
		output += "\t%d: {\n" % s
		output += "\t\t'randi': [%d, %d, %d],\n" % [rng.randi(), rng.randi(), rng.randi()]
		output += "\t\t'randf': [%.15f, %.15f, %.15f],\n" % [rng.randf(), rng.randf(), rng.randf()]
		output += "\t\t'randi_range': [%d, %d, %d],\n" % [rng.randi_range(1, 10), rng.randi_range(100, 200), rng.randi_range(-5, 5)]
		output += "\t\t'randf_range': [%.15f, %.15f, %.15f],\n" % [rng.randf_range(1, 10), rng.randf_range(10, 100), rng.randf_range(-20, 20)]
		output += "\t\t'more_randi': ["
		for i in range(49):
			output += "%d, " % [rng.randi()]
		output += "%d],\n" % [rng.randi()]
		output += "\t},\n"
	output += "}\n"
	print(output)
*/
const EXPECTED_RNG_OUTPUTS: Record<number, { randi: number[], randf: number[], randi_range: number[], randf_range: number[], more_randi: number[] }> = {
	0: {
		'randi': [881477183, 1327520283, 692503688],
		'randf': [0.976464569568634, 0.712012529373169, 0.964393675327301],
		'randi_range': [4, 159, 5],
		'randf_range': [7.378537654876709, 56.651794433593750, -16.810110092163086],
		'more_randi': [612535561, 3983555507, 901953063, 2578460718, 2328966244, 2106662877, 2169385747, 2736371643, 3930532134, 2847396433, 3368674568, 359883246, 3956581145, 2651648658, 938194579, 3456938789, 3713907842, 421891202, 2923081036, 2807229934, 3807083666, 1271953603, 999655542, 2605922550, 1264801581, 1855314982, 609906380, 1434450858, 1995070117, 3910766905, 353758906, 2589700904, 986845749, 142336057, 808161123, 1953011393, 3065620324, 4021316334, 307677251, 2767522266, 2361366243, 4222007805, 1557392341, 3813155557, 1482777009, 538889631, 3041165427, 1782732587, 3826297300, 22519480],
	},
	1: {
		'randi': [1811587497, 683407368, 2033395789],
		'randf': [0.668996810913086, 0.789748013019562, 0.139845073223114],
		'randi_range': [8, 134, 3],
		'randf_range': [7.057888031005859, 76.120979309082031, -17.020332336425781],
		'more_randi': [2594448518, 1916920053, 2543241777, 3272935010, 3189708149, 1579087375, 317151972, 2561236505, 4289455902, 3125293265, 4289109196, 3229339472, 3825412424, 3168620261, 2755978232, 1473070344, 2287712944, 826935087, 1586872521, 3771979814, 2302216427, 2427225293, 2181802152, 1409193875, 2972711971, 76353962, 1795144541, 3175632138, 1465208249, 27709818, 3496480926, 3312207281, 3612509657, 382183026, 686330428, 1544580618, 4239833035, 2959303253, 3913791412, 3051496438, 635983636, 1010110664, 2735238547, 2928369464, 818976287, 274889881, 2566180091, 4141738673, 521711999, 3388083426],
	},
	42: {
		'randi': [492690617, 1919685028, 3561993920],
		'randf': [0.193900793790817, 0.068977333605289, 0.108732931315899],
		'randi_range': [2, 130, 0],
		'randf_range': [9.435955047607422, 19.118156433105469, -12.845755577087402],
		'more_randi': [2160814011, 4159442378, 231587883, 1928126881, 210467999, 1796112158, 62880104, 3816579799, 3950972827, 1040650675, 3465205661, 3630864215, 1785929563, 3949348074, 3125352777, 644201059, 1880694512, 95968067, 2512851934, 3295317029, 1856217290, 2112908573, 3378497054, 1837459106, 2519870220, 963213795, 2706952389, 693790815, 538966447, 1724751924, 2585469828, 120423510, 3592459950, 4184012234, 2531511823, 645153842, 1974425390, 3806117216, 1457503418, 1971130952, 1721086484, 1151723520, 833950247, 1601179396, 2637998531, 3658392947, 3681576867, 349051673, 2859268670, 505655986],
	},
	123456789: {
		'randi': [1712221112, 557107306, 1131688667],
		'randf': [0.002811592305079, 0.407569468021393, 0.638821005821228],
		'randi_range': [10, 187, 4],
		'randf_range': [6.833880901336670, 18.450220108032227, -9.013861656188965],
		'more_randi': [4026917746, 2444194610, 1557705412, 32912260, 3091683398, 2854185317, 2810975961, 1162360072, 2626228177, 3440790760, 240055506, 2079555004, 1454351119, 149517140, 493464540, 1934279561, 871258953, 621642318, 977691699, 660854958, 123739163, 211445127, 2551236301, 1452613773, 4176705767, 3870516084, 277502039, 3504923242, 60423784, 1252853587, 3763012952, 584406286, 536552948, 3876157865, 950594307, 249556234, 3032971362, 3721041907, 1027000417, 427571214, 1419880919, 1919681522, 2012453255, 3166285353, 2600208276, 4291288185, 969179667, 3791978654, 227630509, 3388982579],
	},
}



describe('RandomNumberGenerator', () => {
	test('matches Godot outputs exactly', () => {
		for (const [seedStr, expected] of Object.entries(EXPECTED_RNG_OUTPUTS)) {
			const seed = parseInt(seedStr);
			const rng = new RandomNumberGenerator(seed);

			// Test randi
			for (const expectedRandi of expected.randi) {
				expect(rng.randi()).toBe(expectedRandi);
			}

			// Test randf - use closeTo because of potential float precision differences in formatting
			for (const expectedRandf of expected.randf) {
				expect(rng.randf()).toBeCloseTo(expectedRandf, 10);
			}

			// Test randi_range
			expect(rng.randi_range(1, 10)).toBe(expected.randi_range[0]);
			expect(rng.randi_range(100, 200)).toBe(expected.randi_range[1]);
			expect(rng.randi_range(-5, 5)).toBe(expected.randi_range[2]);

			expect(rng.randf_range(1, 10)).toBeCloseTo(expected.randf_range[0], 5);
			expect(rng.randf_range(10, 100)).toBeCloseTo(expected.randf_range[1], 5);
			expect(rng.randf_range(-20, 20)).toBeCloseTo(expected.randf_range[2], 5);

			for (const expectedMoreRandi of expected.more_randi) {
				expect(rng.randi()).toBe(expectedMoreRandi);
			}
		}
	});
});
