import { h } from "preact";
import { useState, useEffect } from "preact/hooks";
import {
  playFabService,
  getDailyLeaderboardVersion,
  getDateStringForOffset,
  type LeaderboardEntry,
} from "../engine/PlayFabService";
import type { FlairInfo } from "../engine/FlairManager";

export interface LeaderboardViewProps {
  onClose?: () => void;
  isSidePanel?: boolean;
  className?: string;
  refreshTrigger?: number;
}

type TabType = "today" | "yesterday";

function formatTime(seconds: number): string {
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  return `${mins}:${secs.toString().padStart(2, "0")}`;
}

export function LeaderboardView({
  onClose,
  isSidePanel = false,
  className = "",
  refreshTrigger = 0,
}: LeaderboardViewProps) {
  const [activeTab, setActiveTab] = useState<TabType>("today");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [entries, setEntries] = useState<LeaderboardEntry[]>([]);

  // Display name editing
  const [isEditingName, setIsEditingName] = useState(false);
  const [nameInput, setNameInput] = useState("");
  const [nameError, setNameError] = useState<string | null>(null);
  const [nameSaving, setNameSaving] = useState(false);
  const [currentDisplayName, setCurrentDisplayName] = useState<string>("");
  const [currentAvatarUrl, setCurrentAvatarUrl] = useState<string | null>(null);
  const [currentFlair, setCurrentFlair] = useState<FlairInfo | null>(null);

  // Avatar hover preview popover
  const [previewAvatar, setPreviewAvatar] = useState<{ url: string; x: number; y: number } | null>(null);

  const handleAvatarMouseEnter = (url: string, e: any) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const previewSize = 72;
    const placeLeft = rect.right + previewSize + 20 > window.innerWidth;
    const x = placeLeft ? rect.left - previewSize - 12 : rect.right + 12;
    const y = rect.top + rect.height / 2;
    setPreviewAvatar({ url, x, y });
  };

  const handleAvatarMouseLeave = () => {
    setPreviewAvatar(null);
  };

  const todayDate = getDateStringForOffset(0);
  const yesterdayDate = getDateStringForOffset(-1);

  const activeDate = activeTab === "today" ? todayDate : yesterdayDate;
  const activeVersion = getDailyLeaderboardVersion(activeDate);

  const loadLeaderboard = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await playFabService.getLeaderboard(activeVersion);
      setEntries(data);
      setCurrentDisplayName(playFabService.getDisplayName() || "Anonymous");
      setCurrentAvatarUrl(playFabService.getAvatarUrl());
      setCurrentFlair(playFabService.getFlair());
    } catch (err: any) {
      setError(err?.errorMessage || err?.message || "Failed to load leaderboard");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadLeaderboard();
  }, [activeTab, refreshTrigger]);

  const handleSaveName = async () => {
    const trimmed = nameInput.trim();
    if (trimmed.length < 3 || trimmed.length > 25) {
      setNameError("Name must be between 3 and 25 characters");
      return;
    }
    setNameSaving(true);
    setNameError(null);
    try {
      const updated = await playFabService.updateDisplayName(trimmed);
      setCurrentDisplayName(updated);
      setIsEditingName(false);
      loadLeaderboard();
    } catch (err: any) {
      setNameError(err?.errorMessage || err?.message || "Failed to update name");
    } finally {
      setNameSaving(false);
    }
  };

  const userEntry = entries.find((e) => e.isCurrentUser);

  return (
    <div
      className={`bg-slate-900 border border-slate-700 rounded-2xl flex flex-col shadow-2xl overflow-hidden text-slate-100 ${
        isSidePanel ? "h-full max-h-[640px] w-full" : "w-full max-w-lg max-h-[85vh]"
      } ${className}`}
      data-testid={isSidePanel ? "side-leaderboard-view" : "modal-leaderboard-view"}
    >
      {/* Header */}
      <div className="px-5 py-3.5 border-b border-slate-800 flex items-center justify-between bg-slate-950/40">
        <div className="flex items-center gap-2">
          <span className="text-xl">🏆</span>
          <div>
            <h2 id="leaderboard-title" className="text-lg font-bold text-cyan-400 leading-tight">
              Daily Leaderboard
            </h2>
            <p className="text-[11px] text-slate-400">
              {activeTab === "today" ? `Today • ${todayDate}` : `Yesterday • ${yesterdayDate}`}
            </p>
          </div>
        </div>
        {onClose && (
          <button
            className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition text-lg leading-none w-7 h-7 flex items-center justify-center"
            onClick={onClose}
            aria-label="Close"
          >
            ✕
          </button>
        )}
      </div>

      {/* Tabs */}
      <div className="flex border-b border-slate-800 bg-slate-950/20">
        <button
          className={`flex-1 py-2.5 text-xs font-semibold transition border-b-2 ${
            activeTab === "today"
              ? "border-cyan-400 text-cyan-400 bg-slate-800/40"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
          onClick={() => setActiveTab("today")}
        >
          Today
        </button>
        <button
          className={`flex-1 py-2.5 text-xs font-semibold transition border-b-2 ${
            activeTab === "yesterday"
              ? "border-cyan-400 text-cyan-400 bg-slate-800/40"
              : "border-transparent text-slate-400 hover:text-slate-200"
          }`}
          onClick={() => setActiveTab("yesterday")}
        >
          Yesterday
        </button>
      </div>

      {/* User Profile Bar */}
      <div className="px-4 py-2.5 bg-slate-800/50 border-b border-slate-800/80 flex items-center justify-between text-xs">
        {isEditingName ? (
          <div className="flex flex-col gap-1 w-full">
            <div className="flex items-center gap-2">
              <input
                type="text"
                className="bg-slate-900 border border-slate-600 rounded px-2 py-1 text-slate-100 text-xs flex-1 focus:outline-none focus:border-cyan-400"
                value={nameInput}
                onInput={(e: any) => setNameInput(e.target.value)}
                placeholder="Enter name (3-25 chars)"
                maxLength={25}
                disabled={nameSaving}
              />
              <button
                className="px-2.5 py-1 bg-cyan-600 hover:bg-cyan-500 text-white rounded font-medium disabled:opacity-50"
                onClick={handleSaveName}
                disabled={nameSaving}
              >
                {nameSaving ? "..." : "Save"}
              </button>
              <button
                className="px-2 py-1 bg-slate-700 hover:bg-slate-600 text-slate-300 rounded"
                onClick={() => {
                  setIsEditingName(false);
                  setNameError(null);
                }}
                disabled={nameSaving}
              >
                Cancel
              </button>
            </div>
            {nameError && <span className="text-red-400 text-[11px]">{nameError}</span>}
          </div>
        ) : (
          <div className="flex items-center justify-between w-full">
            <div className="flex items-center gap-2">
              {currentAvatarUrl ? (
                <img
                  src={currentAvatarUrl}
                  alt=""
                  className="w-6 h-6 rounded-full object-cover border border-cyan-400/50 cursor-pointer hover:scale-125 transition-transform duration-150"
                  onMouseEnter={(e) => handleAvatarMouseEnter(currentAvatarUrl, e)}
                  onMouseLeave={handleAvatarMouseLeave}
                />
              ) : (
                <span className="w-6 h-6 rounded-full bg-cyan-950 border border-cyan-500/40 flex items-center justify-center text-[11px]">
                  🐟
                </span>
              )}
              <div className="flex items-center gap-1.5 leading-tight">
                <span className="font-semibold text-slate-200 truncate max-w-[130px]">
                  {currentDisplayName || "Anonymous"}
                </span>
                {currentFlair && (
                  <span
                    data-testid="user-profile-flair"
                    className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-bold font-mono border leading-none gap-0.5 flex-shrink-0 cursor-help"
                    style={{
                      color: currentFlair.color,
                      borderColor: `${currentFlair.color}66`,
                      backgroundColor: `${currentFlair.color}1f`,
                    }}
                    title={currentFlair.description}
                  >
                    <span>{currentFlair.text}</span>
                    {currentFlair.extraFlairs > 0 && (
                      <span className="text-[8px] opacity-80">+{currentFlair.extraFlairs}</span>
                    )}
                  </span>
                )}
              </div>
              <button
                className="text-cyan-400 hover:text-cyan-300 underline text-[11px] ml-0.5"
                onClick={() => {
                  setNameInput(currentDisplayName || "");
                  setNameError(null);
                  setIsEditingName(true);
                }}
              >
                Edit Name
              </button>
            </div>
            {userEntry && (
              <div className="text-slate-300 text-[11px]">
                Rank: <span className="font-bold text-cyan-400">#{userEntry.position}</span>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Content Table / States */}
      <div className="p-3 flex-1 overflow-y-auto min-h-[160px]">
        {loading ? (
          <div className="flex flex-col items-center justify-center py-10 text-slate-400">
            <span className="text-2xl animate-spin mb-2">⏳</span>
            <p className="text-xs">Loading leaderboard...</p>
          </div>
        ) : error ? (
          <div className="flex flex-col items-center justify-center py-8 text-center">
            <p className="text-xs text-red-400 mb-2">{error}</p>
            <button
              className="px-3 py-1 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-md text-xs font-semibold"
              onClick={loadLeaderboard}
            >
              🔄 Retry
            </button>
          </div>
        ) : entries.length === 0 ? (
          <div className="text-center py-10 text-slate-400 text-xs">
            No scores recorded yet for this day.
          </div>
        ) : (
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="text-slate-400 border-b border-slate-800 text-[11px]">
                <th className="py-1.5 px-1.5 w-8 text-center">#</th>
                <th className="py-1.5 px-2">Player</th>
                <th className="py-1.5 px-2 text-center w-14">Mistakes</th>
                <th className="py-1.5 px-2 text-right w-14">Time</th>
              </tr>
            </thead>
            <tbody>
              {entries.map((entry) => {
                let medal = null;
                if (entry.position === 1) medal = "🥇";
                else if (entry.position === 2) medal = "🥈";
                else if (entry.position === 3) medal = "🥉";

                return (
                  <tr
                    key={entry.playFabId + entry.position}
                    className={`border-b border-slate-800/40 hover:bg-slate-800/30 transition ${
                      entry.isCurrentUser
                        ? "bg-cyan-950/40 text-cyan-300 font-semibold border-cyan-800/50"
                        : "text-slate-200"
                    }`}
                  >
                    <td className="py-1.5 px-1.5 text-center font-mono">
                      {medal ? <span className="text-sm">{medal}</span> : entry.position}
                    </td>
                    <td className="py-1.5 px-2">
                      <div className="flex items-center gap-1.5 truncate max-w-[180px]">
                        {entry.avatarUrl ? (
                          <img
                            src={entry.avatarUrl}
                            alt=""
                            className="w-4 h-4 rounded-full object-cover border border-slate-700 flex-shrink-0 cursor-pointer hover:scale-125 transition-transform duration-150"
                            onMouseEnter={(e) => handleAvatarMouseEnter(entry.avatarUrl!, e)}
                            onMouseLeave={handleAvatarMouseLeave}
                          />
                        ) : (
                          <span className="w-4 h-4 rounded-full bg-slate-800 border border-slate-700 flex items-center justify-center text-[9px] flex-shrink-0">
                            🐟
                          </span>
                        )}
                        <span className="truncate">{entry.displayName}</span>
                        {entry.flair && (
                          <span
                            data-testid={`flair-${entry.playFabId}`}
                            className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-bold font-mono border leading-none gap-0.5 flex-shrink-0 cursor-help transition-transform hover:scale-105"
                            style={{
                              color: entry.flair.color,
                              borderColor: `${entry.flair.color}66`,
                              backgroundColor: `${entry.flair.color}1f`,
                            }}
                            title={entry.flair.description}
                          >
                            <span>{entry.flair.text}</span>
                            {entry.flair.extraFlairs > 0 && (
                              <span className="text-[8px] opacity-80">+{entry.flair.extraFlairs}</span>
                            )}
                          </span>
                        )}
                        {entry.isCurrentUser && (
                          <>
                            {" "}
                            <span className="text-[10px] text-cyan-400 font-normal flex-shrink-0">
                              (You)
                            </span>
                          </>
                        )}
                      </div>
                    </td>
                    <td className="py-1.5 px-2 text-center font-mono text-slate-300">
                      {entry.mistakes}
                    </td>
                    <td className="py-1.5 px-2 text-right font-mono text-slate-300">
                      {formatTime(entry.seconds)}
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>

      {/* Floating avatar hover preview */}
      {previewAvatar && (
        <div
          data-testid="avatar-preview-popover"
          className="fixed z-[9999] pointer-events-none -translate-y-1/2 bg-slate-950/95 border-2 border-cyan-400/80 rounded-xl p-1.5 shadow-2xl backdrop-blur-md transition-all duration-150 flex flex-col items-center"
          style={{ left: `${previewAvatar.x}px`, top: `${previewAvatar.y}px` }}
        >
          <img
            src={previewAvatar.url}
            alt="Avatar preview"
            className="w-16 h-16 rounded-lg object-cover shadow"
          />
        </div>
      )}

      {/* Footer (if in modal) */}
      {onClose && (
        <div className="px-4 py-2.5 border-t border-slate-800 bg-slate-950/40 flex justify-end">
          <button
            className="px-3.5 py-1 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-lg text-xs font-semibold transition"
            onClick={onClose}
          >
            Close
          </button>
        </div>
      )}
    </div>
  );
}
