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
  const [selectedTool, setSelectedTool] = useState<Content.Water | Content.Boat | Content.NoWater>(Content.Water);

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
      const engine = GridImpl.from_str(levelStr);
      const data = engine.to_grid_data();
      if (!preserveContents) {
        for (let r = 0; r < data.cells.length; r++) {
          for (let c = 0; c < data.cells[r].length; c++) {
            if (data.cells[r][c].c_left !== Content.Block) data.cells[r][c].c_left = Content.Nothing;
            if (data.cells[r][c].c_right !== Content.Block) data.cells[r][c].c_right = Content.Nothing;
          }
        }
      }
      setGridData(data);
      setWon(preserveContents ? isLevelComplete(data) : false);
    } catch (e) {
      console.error("Failed to load level from string", e);
    }
  };

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

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const customLevel = params.get('testLevel') || params.get('level');
    if (customLevel) {
      loadLevelFromString(customLevel);
    } else {
      loadLevel("Level 01/01");
    }
    const handleUp = () => setIsPointerDown(false);
    window.addEventListener('pointerup', handleUp);
    return () => window.removeEventListener('pointerup', handleUp);
  }, []);

  useEffect(() => {
    (window as any).loadLevelString = loadLevelFromString;
    (window as any).loadLevelKey = loadLevel;
    (window as any).setTool = (tool: Content.Water | Content.Boat | Content.NoWater) => setSelectedTool(tool);
    (window as any).setAutoFloodAir = (val: boolean) => setAutoFloodAir(val);
    (window as any).setDarkMode = (val: boolean) => setIsDarkMode(val);
    (window as any).exportLevelString = () => {
      if (!gridData) return '';
      return GridImpl.load_from_grid_data(gridData).to_str();
    };
    (window as any).isWon = () => won;
    (window as any).getGridData = () => gridData;
  }, [gridData, won, isDarkMode]);

  const executeEngineAction = (r: number, c: number, action: { corner: Corner, content: Content }) => {
    if (won) return;
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
        (engine.get_cell(r, c) as any).put_boat();
      } else if (action.content === Content.Nothing) {
        (engine.get_cell(r, c) as any).remove_content(action.corner as unknown as any, false, autoFloodAir);
      }
      
      const next = engine.to_grid_data();
      const complete = isLevelComplete(next);
      if (complete) {
        setWon(true);
        setIsPointerDown(false);
        setDragAction(null);
        setCompletedLevels(comp => new Set(comp).add(currentLevelKey));
      }
      return next;
    });
  };

  const handleCellDown = (r: number, c: number, corner: Corner, e: PointerEvent) => {
    if (won) return;
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
    if (won) return;
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
      class={`game-container ${isDarkMode ? 'theme-dark' : ''}`}
      onPointerUp={() => setIsPointerDown(false)}
      onPointerLeave={() => setIsPointerDown(false)}
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
           <span class="text-white font-medium pl-2 pr-1">Tool:</span>
           <button 
             data-testid="tool-water"
             onClick={() => setSelectedTool(Content.Water)}
             class={`tool-btn ${selectedTool === Content.Water ? 'tool-btn-water-active' : 'tool-btn-water-inactive'}`}
           >
             <span>💧</span>
             <span>Water</span>
           </button>
           <button 
             data-testid="tool-air"
             onClick={() => setSelectedTool(Content.NoWater)}
             class={`tool-btn ${selectedTool === Content.NoWater ? 'tool-btn-air-active' : 'tool-btn-air-inactive'}`}
           >
             <img src="/icons/nowater.png" class="w-3.5 h-3.5 object-contain" alt="air" />
             <span>Air</span>
           </button>
           <button 
             data-testid="tool-boat"
             onClick={() => setSelectedTool(Content.Boat)}
             class={`tool-btn ${selectedTool === Content.Boat ? 'tool-btn-boat-active' : 'tool-btn-boat-inactive'}`}
           >
             <img src="/icons/boat_small.png" class="w-4 h-4 object-contain" alt="boat" />
             <span>Boat</span>
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
          {(gridData.grid_hints.total_water > 0 || gridData.grid_hints.total_boats > 0 || Object.entries(gridData.grid_hints.expected_aquariums).some(([k, v]) => k !== "0" && v > 0)) && (
            <div class="grid-hints-card">
              {gridData.grid_hints.total_water > 0 && (
                 <div class={`hint-stat-item ${
                   currentWater === gridData.grid_hints.total_water ? 'hint-satisfied-water' :
                   currentWater > gridData.grid_hints.total_water ? 'hint-over' :
                   'hint-normal'
                 }`}>
                   <span>💧</span>
                   <span class="godot-text-outline">{currentWater} / {gridData.grid_hints.total_water}</span>
                 </div>
              )}
              {gridData.grid_hints.total_boats > 0 && (
                 <div class={`hint-stat-item ${
                   currentBoats === gridData.grid_hints.total_boats ? 'hint-satisfied-boat' :
                   currentBoats > gridData.grid_hints.total_boats ? 'hint-over' :
                   'hint-normal'
                 }`}>
                   <img src="/icons/boat_small.png" class="w-4 h-4 object-contain" alt="boat" />
                   <span class="godot-text-outline">{currentBoats} / {gridData.grid_hints.total_boats}</span>
                 </div>
              )}
              {Object.keys(gridData.grid_hints.expected_aquariums).some(k => k !== "0") && (
                 <div class="aquarium-section">
                   <span class="aquarium-label">Aquariums:</span>
                   {Object.entries(gridData.grid_hints.expected_aquariums)
                     .filter(([k, v]) => k !== "0" && v > 0)
                     .map(([sizeStr, expectedCount]) => {
                       const targetSize = parseFloat(sizeStr);
                       const actualCount = getActualCount(targetSize);
                       const isSatisfied = actualCount === expectedCount;
                       const isOver = actualCount > expectedCount;
                       const badgeClass = isSatisfied ? 'aquarium-badge-satisfied' : isOver ? 'aquarium-badge-over' : 'aquarium-badge-normal';
                       return (
                         <span key={sizeStr} class={`aquarium-badge ${badgeClass}`}>
                           {expectedCount}x[{targetSize}] ({actualCount})
                         </span>
                       );
                     })}
                 </div>
              )}
            </div>
          )}

          <div class={`grid-board-card ${won ? 'is-won pointer-events-none' : ''}`}>
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
