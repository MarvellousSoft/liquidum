import { h } from 'preact';
import { useState, useEffect } from 'preact/hooks';
import { Grid } from './components/Grid';
import { parseGridData, Content, CellType, Corner, isLevelComplete, countWaterRow, countBoatRow, getAquariums } from './model/GridData';
import type { GridModelData } from './model/GridData';

const LEVELS: Record<string, any> = {
  "Level 01/01": {"description":"FIRST_LEVEL_DESCRIPTION","full_name":"LEVEL_01_01","grid_data":{"0":1,"11":[{"4":2,"5":0,"6":-1,"7":0},{"4":1,"5":0,"6":-1,"7":0},{"4":3,"5":0,"6":-1,"7":0}],"12":[{"4":1,"5":0,"6":-1,"7":0},{"4":2,"5":0,"6":-1,"7":0},{"4":3,"5":0,"6":-1,"7":0}],"13":[[{"1":2,"2":2,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}],[{"1":2,"2":2,"3":11},{"1":2,"2":2,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}]],"14":[[1,1,1],[1,1,1]],"15":[[1,1],[1,1],[1,1]],"16":{"8":-1,"9":0,"10":{}}},"version":1, "tutorial":"mouse1"},
  "Level 02/01": {"full_name":"LEVEL_02_01","grid_data":{"0":1,"11":[{"4":3,"5":2,"6":-1,"7":0},{"4":3,"5":2,"6":-1,"7":0},{"4":3,"5":1,"6":-1,"7":0},{"4":2,"5":1,"6":-1,"7":0}],"12":[{"4":3,"5":2,"6":-1,"7":0},{"4":3,"5":2,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":3,"5":1,"6":-1,"7":0}],"13":[[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":2,"2":2,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":2,"2":2,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}],[{"1":2,"2":2,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":2,"2":2,"3":11},{"1":2,"2":2,"3":11}]],"14":[[1,1,1,1],[1,1,1,1],[1,1,1,1]],"15":[[1,1,1],[1,1,0],[1,1,1],[1,1,1]],"16":{"8":-1,"9":0,"10":{}}},"version":1, "tutorial": "together_separate"},
  "Level 03/01": {"full_name":"LEVEL_03_01","grid_data":{"0":1,"11":[{"4":0.5,"5":0,"6":-1,"7":0},{"4":1.5,"5":0,"6":-1,"7":0},{"4":1,"5":0,"6":-1,"7":0},{"4":2.5,"5":0,"6":-1,"7":0}],"12":[{"4":-1,"5":0,"6":-1,"7":0},{"4":1.5,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":0.5,"5":0,"6":-1,"7":0}],"13":[[{"1":1,"2":2,"3":9},{"1":2,"2":2,"3":11},{"1":2,"2":2,"3":11},{"1":2,"2":2,"3":10}],[{"1":1,"2":1,"3":10},{"1":1,"2":2,"3":9},{"1":2,"2":2,"3":10},{"1":2,"2":2,"3":11}],[{"1":1,"2":2,"3":9},{"1":2,"2":2,"3":11},{"1":2,"2":2,"3":11},{"1":2,"2":1,"3":10}],[{"1":2,"2":1,"3":10},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":2,"2":2,"3":11}]],"14":[[0,0,0,0],[0,0,0,0],[1,1,1,1]],"15":[[0,0,0],[0,0,0],[0,1,0],[0,0,1]],"16":{"8":-1,"9":0,"10":{}}},"version":1},
  "Level 03/07": {"full_name":"LEVEL_03_07","grid_data":{"0":1,"11":[{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":2,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0}],"12":[{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":2,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0}],"13":[[{"1":3,"2":0,"3":9},{"1":0,"2":3,"3":10},{"1":3,"2":3,"3":11},{"1":3,"2":0,"3":9},{"1":0,"2":3,"3":10},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11}],[{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":3,"3":9}],[{"1":3,"2":0,"3":10},{"1":0,"2":3,"3":9},{"1":3,"2":1,"3":10},{"1":1,"2":1,"3":11},{"1":1,"2":3,"3":9},{"1":0,"2":0,"3":11},{"1":3,"2":3,"3":11}],[{"1":0,"2":0,"3":11},{"1":0,"2":3,"3":10},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11},{"1":3,"2":1,"3":10},{"1":3,"2":3,"3":11}],[{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":3,"3":10},{"1":3,"2":1,"3":10},{"1":1,"2":3,"3":10},{"1":3,"2":3,"3":11},{"1":1,"2":3,"3":10}],[{"1":1,"2":3,"3":9},{"1":0,"2":0,"3":11},{"1":0,"2":3,"3":9},{"1":3,"2":3,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":3,"3":9}],[{"1":3,"2":3,"3":11},{"1":1,"2":3,"3":9},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11},{"1":3,"2":3,"3":11}]],"14":[[0,0,1,0,0,1,1],[0,0,0,0,0,0,1],[1,1,1,1,1,0,1],[0,0,1,1,1,1,1],[0,0,0,1,0,1,0],[1,0,1,1,1,1,1]],"15":[[0,1,1,0,1,1],[0,0,0,0,0,0],[0,1,0,0,1,1],[0,1,1,1,1,1],[0,0,1,0,1,1],[1,0,1,1,0,0],[1,1,1,1,1,1]],"16":{"8":-1,"9":0,"10":{}}},"version":1},
  "Level 04/01": {"full_name":"LEVEL_04_01","grid_data":{"0":1,"11":[{"4":-1,"5":0,"6":2,"7":0},{"4":-1,"5":0,"6":2,"7":0},{"4":4.5,"5":0,"6":-1,"7":0}],"12":[{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":1,"7":0},{"4":-1,"5":0,"6":-1,"7":0}],"13":[[{"1":4,"2":4,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":4,"2":4,"3":11}],[{"1":1,"2":1,"3":11},{"1":4,"2":4,"3":11},{"1":0,"2":0,"3":11},{"1":4,"2":4,"3":11},{"1":0,"2":1,"3":10}],[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":10},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":0,"3":10}]],"14":[[0,1,1,1,0],[0,0,0,0,0]],"15":[[0,0,0,0],[1,0,0,1],[0,0,0,0]],"16":{"8":-1,"9":-1,"10":{}}},"version":1, "tutorial": "boats"},
  "Level 05/01": {"full_name":"LEVEL_05_01","grid_data":{"0":1,"11":[{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0}],"12":[{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0},{"4":-1,"5":0,"6":-1,"7":0}],"13":[[{"1":1,"2":1,"3":10},{"1":1,"2":1,"3":9},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11},{"1":0,"2":0,"3":11}],[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":3,"3":9},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}]],"14":[[0,0,0,0,0],[1,1,1,0,1]],"15":[[0,1,0,0],[0,1,0,1],[0,0,0,0]],"16":{"8":-1,"9":0,"10":{"0":0,"2.5":1,"3":1}}},"version":1},
  "Level 06/01": {"full_name":"LEVEL_06_01","grid_data":{"0":1,"11":[{"4":-1,"5":2,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":2,"6":-1,"7":0},{"4":-1,"5":2,"6":-1,"7":0}],"12":[{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0},{"4":-1,"5":1,"6":-1,"7":0}],"13":[[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}],[{"1":1,"2":1,"3":11},{"1":0,"2":0,"3":11},{"1":1,"2":1,"3":11},{"1":1,"2":1,"3":11}]],"14":[[1,1,1,1],[1,1,1,1],[1,0,1,1]],"15":[[0,1,1],[1,0,1],[1,1,1],[1,1,0]],"16":{"8":-1,"9":0,"10":{}}},"version":1}
};

import { GridImpl } from './engine/GridImpl';

export function App() {
  const [gridData, setGridData] = useState<GridModelData | null>(null);
  const [currentLevelKey, setCurrentLevelKey] = useState<string>("Level 01/01");
  const [completedLevels, setCompletedLevels] = useState<Set<string>>(new Set());
  const [isPointerDown, setIsPointerDown] = useState(false);
  const [dragAction, setDragAction] = useState<{ corner: Corner, content: Content } | null>(null);
  const [won, setWon] = useState(false);
  const [autoFloodAir, setAutoFloodAir] = useState(false);
  const [selectedTool, setSelectedTool] = useState<Content.Water | Content.Boat>(Content.Water);

  useEffect(() => {
    loadLevel("Level 01/01");
    const handleUp = () => setIsPointerDown(false);
    window.addEventListener('pointerup', handleUp);
    return () => window.removeEventListener('pointerup', handleUp);
  }, []);

  const loadLevel = (levelKey: string) => {
    try {
      setCurrentLevelKey(levelKey);
      const data = parseGridData(LEVELS[levelKey]);
      for (let r = 0; r < data.cells.length; r++) {
        for (let c = 0; c < data.cells[r].length; c++) {
          if (data.cells[r][c].c_left !== Content.Block) data.cells[r][c].c_left = Content.Nothing;
          if (data.cells[r][c].c_right !== Content.Block) data.cells[r][c].c_right = Content.Nothing;
        }
      }
      setGridData(data);
      setWon(false);
    } catch (e) {
      console.error(e);
    }
  };

  const executeEngineAction = (r: number, c: number, action: { corner: Corner, content: Content }) => {
    setGridData(prev => {
      if (!prev) return prev;
      const engine = GridImpl.load_from_grid_data(prev);
      
      const currContent = (engine.get_cell(r, c) as any).pure()._content_at(action.corner as unknown as any);
      if (currContent === Content.Block) return prev;
      
      if (action.content === Content.Water) {
        (engine.get_cell(r, c) as any).put_water(action.corner as unknown as any);
      } else if (action.content === Content.NoWater) {
        (engine.get_cell(r, c) as any).put_nowater(action.corner as unknown as any, false, autoFloodAir);
      } else if (action.content === Content.Boat) {
        (engine.get_cell(r, c) as any).put_boat(action.corner as unknown as any);
      } else if (action.content === Content.Nothing) {
        (engine.get_cell(r, c) as any).remove_content(action.corner as unknown as any, false, autoFloodAir);
      }
      
      const next = engine.to_grid_data();
      const complete = isLevelComplete(next);
      setWon(complete);
      if (complete) {
        setCompletedLevels(comp => new Set(comp).add(currentLevelKey));
      }
      return next;
    });
  };

  const handleCellDown = (r: number, c: number, corner: Corner, e: PointerEvent) => {
    setIsPointerDown(true);
    if (!gridData) return;
    const cell = gridData.cells[r][c];
    
    let currentContent = Content.Nothing;
    if (cell.type === CellType.Single) {
      currentContent = cell.c_left;
    } else {
      currentContent = (corner === Corner.TopLeft || corner === Corner.BottomLeft) ? cell.c_left : cell.c_right;
    }
    
    if (currentContent === Content.Block) return;

    let targetContent = Content.Nothing;
    if (e.button === 2) {
      targetContent = currentContent === Content.NoWater ? Content.Nothing : Content.NoWater;
    } else {
      targetContent = currentContent === selectedTool ? Content.Nothing : selectedTool;
    }
    
    setDragAction({ corner, content: targetContent });
    executeEngineAction(r, c, { corner, content: targetContent });
  };

  const handleCellEnter = (r: number, c: number, corner: Corner, e: PointerEvent) => {
    if (isPointerDown && dragAction) {
      executeEngineAction(r, c, { corner: corner, content: dragAction.content });
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
      class="min-h-screen flex flex-col items-center justify-center p-4 relative"
      onPointerUp={() => setIsPointerDown(false)}
      onPointerLeave={() => setIsPointerDown(false)}
      onContextMenu={(e) => e.preventDefault()}
    >
      <div class="absolute inset-0 bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900 -z-10" />
      
      <div class="mb-4 flex flex-wrap gap-2 max-w-2xl justify-center">
        {levelKeys.map(key => {
          const isCurrent = key === currentLevelKey;
          const isDone = completedLevels.has(key);
          return (
            <button 
              key={key}
              onClick={() => loadLevel(key)}
              class={`px-3 py-1 md:px-4 md:py-2 text-sm md:text-base font-bold transition-all rounded shadow-md flex items-center gap-1.5 ${
                 isCurrent ? 'bg-emerald-600 text-white ring-2 ring-emerald-400 shadow-emerald-900/50' :
                 isDone ? 'bg-emerald-800/80 hover:bg-emerald-700 text-emerald-100 border border-emerald-500/30' :
                 'bg-blue-600 hover:bg-blue-500 text-white'
              }`}
            >
              {isDone && <span class="text-emerald-300">✓</span>}
              <span>{key}</span>
            </button>
          );
        })}
      </div>
      
      <div class="mb-4 flex flex-wrap gap-4 items-center justify-center bg-white/5 p-4 rounded-xl border border-white/10 shadow-lg backdrop-blur-md">
        <label class="flex items-center space-x-2 text-white font-bold cursor-pointer bg-white/10 px-4 py-2 rounded-full border border-white/20 hover:bg-white/20 transition-colors">
          <input 
             type="checkbox" 
             checked={autoFloodAir} 
             onChange={(e) => setAutoFloodAir(e.currentTarget.checked)}
             class="w-5 h-5 rounded border-gray-300 text-blue-600 focus:ring-blue-600 focus:ring-2 cursor-pointer"
          />
          <span>Auto-Flood Air (✕)</span>
        </label>
        
        <div class="flex items-center space-x-2 bg-white/10 px-2 py-1 rounded-full border border-white/20">
           <span class="text-white font-bold pl-2 pr-1">Tool:</span>
           <button 
             onClick={() => setSelectedTool(Content.Water)}
             class={`px-4 py-1 rounded-full font-bold transition-all ${selectedTool === Content.Water ? 'bg-blue-500 text-white shadow-lg scale-105' : 'text-blue-200 hover:bg-white/10'}`}
           >
             💧 Water
           </button>
           <button 
             onClick={() => setSelectedTool(Content.Boat)}
             class={`px-4 py-1 rounded-full font-bold transition-all ${selectedTool === Content.Boat ? 'bg-amber-500 text-white shadow-lg scale-105' : 'text-amber-200 hover:bg-white/10'}`}
           >
             ⛵ Boat
           </button>
        </div>
      </div>

      <h1 class="text-4xl md:text-6xl font-black text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-emerald-400 mb-6 drop-shadow-lg">
        Liquidum Lite
      </h1>

      {won && (
        <div class="mb-6 px-6 py-4 bg-emerald-500/20 border border-emerald-400/50 text-emerald-200 rounded-2xl flex items-center gap-4 shadow-[0_0_30px_rgba(16,185,129,0.3)] backdrop-blur-md animate-bounce">
          <div class="text-xl font-black">🎉 Level Complete! 🎉</div>
          {nextLevelKey && (
            <button
              onClick={() => loadLevel(nextLevelKey)}
              class="px-4 py-2 bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold rounded-xl shadow-lg transition-transform hover:scale-105 active:scale-95"
            >
              Next Level ({nextLevelKey}) →
            </button>
          )}
        </div>
      )}

      {gridData ? (
        <div class="flex flex-col items-center">
          {/* Grid Hints Header */}
          {(gridData.grid_hints.total_water > 0 || gridData.grid_hints.total_boats > 0 || Object.entries(gridData.grid_hints.expected_aquariums).some(([k, v]) => k !== "0" && v > 0)) && (
            <div class="mb-4 flex flex-wrap gap-5 items-center justify-center text-lg font-black text-white/80 bg-white/5 px-6 py-2.5 rounded-2xl border border-white/10 shadow-lg backdrop-blur-md">
              {gridData.grid_hints.total_water > 0 && (
                 <div class={`flex items-center gap-1.5 transition-colors ${
                   currentWater === gridData.grid_hints.total_water ? 'text-sky-400 font-bold' :
                   currentWater > gridData.grid_hints.total_water ? 'text-red-400 font-bold' :
                   'text-slate-300'
                 }`}>
                   <span>💧</span>
                   <span>{currentWater} / {gridData.grid_hints.total_water}</span>
                 </div>
              )}
              {gridData.grid_hints.total_boats > 0 && (
                 <div class={`flex items-center gap-1.5 transition-colors ${
                   currentBoats === gridData.grid_hints.total_boats ? 'text-amber-400 font-bold' :
                   currentBoats > gridData.grid_hints.total_boats ? 'text-red-400 font-bold' :
                   'text-slate-300'
                 }`}>
                   <span>⛵</span>
                   <span>{currentBoats} / {gridData.grid_hints.total_boats}</span>
                 </div>
              )}
              {Object.keys(gridData.grid_hints.expected_aquariums).some(k => k !== "0") && (
                 <div class="flex flex-wrap gap-2 items-center border-l border-white/20 pl-4">
                   <span class="text-xs uppercase tracking-wider text-slate-400 font-semibold mr-1">Aquariums:</span>
                   {Object.entries(gridData.grid_hints.expected_aquariums)
                     .filter(([k, v]) => k !== "0" && v > 0)
                     .map(([sizeStr, expectedCount]) => {
                       const targetSize = parseFloat(sizeStr);
                       const actualCount = getActualCount(targetSize);
                       const isSatisfied = actualCount === expectedCount;
                       const isOver = actualCount > expectedCount;
                       return (
                         <span class={`px-2.5 py-1 rounded text-sm font-mono border transition-all ${
                           isSatisfied ? 'bg-sky-500/20 border-sky-400/40 text-sky-300 font-bold shadow-[0_0_10px_rgba(56,189,248,0.2)]' :
                           isOver ? 'bg-red-500/20 border-red-400/40 text-red-300 font-bold' :
                           'bg-white/5 border-white/10 text-slate-300'
                         }`}>
                           {expectedCount}x[{targetSize}] ({actualCount})
                         </span>
                       );
                     })}
                 </div>
              )}
            </div>
          )}

          <div class="backdrop-blur-md bg-white/5 p-4 md:p-8 rounded-3xl border border-white/10 shadow-[0_0_40px_rgba(0,0,0,0.3)]">
            <Grid 
              gridData={gridData} 
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
