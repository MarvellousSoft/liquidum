import { h } from 'preact';
import { useState, useEffect, useRef } from 'preact/hooks';
import { Grid } from './components/Grid';
import { parseGridData, Content, CellType, Corner, isLevelComplete, countWaterRow, countBoatRow, getAquariums, levelHasBoats } from './model/GridData';
import type { GridModelData } from './model/GridData';

const LEVELS: Record<string, any> = {
  "Level 01/01": { "description": "FIRST_LEVEL_DESCRIPTION", "full_name": "LEVEL_01_01", "grid_data": { "0": 1, "11": [{ "4": 2, "5": 0, "6": -1, "7": 0 }, { "4": 1, "5": 0, "6": -1, "7": 0 }, { "4": 3, "5": 0, "6": -1, "7": 0 }], "12": [{ "4": 1, "5": 0, "6": -1, "7": 0 }, { "4": 2, "5": 0, "6": -1, "7": 0 }, { "4": 3, "5": 0, "6": -1, "7": 0 }], "13": [[{ "1": 2, "2": 2, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 2, "2": 2, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }]], "14": [[1, 1, 1], [1, 1, 1]], "15": [[1, 1], [1, 1], [1, 1]], "16": { "8": -1, "9": 0, "10": {} } }, "version": 1, "tutorial": "mouse1" },
  "Level 01/05": { "description": "UNIQUE_SOLUTION_DESCRIPTION", "full_name": "LEVEL_01_05", "grid_data": { "0": 1, "11": [{ "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": 3, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }], "12": [{ "4": 1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": 2, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }], "13": [[{ "1": 1, "2": 1, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 2, "2": 2, "3": 11 }], [{ "1": 2, "2": 2, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 2, "2": 2, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }]], "14": [[1, 0, 1, 0, 1], [0, 0, 0, 1, 0]], "15": [[1, 0, 0, 0], [1, 1, 1, 1], [0, 1, 0, 0]], "16": { "8": 7, "9": 0, "10": {} } }, "version": 1 },
  "Level 02/01": { "full_name": "LEVEL_02_01", "grid_data": { "0": 1, "11": [{ "4": 3, "5": 2, "6": -1, "7": 0 }, { "4": 3, "5": 2, "6": -1, "7": 0 }, { "4": 3, "5": 1, "6": -1, "7": 0 }, { "4": 2, "5": 1, "6": -1, "7": 0 }], "12": [{ "4": 3, "5": 2, "6": -1, "7": 0 }, { "4": 3, "5": 2, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": 3, "5": 1, "6": -1, "7": 0 }], "13": [[{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 2, "2": 2, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 2, "2": 2, "3": 11 }]], "14": [[1, 1, 1, 1], [1, 1, 1, 1], [1, 1, 1, 1]], "15": [[1, 1, 1], [1, 1, 0], [1, 1, 1], [1, 1, 1]], "16": { "8": -1, "9": 0, "10": {} } }, "version": 1, "tutorial": "together_separate" },
  "Level 03/01": { "full_name": "LEVEL_03_01", "grid_data": { "0": 1, "11": [{ "4": 0.5, "5": 0, "6": -1, "7": 0 }, { "4": 1.5, "5": 0, "6": -1, "7": 0 }, { "4": 1, "5": 0, "6": -1, "7": 0 }, { "4": 2.5, "5": 0, "6": -1, "7": 0 }], "12": [{ "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": 1.5, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": 0.5, "5": 0, "6": -1, "7": 0 }], "13": [[{ "1": 1, "2": 2, "3": 9 }, { "1": 2, "2": 2, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 2, "2": 2, "3": 10 }], [{ "1": 1, "2": 1, "3": 10 }, { "1": 1, "2": 2, "3": 9 }, { "1": 2, "2": 2, "3": 10 }, { "1": 2, "2": 2, "3": 11 }], [{ "1": 1, "2": 2, "3": 9 }, { "1": 2, "2": 2, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 2, "2": 1, "3": 10 }], [{ "1": 2, "2": 1, "3": 10 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 2, "2": 2, "3": 11 }]], "14": [[0, 0, 0, 0], [0, 0, 0, 0], [1, 1, 1, 1]], "15": [[0, 0, 0], [0, 0, 0], [0, 1, 0], [0, 0, 1]], "16": { "8": -1, "9": 0, "10": {} } }, "version": 1 },
  "Level 03/07": { "full_name": "LEVEL_03_07", "grid_data": { "0": 1, "11": [{ "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 2, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }], "12": [{ "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 2, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }], "13": [[{ "1": 3, "2": 0, "3": 9 }, { "1": 0, "2": 3, "3": 10 }, { "1": 3, "2": 3, "3": 11 }, { "1": 3, "2": 0, "3": 9 }, { "1": 0, "2": 3, "3": 10 }, { "1": 3, "2": 3, "3": 11 }, { "1": 3, "2": 3, "3": 11 }], [{ "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 3, "3": 9 }], [{ "1": 3, "2": 0, "3": 10 }, { "1": 0, "2": 3, "3": 9 }, { "1": 3, "2": 1, "3": 10 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 3, "3": 9 }, { "1": 0, "2": 0, "3": 11 }, { "1": 3, "2": 3, "3": 11 }], [{ "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 3, "3": 10 }, { "1": 3, "2": 3, "3": 11 }, { "1": 3, "2": 3, "3": 11 }, { "1": 3, "2": 3, "3": 11 }, { "1": 3, "2": 1, "3": 10 }, { "1": 3, "2": 3, "3": 11 }], [{ "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 3, "3": 10 }, { "1": 3, "2": 1, "3": 10 }, { "1": 1, "2": 3, "3": 10 }, { "1": 3, "2": 3, "3": 11 }, { "1": 1, "2": 3, "3": 10 }], [{ "1": 1, "2": 3, "3": 9 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 3, "3": 9 }, { "1": 3, "2": 3, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 3, "3": 9 }], [{ "1": 3, "2": 3, "3": 11 }, { "1": 1, "2": 3, "3": 9 }, { "1": 3, "2": 3, "3": 11 }, { "1": 3, "2": 3, "3": 11 }, { "1": 3, "2": 3, "3": 11 }, { "1": 3, "2": 3, "3": 11 }, { "1": 3, "2": 3, "3": 11 }]], "14": [[0, 0, 1, 0, 0, 1, 1], [0, 0, 0, 0, 0, 0, 1], [1, 1, 1, 1, 1, 0, 1], [0, 0, 1, 1, 1, 1, 1], [0, 0, 0, 1, 0, 1, 0], [1, 0, 1, 1, 1, 1, 1]], "15": [[0, 1, 1, 0, 1, 1], [0, 0, 0, 0, 0, 0], [0, 1, 0, 0, 1, 1], [0, 1, 1, 1, 1, 1], [0, 0, 1, 0, 1, 1], [1, 0, 1, 1, 0, 0], [1, 1, 1, 1, 1, 1]], "16": { "8": -1, "9": 0, "10": {} } }, "version": 1 },
  "Level 04/01": { "full_name": "LEVEL_04_01", "grid_data": { "0": 1, "11": [{ "4": -1, "5": 0, "6": 2, "7": 0 }, { "4": -1, "5": 0, "6": 2, "7": 0 }, { "4": 4.5, "5": 0, "6": -1, "7": 0 }], "12": [{ "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": 1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": 1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }], "13": [[{ "1": 4, "2": 4, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 4, "2": 4, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 4, "2": 4, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 4, "2": 4, "3": 11 }, { "1": 0, "2": 1, "3": 10 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 10 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 0, "3": 10 }]], "14": [[0, 1, 1, 1, 0], [0, 0, 0, 0, 0]], "15": [[0, 0, 0, 0], [1, 0, 0, 1], [0, 0, 0, 0]], "16": { "8": -1, "9": -1, "10": {} } }, "version": 1, "tutorial": "boats" },
  "Level 04/05": { "full_name": "LEVEL_04_05", "grid_data": { "0": 1, "11": [{ "4": 4, "5": 1, "6": -1, "7": 0 }, { "4": 3.5, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }], "12": [{ "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 2, "6": -1, "7": 0 }], "13": [[{ "1": 1, "2": 1, "3": 10 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 4, "2": 4, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 10 }, { "1": 1, "2": 1, "3": 11 }, { "1": 4, "2": 4, "3": 11 }, { "1": 0, "2": 0, "3": 9 }, { "1": 0, "2": 1, "3": 10 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 9 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }]], "14": [[0, 0, 1, 1, 0, 0], [0, 1, 0, 0, 0, 0]], "15": [[0, 1, 0, 1, 0], [0, 0, 1, 1, 0], [1, 0, 1, 0, 0]], "16": { "8": -1, "9": 2, "10": {} } }, "version": 1 },
  "Level 05/01": { "full_name": "LEVEL_05_01", "grid_data": { "0": 1, "11": [{ "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }], "12": [{ "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }], "13": [[{ "1": 1, "2": 1, "3": 10 }, { "1": 1, "2": 1, "3": 9 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 3, "3": 9 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }]], "14": [[0, 0, 0, 0, 0], [1, 1, 1, 0, 1]], "15": [[0, 1, 0, 0], [0, 1, 0, 1], [0, 0, 0, 0]], "16": { "8": -1, "9": 0, "10": { "0": 0, "2.5": 1, "3": 1 } } }, "version": 1 },
  "Level 05/08": { "full_name": "LEVEL_05_08", "grid_data": { "0": 1, "11": [{ "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 2, "6": -1, "7": 0 }], "12": [{ "4": 3, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 0, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }], "13": [[{ "1": 1, "2": 0, "3": 9 }, { "1": 0, "2": 0, "3": 11 }, { "1": 0, "2": 0, "3": 9 }], [{ "1": 0, "2": 0, "3": 11 }, { "1": 4, "2": 4, "3": 11 }, { "1": 4, "2": 4, "3": 11 }], [{ "1": 0, "2": 1, "3": 9 }, { "1": 1, "2": 1, "3": 9 }, { "1": 1, "2": 1, "3": 10 }], [{ "1": 0, "2": 0, "3": 9 }, { "1": 4, "2": 4, "3": 11 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 3, "2": 1, "3": 9 }, { "1": 1, "2": 1, "3": 9 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 1, "2": 1, "3": 10 }, { "1": 1, "2": 1, "3": 10 }, { "1": 1, "2": 0, "3": 9 }], [{ "1": 0, "2": 1, "3": 10 }, { "1": 0, "2": 1, "3": 10 }, { "1": 0, "2": 0, "3": 9 }]], "14": [[0, 1, 0], [0, 0, 0], [1, 1, 0], [1, 0, 0], [1, 0, 0], [0, 0, 0]], "15": [[0, 0], [1, 0], [0, 0], [0, 1], [0, 0], [0, 0], [1, 1]], "16": { "8": -1, "9": 3, "10": { "0.5": 1, "1": 2 } } }, "version": 1 },
  "Level 06/01": { "full_name": "LEVEL_06_01", "grid_data": { "0": 1, "11": [{ "4": -1, "5": 2, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 2, "6": -1, "7": 0 }, { "4": -1, "5": 2, "6": -1, "7": 0 }], "12": [{ "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }], "13": [[{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 0, "2": 0, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }]], "14": [[1, 1, 1, 1], [1, 1, 1, 1], [1, 0, 1, 1]], "15": [[0, 1, 1], [1, 0, 1], [1, 1, 1], [1, 1, 0]], "16": { "8": -1, "9": 0, "10": {} } }, "version": 1 },
  "Level 06/03": { "full_name": "LEVEL_06_03", "grid_data": { "0": 1, "11": [{ "4": -1, "5": 1, "6": 0, "7": 0 }, { "4": -1, "5": 2, "6": -1, "7": 1 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 2, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }], "12": [{ "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 2, "6": -1, "7": 0 }, { "4": -1, "5": 1, "6": -1, "7": 0 }, { "4": -1, "5": 2, "6": 1, "7": 0 }, { "4": -1, "5": 2, "6": 2, "7": 0 }, { "4": -1, "5": 2, "6": 2, "7": 0 }], "13": [[{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 2, "2": 2, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 2, "2": 2, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 4, "2": 4, "3": 11 }, { "1": 4, "2": 4, "3": 11 }, { "1": 4, "2": 4, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 4, "2": 4, "3": 11 }], [{ "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 4, "2": 4, "3": 11 }, { "1": 1, "2": 1, "3": 11 }], [{ "1": 2, "2": 2, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }, { "1": 1, "2": 1, "3": 11 }]], "14": [[0, 1, 1, 1, 0, 1], [0, 0, 1, 0, 0, 0], [1, 0, 1, 1, 0, 1], [1, 1, 1, 0, 1, 0], [1, 1, 1, 1, 0, 1]], "15": [[0, 1, 0, 1, 1], [1, 1, 1, 1, 1], [1, 0, 1, 1, 1], [0, 1, 0, 1, 1], [0, 0, 1, 1, 1], [1, 0, 1, 0, 0]], "16": { "8": 27, "9": 5, "10": {} } }, "version": 1 }
};

import { GridImpl } from './engine/GridImpl';
import { E } from './engine/E';
import { LoadMode } from './engine/Grid';

function toEngineCorner(c: Corner): E.Corner {
  switch (c) {
    case Corner.TopLeft: return E.Corner.TopLeft;
    case Corner.TopRight: return E.Corner.TopRight;
    case Corner.BottomLeft: return E.Corner.BottomLeft;
    case Corner.BottomRight: return E.Corner.BottomRight;
  }
}

export function App() {
  const [gridData, setGridData] = useState<GridModelData | null>(null);
  const [currentLevelKey, setCurrentLevelKey] = useState<string>("Level 01/01");
  const [completedLevels, setCompletedLevels] = useState<Set<string>>(new Set());
  const [isPointerDown, setIsPointerDown] = useState(false);
  const [mouseHoldStatus, setMouseHoldStatus] = useState<E.MouseDragState>(E.MouseDragState.None);
  const mouseHoldStatusRef = useRef<E.MouseDragState>(E.MouseDragState.None);
  const [won, setWon] = useState(false);
  const [autoFloodAir, setAutoFloodAir] = useState(false);
  const [selectedTool, setSelectedTool] = useState<Content.Water | Content.Boat | Content.NoWater | Content.NoBoat>(Content.Water);
  const [mistakes, setMistakes] = useState<number>(0);
  const mistakesRef = useRef(mistakes);
  mistakesRef.current = mistakes;
  const [blinkingCells, setBlinkingCells] = useState<Map<string, { corner: Corner, timestamp: number }>>(new Map());
  const [mistakePulse, setMistakePulse] = useState<boolean>(false);
  const hasBoats = levelHasBoats(gridData);
  const hasBoatsRef = useRef(hasBoats);
  hasBoatsRef.current = hasBoats;

  const [canUndo, setCanUndo] = useState<boolean>(false);
  const [canRedo, setCanRedo] = useState<boolean>(false);
  const engineRef = useRef<GridImpl | null>(null);

  const handleUndo = () => {
    const engine = engineRef.current;
    if (!engine) return;
    if (engine.undo()) {
      const next = engine.to_grid_data();
      setGridData(next);
      setWon(isLevelComplete(next));
      setCanUndo(engine.can_undo());
      setCanRedo(engine.can_redo());
    }
  };

  const handleRedo = () => {
    const engine = engineRef.current;
    if (!engine) return;
    if (engine.redo()) {
      const next = engine.to_grid_data();
      setGridData(next);
      setWon(isLevelComplete(next));
      setCanUndo(engine.can_undo());
      setCanRedo(engine.can_redo());
    }
  };

  const handleUndoRef = useRef(handleUndo);
  handleUndoRef.current = handleUndo;
  const handleRedoRef = useRef(handleRedo);
  handleRedoRef.current = handleRedo;

  const handlePointerUp = () => {
    setIsPointerDown(false);
    mouseHoldStatusRef.current = E.MouseDragState.None;
    setMouseHoldStatus(E.MouseDragState.None);
    if (engineRef.current) {
      while (
        engineRef.current.undo_stack.length > 0 &&
        engineRef.current.undo_stack[engineRef.current.undo_stack.length - 1].changes.length === 0
      ) {
        engineRef.current.undo_stack.pop();
      }
      setCanUndo(engineRef.current.can_undo());
      setCanRedo(engineRef.current.can_redo());
    }
  };

  useEffect(() => {
    if (!hasBoats && (selectedTool === Content.Boat || selectedTool === Content.NoBoat)) {
      setSelectedTool(Content.Water);
    }
  }, [hasBoats, selectedTool]);

  const [isDarkMode, setIsDarkMode] = useState<boolean>(() => {
    if (typeof window === 'undefined') return false;
    return localStorage.getItem('liquidum_theme') === 'dark';
  });

  useEffect(() => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('liquidum_theme', isDarkMode ? 'dark' : 'light');
    }
  }, [isDarkMode]);

  const isTestMode = typeof window !== 'undefined' && (
    new URLSearchParams(window.location.search).get('mode') === 'test' ||
    new URLSearchParams(window.location.search).has('testLevel') ||
    new URLSearchParams(window.location.search).has('level')
  );

  const loadLevelFromString = (levelStr: string, preserveContents: boolean = false) => {
    try {
      const engine = GridImpl.from_str(levelStr, preserveContents ? LoadMode.Testing : LoadMode.SolutionNoClear);
      if (!preserveContents) {
        for (let r = 0; r < engine.rows(); r++) {
          for (let c = 0; c < engine.cols(); c++) {
            const pure = engine.pure_cells[r][c];
            if (pure.c_left !== Content.Block) pure.c_left = Content.Nothing;
            if (pure.c_right !== Content.Block) pure.c_right = Content.Nothing;
          }
        }
      }
      engine.undo_stack = [];
      engine.redo_stack = [];
      engine.maybe_update_hints();
      engineRef.current = engine;
      const data = engine.to_grid_data();
      setGridData(data);
      setWon(preserveContents ? isLevelComplete(data) : false);
      setMistakes(0);
      setBlinkingCells(new Map());
      setCanUndo(false);
      setCanRedo(false);
    } catch (e) {
      console.error("Failed to load level from string", e);
    }
  };

  const loadLevel = (levelKey: string) => {
    try {
      setCurrentLevelKey(levelKey);
      const data = parseGridData(LEVELS[levelKey]);

      const solution_c_left: Content[][] = [];
      const solution_c_right: Content[][] = [];
      let hasSolutionCells = false;
      for (let r = 0; r < data.cells.length; r++) {
        solution_c_left.push([]);
        solution_c_right.push([]);
        for (let c = 0; c < data.cells[r].length; c++) {
          solution_c_left[r].push(data.cells[r][c].c_left);
          solution_c_right[r].push(data.cells[r][c].c_right);
          if (
            data.cells[r][c].c_left === Content.Water ||
            data.cells[r][c].c_left === Content.Boat ||
            data.cells[r][c].c_right === Content.Water ||
            data.cells[r][c].c_right === Content.Boat
          ) {
            hasSolutionCells = true;
          }
        }
      }
      if (hasSolutionCells) {
        data.solution_c_left = solution_c_left;
        data.solution_c_right = solution_c_right;
      }

      for (let r = 0; r < data.cells.length; r++) {
        for (let c = 0; c < data.cells[r].length; c++) {
          if (data.cells[r][c].c_left !== Content.Block) data.cells[r][c].c_left = Content.Nothing;
          if (data.cells[r][c].c_right !== Content.Block) data.cells[r][c].c_right = Content.Nothing;
        }
      }

      const engine = GridImpl.load_from_grid_data(data);
      engine.undo_stack = [];
      engine.redo_stack = [];
      engine.maybe_update_hints();
      engineRef.current = engine;

      setGridData(data);
      setWon(false);
      setMistakes(0);
      setBlinkingCells(new Map());
      setCanUndo(false);
      setCanRedo(false);
    } catch (e) {
      console.error(e);
    }
  };

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const customLevel = params.get('testLevel') || params.get('level');
    if (customLevel) {
      loadLevelFromString(customLevel);
    } else {
      loadLevel("Level 01/01");
    }

    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.target as HTMLElement)?.tagName === 'INPUT' || (e.target as HTMLElement)?.tagName === 'TEXTAREA') {
        return;
      }
      const key = e.key.toLowerCase();
      if ((key === 'z' && (e.ctrlKey || e.metaKey)) || key === 'z') {
        if (!e.shiftKey) {
          e.preventDefault();
          handleUndoRef.current();
          return;
        } else {
          e.preventDefault();
          handleRedoRef.current();
          return;
        }
      }
      if ((key === 'y' && (e.ctrlKey || e.metaKey)) || key === 'y') {
        e.preventDefault();
        handleRedoRef.current();
        return;
      }
      if (e.key === '1') setSelectedTool(Content.Water);
      else if (e.key === '2') setSelectedTool(Content.NoWater);
      else if (e.key === '3' && hasBoatsRef.current) setSelectedTool(Content.Boat);
      else if (e.key === '4' && hasBoatsRef.current) setSelectedTool(Content.NoBoat);
    };

    window.addEventListener('pointerup', handlePointerUp);
    window.addEventListener('keydown', handleKeyDown);
    return () => {
      window.removeEventListener('pointerup', handlePointerUp);
      window.removeEventListener('keydown', handleKeyDown);
    };
  }, []);

  useEffect(() => {
    (window as any).loadLevelString = loadLevelFromString;
    (window as any).loadLevelKey = loadLevel;
    (window as any).setTool = (tool: Content.Water | Content.Boat | Content.NoWater | Content.NoBoat) => {
      if ((tool === Content.Boat || tool === Content.NoBoat) && !hasBoatsRef.current) {
        return;
      }
      setSelectedTool(tool);
    };
    (window as any).setAutoFloodAir = (val: boolean) => setAutoFloodAir(val);
    (window as any).setDarkMode = (val: boolean) => setIsDarkMode(val);
    (window as any).exportLevelString = () => {
      if (engineRef.current) return engineRef.current.to_str();
      if (!gridData) return '';
      return GridImpl.load_from_grid_data(gridData).to_str();
    };
    (window as any).isWon = () => won;
    (window as any).getGridData = () => gridData;
    (window as any).getMistakes = () => mistakesRef.current;
    (window as any).putCellAction = (r: number, c: number, corner: Corner, content: Content) => {
      const engine = engineRef.current;
      if (!engine) return;
      const eCorner = toEngineCorner(corner);
      const cell = engine.get_cell(r, c) as any;
      if (cell.block_at(eCorner)) return;

      engine.push_empty_undo();
      if (content === Content.Water) {
        cell.put_water(eCorner, false);
      } else if (content === Content.NoWater) {
        cell.put_nowater(eCorner, false, autoFloodAir);
      } else if (content === Content.Boat) {
        cell.put_boat(false);
      } else if (content === Content.NoBoat) {
        cell.put_noboat(eCorner, false);
      } else if (content === Content.Nothing) {
        cell.remove_content(eCorner, false, autoFloodAir);
      }

      handlePointerUp();
      const next = engine.to_grid_data();
      setGridData(next);
      setCanUndo(engine.can_undo());
      setCanRedo(engine.can_redo());
      if (isLevelComplete(next)) {
        setWon(true);
        setCompletedLevels(comp => new Set(comp).add(currentLevelKey));
      }
    };
    (window as any).undo = () => handleUndoRef.current();
    (window as any).redo = () => handleRedoRef.current();
    (window as any).canUndo = () => engineRef.current?.can_undo() ?? false;
    (window as any).canRedo = () => engineRef.current?.can_redo() ?? false;
  }, [gridData, won, isDarkMode, mistakes, canUndo, canRedo]);

  const triggerMistake = (r: number, c: number, corner: Corner) => {
    setMistakes(m => m + 1);
    setMistakePulse(true);
    setTimeout(() => setMistakePulse(false), 400);

    const cellKey = `${r}-${c}`;
    setBlinkingCells(prev => {
      const next = new Map(prev);
      next.set(cellKey, { corner, timestamp: Date.now() });
      return next;
    });

    setTimeout(() => {
      setBlinkingCells(prev => {
        if (!prev.has(cellKey)) return prev;
        const next = new Map(prev);
        next.delete(cellKey);
        return next;
      });
    }, 800);

    setIsPointerDown(false);
    mouseHoldStatusRef.current = E.MouseDragState.None;
    setMouseHoldStatus(E.MouseDragState.None);

    if (engineRef.current) {
      while (
        engineRef.current.undo_stack.length > 0 &&
        engineRef.current.undo_stack[engineRef.current.undo_stack.length - 1].changes.length === 0
      ) {
        engineRef.current.undo_stack.pop();
      }
      setCanUndo(engineRef.current.can_undo());
      setCanRedo(engineRef.current.can_redo());
    }
  };

  const handleCellDown = (r: number, c: number, corner: Corner, e: PointerEvent) => {
    if (won) return;
    const engine = engineRef.current;
    if (!engine) return;

    const eCorner = toEngineCorner(corner);
    const cell = engine.get_cell(r, c) as any;
    if (cell.block_at(eCorner)) return;

    engine.push_empty_undo();
    let status = E.MouseDragState.None;

    if (e.button === 2) {
      // Secondary button (Right Click) - Port of Godot cell_pressed_second_button
      if (cell.nowater_at(eCorner)) {
        status = E.MouseDragState.RemoveNoWater;
        cell.remove_nowater(eCorner, false);
      } else if (cell.noboat_at(eCorner)) {
        status = E.MouseDragState.RemoveNoBoat;
        cell.remove_noboat(eCorner, false);
      } else if (cell.has_boat()) {
        status = E.MouseDragState.RemoveBoat;
        cell.remove_content(eCorner, false);
      } else {
        if (selectedTool === Content.Boat) {
          status = E.MouseDragState.NoBoat;
          cell.put_noboat(eCorner, false);
        } else {
          status = E.MouseDragState.NoWater;
          cell.put_nowater(eCorner, false, autoFloodAir);
        }
      }
    } else {
      // Primary button (Left Click) - Port of Godot _process_click
      if (selectedTool === Content.Water) {
        if (cell.water_at(eCorner)) {
          status = E.MouseDragState.RemoveWater;
          cell.remove_content(eCorner, false, autoFloodAir);
        } else {
          status = E.MouseDragState.Water;
          const added = cell.put_water(eCorner, false);
          if (added <= 0.0) {
            triggerMistake(r, c, corner);
            return;
          }
        }
      } else if (selectedTool === Content.NoWater) {
        if (cell.nowater_at(eCorner)) {
          status = E.MouseDragState.RemoveNoWater;
          cell.remove_nowater(eCorner, false);
        } else {
          status = E.MouseDragState.NoWater;
          cell.put_nowater(eCorner, false, autoFloodAir);
        }
      } else if (selectedTool === Content.Boat) {
        if (cell.has_boat()) {
          status = E.MouseDragState.RemoveBoat;
          cell.remove_content(E.Corner.BottomLeft, false);
        } else {
          status = E.MouseDragState.Boat;
          const success = cell.put_boat(false);
          if (!success) {
            triggerMistake(r, c, corner);
            return;
          }
        }
      } else if (selectedTool === Content.NoBoat) {
        if (cell.noboat_at(eCorner)) {
          status = E.MouseDragState.RemoveNoBoat;
          cell.remove_noboat(eCorner, false);
        } else {
          status = E.MouseDragState.NoBoat;
          cell.put_noboat(eCorner, false);
        }
      }
    }

    mouseHoldStatusRef.current = status;
    setMouseHoldStatus(status);
    setIsPointerDown(true);

    const next = engine.to_grid_data();
    setGridData(next);
    setCanUndo(engine.can_undo());
    setCanRedo(engine.can_redo());
    const complete = isLevelComplete(next);
    if (complete) {
      setWon(true);
      setIsPointerDown(false);
      mouseHoldStatusRef.current = E.MouseDragState.None;
      setMouseHoldStatus(E.MouseDragState.None);
      setCompletedLevels(comp => new Set(comp).add(currentLevelKey));
    }
  };

  const handleCellEnter = (r: number, c: number, corner: Corner, e: PointerEvent) => {
    if (won) return;
    const engine = engineRef.current;
    if (!engine) return;

    const dragStatus = mouseHoldStatusRef.current;
    if (!isPointerDown || dragStatus === E.MouseDragState.None) return;

    const eCorner = toEngineCorner(corner);
    const cell = engine.get_cell(r, c) as any;
    if (cell.block_at(eCorner)) return;

    let madeChange = false;

    // Port of Godot _on_cell_mouse_entered:
    if (dragStatus === E.MouseDragState.Water && cell.nothing_at(eCorner)) {
      const added = cell.put_water(eCorner, false);
      if (added <= 0.0) {
        triggerMistake(r, c, corner);
        return;
      }
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.NoWater && (cell.noboat_at(eCorner) || cell.nothing_at(eCorner))) {
      cell.put_nowater(eCorner, false, autoFloodAir);
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.NoBoat && (cell.nowater_at(eCorner) || cell.nothing_at(eCorner))) {
      cell.put_noboat(eCorner, false);
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.Boat && cell.nothing_at(eCorner)) {
      const success = cell.put_boat(false);
      if (!success) {
        triggerMistake(r, c, corner);
        return;
      }
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.RemoveWater && cell.water_at(eCorner)) {
      cell.remove_content(eCorner, false, autoFloodAir);
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.RemoveNoWater && cell.nowater_at(eCorner)) {
      cell.remove_nowater(eCorner, false);
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.RemoveNoBoat && cell.noboat_at(eCorner)) {
      cell.remove_noboat(eCorner, false);
      madeChange = true;
    } else if (dragStatus === E.MouseDragState.RemoveBoat && cell.has_boat()) {
      cell.remove_content(eCorner, false);
      madeChange = true;
    }

    if (madeChange) {
      const next = engine.to_grid_data();
      setGridData(next);
      setCanUndo(engine.can_undo());
      setCanRedo(engine.can_redo());
      const complete = isLevelComplete(next);
      if (complete) {
        setWon(true);
        setIsPointerDown(false);
        mouseHoldStatusRef.current = E.MouseDragState.None;
        setMouseHoldStatus(E.MouseDragState.None);
        setCompletedLevels(comp => new Set(comp).add(currentLevelKey));
      }
    }
  };

  // Compute current stats for hints header
  let currentWater = 0;
  let currentBoats = 0;
  let foundAquariums: { size: number, boats: number }[] = [];
  if (gridData) {
    for (let r = 0; r < gridData.cells.length; r++) {
      currentWater += countWaterRow(gridData, r);
      currentBoats += countBoatRow(gridData, r);
    }
    foundAquariums = getAquariums(gridData);
  }

  const getActualCount = (targetSize: number) => {
    return foundAquariums.filter(aq => Math.abs(aq.size - targetSize) < 0.01).length;
  };

  const levelKeys = Object.keys(LEVELS);
  const currentIndex = levelKeys.indexOf(currentLevelKey);
  const nextLevelKey = currentIndex >= 0 && currentIndex < levelKeys.length - 1 ? levelKeys[currentIndex + 1] : null;

  return (
    <div
      class={`game-container ${isDarkMode ? 'theme-dark' : ''}`}
      onPointerUp={handlePointerUp}
      onPointerLeave={handlePointerUp}
      onContextMenu={(e) => e.preventDefault()}
    >
      <div class="game-bg" />

      {!isTestMode && (
        <div class="level-picker">
          {levelKeys.map(key => {
            const isCurrent = key === currentLevelKey;
            const isDone = completedLevels.has(key);
            const statusClass = isCurrent ? 'level-btn-current' : isDone ? 'level-btn-done' : 'level-btn-unsolved';
            return (
              <button
                key={key}
                onClick={() => loadLevel(key)}
                class={`level-btn ${statusClass}`}
              >
                {isDone && <img src="/icons/checkmark.png" class="w-3.5 h-3.5 object-contain" alt="done" />}
                <span>{key}</span>
              </button>
            );
          })}
        </div>
      )}

      <div class="controls-toolbar">
        <label class="toolbar-toggle">
          <input
            type="checkbox"
            data-testid="auto-flood-air"
            checked={autoFloodAir}
            onChange={(e) => setAutoFloodAir(e.currentTarget.checked)}
            class="checkbox-input"
          />
          <span>Auto-Flood Air (✕)</span>
        </label>

        <div class="tool-selector">
          <button
            data-testid="tool-water"
            onClick={() => setSelectedTool(Content.Water)}
            class={`tool-btn ${selectedTool === Content.Water ? 'tool-btn-water-active' : 'tool-btn-water-inactive'}`}
            title="Water (1)"
            aria-label="Water"
          >
            <span class="text-base leading-none">💧</span>
          </button>
          <button
            data-testid="tool-air"
            onClick={() => setSelectedTool(Content.NoWater)}
            class={`tool-btn ${selectedTool === Content.NoWater ? 'tool-btn-air-active' : 'tool-btn-air-inactive'}`}
            title="Air (2)"
            aria-label="Air"
          >
            <img src="/icons/nowater.png" class="w-4 h-4 object-contain" alt="air" />
          </button>
          {hasBoats && (
            <>
              <button
                data-testid="tool-boat"
                onClick={() => setSelectedTool(Content.Boat)}
                class={`tool-btn ${selectedTool === Content.Boat ? 'tool-btn-boat-active' : 'tool-btn-boat-inactive'}`}
                title="Boat (3)"
                aria-label="Boat"
              >
                <img src="/icons/boat_small.png" class="w-4 h-4 object-contain" alt="boat" />
              </button>
              <button
                data-testid="tool-maybeboat"
                data-tool-id="noboat"
                onClick={() => setSelectedTool(Content.NoBoat)}
                class={`tool-btn ${selectedTool === Content.NoBoat ? 'tool-btn-maybeboat-active' : 'tool-btn-maybeboat-inactive'}`}
                title="Maybe Boat (4)"
                aria-label="Maybe Boat"
              >
                <div class="relative w-4 h-4 flex items-center justify-center pointer-events-none">
                  <img src="/icons/boat_small.png" class="w-full h-full object-contain" alt="maybe boat" />
                  <img src="/icons/question_mark.png" class="absolute inset-0 w-full h-full object-contain filter-mint" alt="?" />
                </div>
              </button>
            </>
          )}
        </div>

        <div class="undo-redo-group">
          <button
            data-testid="btn-undo"
            onClick={handleUndo}
            class={`btn-action btn-undo ${!canUndo ? 'btn-disabled' : ''}`}
            title="Undo (Z or Ctrl+Z)"
            aria-label="Undo"
            disabled={!canUndo}
          >
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 7v6h6" />
              <path d="M21 17a9 9 0 0 0-9-9 9 9 0 0 0-6 2.3L3 13" />
            </svg>
            <span>Undo</span>
          </button>
          <button
            data-testid="btn-redo"
            onClick={handleRedo}
            class={`btn-action btn-redo ${!canRedo ? 'btn-disabled' : ''}`}
            title="Redo (Y or Ctrl+Y)"
            aria-label="Redo"
            disabled={!canRedo}
          >
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
              <path d="M21 7v6h-6" />
              <path d="M3 17a9 9 0 0 1 9-9 9 9 0 0 1 6 2.3L21 13" />
            </svg>
            <span>Redo</span>
          </button>
        </div>

        <button
          data-testid="btn-restart"
          onClick={() => loadLevel(currentLevelKey)}
          class="btn-restart"
          title="Restart Level"
        >
          <img src="/icons/restart_normal.png" class="w-4 h-4 object-contain" alt="restart" />
          <span>Restart</span>
        </button>

        <button
          data-testid="btn-theme-toggle"
          onClick={() => setIsDarkMode(!isDarkMode)}
          class="btn-theme-toggle"
          title={isDarkMode ? "Switch to Aquatic Light Mode" : "Switch to Deep Ocean Dark Mode"}
        >
          <span>{isDarkMode ? '☀️' : '🌙'}</span>
        </button>
      </div>

      <h1 class="game-title">
        Liquidum Lite
      </h1>

      <div class="banner-slot">
        {won ? (
          <div data-testid="win-banner" class="win-banner">
            <div class="win-title">🎉 Level Complete! 🎉</div>
            <div class="flex items-center gap-2">
              <button
                data-testid="btn-play-again"
                onClick={() => loadLevel(currentLevelKey)}
                class="win-btn-again"
              >
                <img src="/icons/restart_normal.png" class="w-4 h-4 object-contain" alt="restart" />
                <span>Play Again</span>
              </button>
              {nextLevelKey && (
                <button
                  data-testid="btn-next-level"
                  onClick={() => loadLevel(nextLevelKey)}
                  class="win-btn-next"
                >
                  <span>Next Level ({nextLevelKey})</span>
                  <span>→</span>
                </button>
              )}
            </div>
          </div>
        ) : (
          <div class="controls-hint">
            Tap/Click: Place selected tool • Right-click: Air (✕)
          </div>
        )}
      </div>

      {gridData ? (
        <div class="flex flex-col items-center">
          {/* Grid Hints Header */}
          {(() => {
            const hasTotalWater = gridData.grid_hints.total_water >= 0;
            const hasTotalBoats = gridData.grid_hints.total_boats > 0;
            const aquariumEntries = Object.entries(gridData.grid_hints.expected_aquariums || {})
              .filter(([_, v]) => v !== -1 && v >= 0)
              .sort(([a], [b]) => parseFloat(a) - parseFloat(b));
            const hasAquariums = aquariumEntries.length > 0;

            return (
              <div class="grid-hints-card" data-testid="grid-hints-card">
                {/* Mistake Counter */}
                <div
                  data-testid="mistake-counter"
                  class={`hint-stat-card hint-stat-mistake ${mistakePulse ? 'hint-stat-mistake-bump' : ''}`}
                  title="Mistakes made"
                >
                  <span class="hint-stat-icon">❌</span>
                  <span class="hint-stat-label">Mistakes</span>
                  <span data-testid="mistake-count" class="hint-stat-value godot-text-outline">
                    {mistakes}
                  </span>
                </div>

                {hasTotalWater && (
                  <div
                    data-testid="hint-water-counter"
                    class={`hint-stat-card ${currentWater === gridData.grid_hints.total_water ? 'hint-stat-satisfied' :
                      currentWater > gridData.grid_hints.total_water ? 'hint-stat-over' :
                        'hint-stat-normal'
                      }`}
                    title={`Total water: ${currentWater} / ${gridData.grid_hints.total_water} placed`}
                  >
                    <span class="hint-stat-icon">💧</span>
                    <span class="hint-stat-label">Water</span>
                    <span class="hint-stat-value godot-text-outline">
                      {currentWater} / {gridData.grid_hints.total_water}
                    </span>
                    {currentWater === gridData.grid_hints.total_water ? (
                      <span class="hint-status-badge badge-satisfied">✓</span>
                    ) : currentWater > gridData.grid_hints.total_water ? (
                      <span class="hint-status-badge badge-over">⚠ Over</span>
                    ) : null}
                  </div>
                )}

                {hasTotalBoats && (
                  <div
                    data-testid="hint-boat-counter"
                    class={`hint-stat-card ${currentBoats === gridData.grid_hints.total_boats ? 'hint-stat-satisfied' :
                      currentBoats > gridData.grid_hints.total_boats ? 'hint-stat-over' :
                        'hint-stat-normal'
                      }`}
                    title={`Total boats: ${currentBoats} / ${gridData.grid_hints.total_boats} placed`}
                  >
                    <img src="/icons/boat_small.png" class="hint-boat-img" alt="boat" />
                    <span class="hint-stat-label">Boats</span>
                    <span class="hint-stat-value godot-text-outline">
                      {currentBoats} / {gridData.grid_hints.total_boats}
                    </span>
                    {currentBoats === gridData.grid_hints.total_boats ? (
                      <span class="hint-status-badge badge-satisfied">✓</span>
                    ) : currentBoats > gridData.grid_hints.total_boats ? (
                      <span class="hint-status-badge badge-over">⚠ Over</span>
                    ) : null}
                  </div>
                )}

                {hasAquariums && (
                  <div class={`aquarium-section ${(hasTotalWater || hasTotalBoats) ? 'has-counters' : ''}`} data-testid="aquarium-section">
                    <div class="aquarium-header">
                      <span class="aquarium-icon">🌊</span>
                      <span class="aquarium-label">Aquariums:</span>
                    </div>
                    <div class="aquarium-items">
                      {aquariumEntries.map(([sizeStr, expectedCount]) => {
                        const targetSize = parseFloat(sizeStr);
                        const actualCount = getActualCount(targetSize);
                        const isSatisfied = actualCount === expectedCount;
                        const isOver = actualCount > expectedCount;
                        const cardClass = isSatisfied ? 'aquarium-card-satisfied' : isOver ? 'aquarium-card-over' : 'aquarium-card-normal';
                        return (
                          <div
                            key={sizeStr}
                            data-testid={`aquarium-hint-${sizeStr}`}
                            class={`aquarium-card ${cardClass}`}
                            title={`Aquarium of size ${targetSize}: ${actualCount} / ${expectedCount} placed`}
                          >
                            <div class={`aq-tank ${targetSize === 0.5 ? 'aq-tank-half' : ''}`}>
                              {targetSize > 0 && (
                                <div class={`aq-tank-water ${targetSize === 0.5 ? 'aq-tank-water-half' : ''}`} />
                              )}
                              {targetSize === 0.5 && (
                                <svg class="aq-diag-line">
                                  <line x1="0" y1="0" x2="100%" y2="100%" stroke="#000924" stroke-width="2" />
                                </svg>
                              )}
                              <span class={`aq-tank-size ${targetSize === 0.5 ? 'aq-size-half' : ''}`}>
                                {targetSize}
                              </span>
                            </div>
                            <div class="aq-info">
                              <span class="aq-expected-count">×{expectedCount}</span>
                              <span class={`aq-status-pill ${isSatisfied ? 'aq-pill-satisfied' :
                                isOver ? 'aq-pill-over' :
                                  'aq-pill-normal'
                                }`}>
                                {isSatisfied ? `✓ ${actualCount}` : `${actualCount}/${expectedCount}`}
                              </span>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  </div>
                )}
              </div>
            );
          })()}

          <div class={`grid-board-card ${won ? 'is-won pointer-events-none' : ''}`}>
            <Grid
              gridData={gridData}
              blinkingCells={blinkingCells}
              onCellPointerDown={handleCellDown}
              onCellPointerEnter={handleCellEnter}
            />
          </div>
        </div>
      ) : (
        <p>Loading...</p>
      )}
    </div>
  );
}
