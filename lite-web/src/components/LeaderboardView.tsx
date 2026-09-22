import { h } from "preact";
import { useState, useEffect } from "preact/hooks";
import { createPortal } from "preact/compat";
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
    const previewSize = 80;
    const placeLeft = rect.right + previewSize + 20 > window.innerWidth;
    const x = placeLeft ? rect.left - previewSize - 12 : rect.right + 12;
    const y = rect.top + rect.height / 2;
    const clampedX = Math.max(8, x);
    const clampedY = Math.max(previewSize / 2 + 8, Math.min(window.innerHeight - previewSize / 2 - 8, y));
    setPreviewAvatar({ url, x: clampedX, y: clampedY });
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
      class={`${
        isSidePanel
          ? "leaderboard-panel h-full max-h-[640px] w-full"
          : "shortcuts-dialog w-full max-w-lg max-h-[85vh]"
      } ${className}`}
      data-testid={isSidePanel ? "side-leaderboard-view" : "modal-leaderboard-view"}
    >
      {/* Header */}
      <div class="shortcuts-header shrink-0">
        <div class="flex items-center gap-2">
          <span class="text-xl select-none">🏆</span>
          <div>
            <h2 id="leaderboard-title" class="shortcuts-title godot-text-outline leading-tight">
              Daily Leaderboard
            </h2>
            <p class="text-[11px] text-[rgba(217,255,226,0.7)]">
              {activeTab === "today" ? `Today • ${todayDate}` : `Yesterday • ${yesterdayDate}`}
            </p>
          </div>
        </div>
        {onClose && (
          <button
            data-testid="btn-close-leaderboard"
            class="shortcuts-close-btn"
            onClick={onClose}
            aria-label="Close"
            title="Close (Esc)"
          >
            ✕
          </button>
        )}
      </div>

      {/* Tabs */}
      <div class="leaderboard-tabs shrink-0">
        <button
          class={`leaderboard-tab ${activeTab === "today" ? "active" : ""}`}
          onClick={() => setActiveTab("today")}
        >
          Today
        </button>
        <button
          class={`leaderboard-tab ${activeTab === "yesterday" ? "active" : ""}`}
          onClick={() => setActiveTab("yesterday")}
        >
          Yesterday
        </button>
      </div>

      {/* User Profile Bar */}
      <div class="leaderboard-user-bar shrink-0">
        {isEditingName ? (
          <div class="flex flex-col gap-1.5 w-full">
            <div class="flex items-center gap-2">
              <input
                type="text"
                class="game-input text-xs flex-1 py-1 px-2.5"
                value={nameInput}
                onInput={(e: any) => setNameInput(e.target.value)}
                placeholder="Enter name (3-25 chars)"
                maxLength={25}
                disabled={nameSaving}
              />
              <button
                class="btn-shortcuts text-xs py-1 px-3"
                onClick={handleSaveName}
                disabled={nameSaving}
              >
                {nameSaving ? "..." : "Save"}
              </button>
              <button
                class="btn-secondary text-xs py-1 px-2.5"
                onClick={() => {
                  setIsEditingName(false);
                  setNameError(null);
                }}
                disabled={nameSaving}
              >
                Cancel
              </button>
            </div>
            {nameError && (
              <span class="text-[var(--stat-error)] text-[11px] font-semibold">{nameError}</span>
            )}
          </div>
        ) : (
          <div class="flex items-center justify-between w-full">
            <div class="flex items-center gap-2">
              {currentAvatarUrl ? (
                <img
                  src={currentAvatarUrl}
                  alt=""
                  class="w-6 h-6 rounded-full object-cover border-2 border-[var(--cell-wall)] bg-[rgba(0,9,36,0.6)] cursor-pointer hover:scale-125 transition-transform duration-150 shrink-0 shadow-sm"
                  onMouseEnter={(e) => handleAvatarMouseEnter(currentAvatarUrl, e)}
                  onMouseLeave={handleAvatarMouseLeave}
                />
              ) : (
                <span class="w-6 h-6 rounded-full bg-[rgba(0,9,36,0.6)] border-2 border-[var(--cell-wall)] flex items-center justify-center text-[11px] shrink-0 select-none">
                  🐟
                </span>
              )}
              <div class="flex items-center gap-1.5 leading-tight">
                <span class="font-bold text-white truncate max-w-[130px] font-game text-xs">
                  {currentDisplayName || "Anonymous"}
                </span>
                {currentFlair && (
                  <span
                    data-testid="user-profile-flair"
                    class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-bold font-mono border leading-none gap-0.5 flex-shrink-0 cursor-help"
                    style={{
                      color: currentFlair.color,
                      borderColor: `${currentFlair.color}66`,
                      backgroundColor: `${currentFlair.color}1f`,
                    }}
                    title={currentFlair.description}
                  >
                    <span>{currentFlair.text}</span>
                    {currentFlair.extraFlairs > 0 && (
                      <span class="text-[8px] opacity-80">+{currentFlair.extraFlairs}</span>
                    )}
                  </span>
                )}
              </div>
              <button
                class="text-[var(--stat-satisfied)] hover:text-white underline text-[11px] font-game ml-0.5 cursor-pointer transition-colors"
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
              <div class="text-[rgba(217,255,226,0.8)] text-[11px] font-game">
                Rank: <span class="font-bold text-[var(--stat-satisfied)]">#{userEntry.position}</span>
              </div>
            )}
          </div>
        )}
      </div>

      {/* Content Table / States */}
      <div class="p-3 flex-1 overflow-y-auto min-h-[160px]">
        {loading ? (
          <div class="flex flex-col items-center justify-center py-10 text-[rgba(217,255,226,0.6)]">
            <span class="text-2xl animate-spin mb-2 select-none">⏳</span>
            <p class="text-xs font-game">Loading leaderboard...</p>
          </div>
        ) : error ? (
          <div class="flex flex-col items-center justify-center py-8 text-center">
            <p class="text-xs text-[var(--stat-error)] font-semibold mb-2">{error}</p>
            <button
              class="btn-shortcuts text-xs py-1 px-3"
              onClick={loadLeaderboard}
            >
              🔄 Retry
            </button>
          </div>
        ) : entries.length === 0 ? (
          <div class="text-center py-10 text-[rgba(217,255,226,0.6)] text-xs font-game">
            No scores recorded yet for this day.
          </div>
        ) : (
          <table class="leaderboard-table">
            <thead>
              <tr>
                <th class="py-2 px-1.5 w-8 text-center">#</th>
                <th class="py-2 px-2">Player</th>
                <th class="py-2 px-2 text-center w-16">Mistakes</th>
                <th class="py-2 px-2 text-right w-16">Time</th>
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
                    class={entry.isCurrentUser ? "is-current-user" : ""}
                  >
                    <td class="py-2 px-1.5 text-center font-mono">
                      {medal ? <span class="text-sm select-none">{medal}</span> : entry.position}
                    </td>
                    <td class="py-2 px-2">
                      <div class="flex items-center gap-1.5 truncate max-w-[180px]">
                        {entry.avatarUrl ? (
                          <img
                            src={entry.avatarUrl}
                            alt=""
                            class="w-4 h-4 rounded-full object-cover border border-[rgba(217,255,226,0.3)] bg-[rgba(0,9,36,0.5)] flex-shrink-0 cursor-pointer hover:scale-125 transition-transform duration-150"
                            onMouseEnter={(e) => handleAvatarMouseEnter(entry.avatarUrl!, e)}
                            onMouseLeave={handleAvatarMouseLeave}
                          />
                        ) : (
                          <span class="w-4 h-4 rounded-full bg-[rgba(0,9,36,0.5)] border border-[rgba(217,255,226,0.2)] flex items-center justify-center text-[9px] flex-shrink-0 select-none">
                            🐟
                          </span>
                        )}
                        <span class="truncate font-game text-xs">{entry.displayName}</span>
                        {entry.flair && (
                          <span
                            data-testid={`flair-${entry.playFabId}`}
                            class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-bold font-mono border leading-none gap-0.5 flex-shrink-0 cursor-help transition-transform hover:scale-105"
                            style={{
                              color: entry.flair.color,
                              borderColor: `${entry.flair.color}66`,
                              backgroundColor: `${entry.flair.color}1f`,
                            }}
                            title={entry.flair.description}
                          >
                            <span>{entry.flair.text}</span>
                            {entry.flair.extraFlairs > 0 && (
                              <span class="text-[8px] opacity-80">+{entry.flair.extraFlairs}</span>
                            )}
                          </span>
                        )}
                        {entry.isCurrentUser && (
                          <span class="text-[10px] text-[var(--stat-satisfied)] font-semibold flex-shrink-0">
                            (You)
                          </span>
                        )}
                      </div>
                    </td>
                    <td class="py-2 px-2 text-center font-mono opacity-90">
                      {entry.mistakes}
                    </td>
                    <td class="py-2 px-2 text-right font-mono opacity-90">
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
      {previewAvatar && typeof document !== "undefined" && createPortal(
        <div
          data-testid="avatar-preview-popover"
          class="leaderboard-avatar-preview"
          style={{ left: `${previewAvatar.x}px`, top: `${previewAvatar.y}px` }}
        >
          <img
            src={previewAvatar.url}
            alt="Avatar preview"
            class="w-16 h-16 rounded-lg object-cover shadow"
          />
        </div>,
        document.querySelector(".game-container") || document.body
      )}

      {/* Footer (if in modal) */}
      {onClose && (
        <div class="px-5 py-3 border-t-2 border-[rgba(217,255,226,0.15)] bg-[rgba(0,9,36,0.25)] flex justify-end shrink-0">
          <button
            class="btn-secondary"
            onClick={onClose}
          >
            Close
          </button>
        </div>
      )}
    </div>
  );
}
