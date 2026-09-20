import { h } from "preact";
import { useState, useEffect } from "preact/hooks";
import { playFabService, type PlayerProfileEvent } from "../engine/PlayFabService";

interface AccountModalProps {
  isOpen: boolean;
  onClose: () => void;
  onAccountUpdated?: () => void;
}

export function AccountModal({ isOpen, onClose, onAccountUpdated }: AccountModalProps) {
  if (!isOpen) return null;

  const [displayName, setDisplayName] = useState<string>(playFabService.getDisplayName() || "Anonymous");
  const [avatarUrl, setAvatarUrl] = useState<string>(playFabService.getAvatarUrl() || "");
  const [avatarPreviewUrl, setAvatarPreviewUrl] = useState<string>(playFabService.getAvatarUrl() || "");
  const [previewError, setPreviewError] = useState<boolean>(false);
  const [recoveryKey, setRecoveryKey] = useState<string>(() => playFabService.getCustomId());
  const [isKeyVisible, setIsKeyVisible] = useState<boolean>(false);
  const [copySuccess, setCopySuccess] = useState<boolean>(false);

  // Name editing state
  const [nameSaving, setNameSaving] = useState<boolean>(false);
  const [nameMessage, setNameMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  // Avatar editing state
  const [avatarSaving, setAvatarSaving] = useState<boolean>(false);
  const [avatarMessage, setAvatarMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  // Key restore state
  const [restoreKeyInput, setRestoreKeyInput] = useState<string>("");
  const [restoreMessage, setRestoreMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);
  const [isRestoring, setIsRestoring] = useState<boolean>(false);

  // Sync profile data on open or when profile events fire
  useEffect(() => {
    setDisplayName(playFabService.getDisplayName() || "Anonymous");
    const currentAvatar = playFabService.getAvatarUrl() || "";
    setAvatarUrl(currentAvatar);
    setAvatarPreviewUrl(currentAvatar);
    setRecoveryKey(playFabService.getCustomId());

    const unsubscribe = playFabService.onProfileChange((profile: PlayerProfileEvent) => {
      if (profile.displayName) setDisplayName(profile.displayName);
      const av = profile.avatarUrl || "";
      setAvatarUrl(av);
      setAvatarPreviewUrl(av);
      setRecoveryKey(playFabService.getCustomId());
    });

    return () => unsubscribe();
  }, [isOpen]);

  // Handle escape key to close
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape") {
        onClose();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onClose]);

  // 1. Save Display Name
  const handleSaveDisplayName = async () => {
    const trimmed = displayName.trim();
    if (trimmed.length < 3 || trimmed.length > 25) {
      setNameMessage({ type: "error", text: "Display name must be between 3 and 25 characters" });
      return;
    }
    setNameSaving(true);
    setNameMessage(null);
    try {
      const updated = await playFabService.updateDisplayName(trimmed);
      setDisplayName(updated);
      setNameMessage({ type: "success", text: "Name updated successfully!" });
      onAccountUpdated?.();
    } catch (err: any) {
      setNameMessage({
        type: "error",
        text: err?.errorMessage || err?.message || "Failed to update display name",
      });
    } finally {
      setNameSaving(false);
    }
  };

  // 2. Save Avatar URL
  const handleSaveAvatar = async () => {
    const trimmed = avatarUrl.trim();
    setAvatarSaving(true);
    setAvatarMessage(null);
    try {
      const updated = await playFabService.updateAvatarUrl(trimmed);
      setAvatarUrl(updated || "");
      setAvatarPreviewUrl(updated || "");
      setAvatarMessage({
        type: "success",
        text: updated ? "Avatar updated successfully!" : "Avatar removed.",
      });
      onAccountUpdated?.();
    } catch (err: any) {
      setAvatarMessage({
        type: "error",
        text: err?.errorMessage || err?.message || "Failed to update avatar URL",
      });
    } finally {
      setAvatarSaving(false);
    }
  };

  // 3. Remove Avatar
  const handleRemoveAvatar = async () => {
    setAvatarSaving(true);
    setAvatarMessage(null);
    try {
      await playFabService.updateAvatarUrl("");
      setAvatarUrl("");
      setAvatarPreviewUrl("");
      setAvatarMessage({ type: "success", text: "Avatar removed." });
      onAccountUpdated?.();
    } catch (err: any) {
      setAvatarMessage({
        type: "error",
        text: err?.errorMessage || err?.message || "Failed to remove avatar",
      });
    } finally {
      setAvatarSaving(false);
    }
  };

  // 4. Copy Recovery Key
  const handleCopyKey = () => {
    if (navigator?.clipboard?.writeText) {
      navigator.clipboard.writeText(recoveryKey);
      setCopySuccess(true);
      setTimeout(() => setCopySuccess(false), 2500);
    }
  };

  // 5. Restore / Switch Account from Key
  const handleRestoreAccount = async () => {
    const cleanKey = restoreKeyInput.trim();
    if (!cleanKey) {
      setRestoreMessage({ type: "error", text: "Please enter a valid recovery key" });
      return;
    }

    if (cleanKey === recoveryKey) {
      setRestoreMessage({ type: "error", text: "This is already the currently active account key" });
      return;
    }

    const confirmed = window.confirm(
      "Restoring this key will switch your browser session to that account. Continue?"
    );
    if (!confirmed) return;

    setIsRestoring(true);
    setRestoreMessage(null);
    try {
      const res = await playFabService.switchAccount(cleanKey);
      setDisplayName(res.displayName || "Anonymous");
      setAvatarUrl(res.avatarUrl || "");
      setAvatarPreviewUrl(res.avatarUrl || "");
      setRecoveryKey(cleanKey);
      setRestoreMessage({ type: "success", text: `Account restored! Welcome, ${res.displayName || "Player"}.` });
      setRestoreKeyInput("");
      onAccountUpdated?.();
    } catch (err: any) {
      setRestoreMessage({
        type: "error",
        text: err?.errorMessage || err?.message || "Failed to restore account from key",
      });
    } finally {
      setIsRestoring(false);
    }
  };

  return (
    <div
      data-testid="account-modal"
      class="modal-backdrop"
      onClick={onClose}
    >
      <div
        class="shortcuts-dialog max-h-[85vh] flex flex-col"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-labelledby="account-modal-title"
        style={{ maxWidth: '540px' }}
      >
        {/* Header */}
        <div class="shortcuts-header shrink-0">
          <div class="flex items-center gap-2">
            <span class="text-xl">👤</span>
            <div>
              <h2 id="account-modal-title" class="shortcuts-title godot-text-outline">
                Player Account & Profile
              </h2>
              <p class="text-[11px] text-[rgba(217,255,226,0.7)]">
                Manage your public name, avatar, and cloud recovery key
              </p>
            </div>
          </div>
          <button
            data-testid="btn-close-account"
            class="shortcuts-close-btn"
            onClick={onClose}
            title="Close (Esc)"
            aria-label="Close"
          >
            ✕
          </button>
        </div>

        {/* Scrollable Content */}
        <div class="shortcuts-content overflow-y-auto space-y-4 pr-1">
          {/* SECTION 1: PROFILE PICTURE */}
          <div class="shortcut-section space-y-3">
            <h3 class="shortcut-section-title">
              <span>🖼️</span> Profile Picture
            </h3>

            <div class="flex items-center gap-4">
              {/* Avatar Preview */}
              <div class="w-14 h-14 rounded-full border-2 border-[var(--cell-wall)] bg-[rgba(0,9,36,0.7)] flex items-center justify-center shrink-0 overflow-hidden shadow-inner">
                {avatarPreviewUrl && !previewError ? (
                  <img
                    src={avatarPreviewUrl}
                    alt="Avatar preview"
                    class="w-full h-full object-cover"
                    onError={() => setPreviewError(true)}
                  />
                ) : (
                  <span class="text-2xl select-none">🐟</span>
                )}
              </div>

              <div class="flex-1 space-y-2">
                <label class="block text-[11px] font-medium text-[rgba(217,255,226,0.7)]">
                  Image URL (PNG or JPG)
                </label>
                <div class="flex items-center gap-2">
                  <input
                    type="url"
                    data-testid="input-avatar-url"
                    class="game-input flex-1 text-xs"
                    placeholder="https://example.com/my-avatar.png"
                    value={avatarUrl}
                    onInput={(e: any) => {
                      setAvatarUrl(e.target.value);
                      setAvatarPreviewUrl(e.target.value.trim());
                      setPreviewError(false);
                    }}
                    disabled={avatarSaving}
                  />
                  <button
                    data-testid="btn-save-avatar"
                    class="btn-shortcuts text-xs shrink-0"
                    onClick={handleSaveAvatar}
                    disabled={avatarSaving}
                  >
                    {avatarSaving ? "..." : "Save"}
                  </button>
                  {avatarUrl && (
                    <button
                      data-testid="btn-remove-avatar"
                      class="btn-secondary-danger text-xs shrink-0"
                      onClick={handleRemoveAvatar}
                      disabled={avatarSaving}
                      title="Remove avatar"
                    >
                      Clear
                    </button>
                  )}
                </div>
              </div>
            </div>

            {avatarMessage && (
              <p
                data-testid="avatar-message"
                class={`text-[11px] mt-1 font-semibold ${avatarMessage.type === "success" ? "text-[var(--stat-satisfied)]" : "text-[var(--stat-error)]"}`}
              >
                {avatarMessage.text}
              </p>
            )}
          </div>

          {/* SECTION 2: DISPLAY NAME */}
          <div class="shortcut-section space-y-3">
            <h3 class="shortcut-section-title">
              <span>🏷️</span> Display Name
            </h3>
            <p class="shortcut-section-hint">
              Your name appears on the daily leaderboard. Must be between 3 and 25 characters.
            </p>

            <div class="flex items-center gap-2">
              <input
                type="text"
                data-testid="input-display-name"
                class="game-input flex-1 text-xs"
                placeholder="Enter player name"
                value={displayName}
                maxLength={25}
                onInput={(e: any) => setDisplayName(e.target.value)}
                disabled={nameSaving}
              />
              <button
                data-testid="btn-save-display-name"
                class="btn-shortcuts text-xs shrink-0"
                onClick={handleSaveDisplayName}
                disabled={nameSaving}
              >
                {nameSaving ? "Saving..." : "Save Name"}
              </button>
            </div>

            {nameMessage && (
              <p
                data-testid="name-message"
                class={`text-[11px] mt-1 font-semibold ${nameMessage.type === "success" ? "text-[var(--stat-satisfied)]" : "text-[var(--stat-error)]"}`}
              >
                {nameMessage.text}
              </p>
            )}
          </div>

          {/* SECTION 3: ACCOUNT RECOVERY KEY */}
          <div class="shortcut-section space-y-4">
            <div>
              <h3 class="shortcut-section-title">
                <span>🔑</span> Account Recovery Key
              </h3>
              <p class="shortcut-section-hint">
                This secret key identifies your player profile on PlayFab. Save it to keep your leaderboard submissions and rank if you switch browsers or devices.
              </p>
            </div>

            {/* Current Key display + copy */}
            <div class="space-y-1.5">
              <label class="block text-[11px] font-medium text-[rgba(217,255,226,0.7)]">
                Your Current Key
              </label>
              <div class="flex items-center gap-2">
                <input
                  type={isKeyVisible ? "text" : "password"}
                  data-testid="input-recovery-key"
                  readOnly
                  value={recoveryKey}
                  class="game-input font-mono text-xs flex-1 select-all"
                />
                <button
                  type="button"
                  data-testid="btn-toggle-key-visibility"
                  class="btn-secondary text-xs shrink-0"
                  onClick={() => setIsKeyVisible(!isKeyVisible)}
                  title={isKeyVisible ? "Hide Key" : "Reveal Key"}
                >
                  {isKeyVisible ? "🙈 Hide" : "👁️ Show"}
                </button>
                <button
                  type="button"
                  data-testid="btn-copy-key"
                  class="btn-shortcuts text-xs shrink-0 flex items-center gap-1"
                  onClick={handleCopyKey}
                >
                  {copySuccess ? "✓ Copied!" : "📋 Copy Key"}
                </button>
              </div>
            </div>

            {/* Restore Account from Key */}
            <div class="pt-3 border-t border-[rgba(217,255,226,0.12)] space-y-2">
              <label class="block text-[11px] font-medium text-[rgba(217,255,226,0.7)]">
                Restore or Switch Account
              </label>
              <div class="flex items-center gap-2">
                <input
                  type="text"
                  data-testid="input-restore-key"
                  class="game-input font-mono text-xs flex-1"
                  placeholder="Paste recovery key here..."
                  value={restoreKeyInput}
                  onInput={(e: any) => setRestoreKeyInput(e.target.value)}
                  disabled={isRestoring}
                />
                <button
                  type="button"
                  data-testid="btn-restore-key"
                  class="btn-shortcuts text-xs shrink-0"
                  onClick={handleRestoreAccount}
                  disabled={isRestoring || !restoreKeyInput.trim()}
                >
                  {isRestoring ? "Restoring..." : "Restore Account"}
                </button>
              </div>

              {restoreMessage && (
                <p
                  data-testid="restore-message"
                  class={`text-[11px] mt-1 font-semibold ${restoreMessage.type === "success" ? "text-[var(--stat-satisfied)]" : "text-[var(--stat-error)]"}`}
                >
                  {restoreMessage.text}
                </p>
              )}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div class="px-5 py-3 border-t border-[rgba(217,255,226,0.15)] bg-[rgba(0,9,36,0.2)] flex justify-end shrink-0">
          <button
            class="btn-secondary text-xs px-4 py-1.5"
            onClick={onClose}
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
