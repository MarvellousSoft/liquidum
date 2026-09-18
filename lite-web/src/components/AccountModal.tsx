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
      className="modal-backdrop fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-4"
      onClick={onClose}
    >
      <div
        className="w-full max-w-lg bg-slate-900 border border-slate-700 rounded-2xl flex flex-col shadow-2xl overflow-hidden text-slate-100 max-h-[90vh]"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-modal="true"
        aria-labelledby="account-modal-title"
      >
        {/* Header */}
        <div className="px-5 py-3.5 border-b border-slate-800 flex items-center justify-between bg-slate-950/40">
          <div className="flex items-center gap-2">
            <span className="text-xl">👤</span>
            <div>
              <h2 id="account-modal-title" className="text-lg font-bold text-cyan-400 leading-tight">
                Player Account & Profile
              </h2>
              <p className="text-[11px] text-slate-400">
                Manage your public name, avatar, and cloud recovery key
              </p>
            </div>
          </div>
          <button
            data-testid="btn-close-account"
            className="p-1 rounded-lg text-slate-400 hover:text-white hover:bg-slate-800 transition text-lg leading-none w-7 h-7 flex items-center justify-center"
            onClick={onClose}
            aria-label="Close"
          >
            ✕
          </button>
        </div>

        {/* Scrollable Content */}
        <div className="overflow-y-auto px-5 py-4 space-y-6 text-xs text-slate-200">
          {/* SECTION 1: PROFILE PICTURE */}
          <div className="bg-slate-800/40 border border-slate-700/60 rounded-xl p-4 space-y-3">
            <h3 className="text-sm font-semibold text-cyan-300 flex items-center gap-1.5">
              <span>🖼️</span> Profile Picture
            </h3>

            <div className="flex items-center gap-4">
              {/* Avatar Preview */}
              <div className="w-14 h-14 rounded-full border-2 border-cyan-400/80 bg-slate-950 flex items-center justify-center shrink-0 overflow-hidden shadow-inner">
                {avatarPreviewUrl && !previewError ? (
                  <img
                    src={avatarPreviewUrl}
                    alt="Avatar preview"
                    className="w-full h-full object-cover"
                    onError={() => setPreviewError(true)}
                  />
                ) : (
                  <span className="text-2xl select-none">🐟</span>
                )}
              </div>

              <div className="flex-1 space-y-2">
                <label className="block text-[11px] text-slate-400 font-medium">
                  Image URL (PNG or JPG)
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="url"
                    data-testid="input-avatar-url"
                    className="bg-slate-950 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100 flex-1 focus:outline-none focus:border-cyan-400 transition"
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
                    className="px-3 py-1.5 bg-cyan-600 hover:bg-cyan-500 active:bg-cyan-700 text-white rounded-lg font-medium transition disabled:opacity-50 shrink-0"
                    onClick={handleSaveAvatar}
                    disabled={avatarSaving}
                  >
                    {avatarSaving ? "..." : "Save"}
                  </button>
                  {avatarUrl && (
                    <button
                      data-testid="btn-remove-avatar"
                      className="px-2.5 py-1.5 bg-slate-800 hover:bg-red-950 hover:text-red-300 text-slate-400 border border-slate-700 rounded-lg transition disabled:opacity-50 shrink-0"
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
                className={`text-[11px] mt-1 ${avatarMessage.type === "success" ? "text-emerald-400" : "text-rose-400"}`}
              >
                {avatarMessage.text}
              </p>
            )}
          </div>

          {/* SECTION 2: DISPLAY NAME */}
          <div className="bg-slate-800/40 border border-slate-700/60 rounded-xl p-4 space-y-3">
            <h3 className="text-sm font-semibold text-cyan-300 flex items-center gap-1.5">
              <span>🏷️</span> Display Name
            </h3>
            <p className="text-[11px] text-slate-400">
              Your name appears on the daily leaderboard. Must be between 3 and 25 characters.
            </p>

            <div className="flex items-center gap-2">
              <input
                type="text"
                data-testid="input-display-name"
                className="bg-slate-950 border border-slate-700 rounded-lg px-3 py-1.5 text-xs text-slate-100 flex-1 focus:outline-none focus:border-cyan-400 transition"
                placeholder="Enter player name"
                value={displayName}
                maxLength={25}
                onInput={(e: any) => setDisplayName(e.target.value)}
                disabled={nameSaving}
              />
              <button
                data-testid="btn-save-display-name"
                className="px-3 py-1.5 bg-cyan-600 hover:bg-cyan-500 active:bg-cyan-700 text-white rounded-lg font-medium transition disabled:opacity-50 shrink-0"
                onClick={handleSaveDisplayName}
                disabled={nameSaving}
              >
                {nameSaving ? "Saving..." : "Save Name"}
              </button>
            </div>

            {nameMessage && (
              <p
                data-testid="name-message"
                className={`text-[11px] mt-1 ${nameMessage.type === "success" ? "text-emerald-400" : "text-rose-400"}`}
              >
                {nameMessage.text}
              </p>
            )}
          </div>

          {/* SECTION 3: ACCOUNT RECOVERY KEY */}
          <div className="bg-slate-800/40 border border-slate-700/60 rounded-xl p-4 space-y-4">
            <div>
              <h3 className="text-sm font-semibold text-cyan-300 flex items-center gap-1.5">
                <span>🔑</span> Account Recovery Key
              </h3>
              <p className="text-[11px] text-slate-400 leading-relaxed mt-1">
                This secret key identifies your player profile on PlayFab. Save it to keep your leaderboard submissions and rank if you switch browsers or devices.
              </p>
            </div>

            {/* Current Key display + copy */}
            <div className="space-y-1.5">
              <label className="block text-[11px] text-slate-400 font-medium">
                Your Current Key
              </label>
              <div className="flex items-center gap-2">
                <input
                  type={isKeyVisible ? "text" : "password"}
                  data-testid="input-recovery-key"
                  readOnly
                  value={recoveryKey}
                  className="bg-slate-950 border border-slate-700 rounded-lg px-3 py-1.5 text-xs font-mono text-slate-300 flex-1 select-all focus:outline-none"
                />
                <button
                  type="button"
                  data-testid="btn-toggle-key-visibility"
                  className="px-2.5 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700 rounded-lg transition shrink-0"
                  onClick={() => setIsKeyVisible(!isKeyVisible)}
                  title={isKeyVisible ? "Hide Key" : "Reveal Key"}
                >
                  {isKeyVisible ? "🙈 Hide" : "👁️ Show"}
                </button>
                <button
                  type="button"
                  data-testid="btn-copy-key"
                  className="px-3.5 py-1.5 bg-cyan-700 hover:bg-cyan-600 active:bg-cyan-800 text-white rounded-lg font-medium transition shrink-0 flex items-center gap-1 shadow-sm"
                  onClick={handleCopyKey}
                >
                  {copySuccess ? "✓ Copied!" : "📋 Copy Key"}
                </button>
              </div>
            </div>

            {/* Restore Account from Key */}
            <div className="pt-3 border-t border-slate-700/50 space-y-2">
              <label className="block text-[11px] text-slate-400 font-medium">
                Restore or Switch Account
              </label>
              <div className="flex items-center gap-2">
                <input
                  type="text"
                  data-testid="input-restore-key"
                  className="bg-slate-950 border border-slate-700 rounded-lg px-3 py-1.5 text-xs font-mono text-slate-100 flex-1 focus:outline-none focus:border-cyan-400 transition"
                  placeholder="Paste recovery key here..."
                  value={restoreKeyInput}
                  onInput={(e: any) => setRestoreKeyInput(e.target.value)}
                  disabled={isRestoring}
                />
                <button
                  type="button"
                  data-testid="btn-restore-key"
                  className="px-3.5 py-1.5 bg-emerald-600 hover:bg-emerald-500 active:bg-emerald-700 text-white rounded-lg font-medium transition disabled:opacity-50 shrink-0 shadow-sm"
                  onClick={handleRestoreAccount}
                  disabled={isRestoring || !restoreKeyInput.trim()}
                >
                  {isRestoring ? "Restoring..." : "Restore Account"}
                </button>
              </div>

              {restoreMessage && (
                <p
                  data-testid="restore-message"
                  className={`text-[11px] mt-1 ${restoreMessage.type === "success" ? "text-emerald-400" : "text-rose-400"}`}
                >
                  {restoreMessage.text}
                </p>
              )}
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="px-5 py-3 border-t border-slate-800 bg-slate-950/40 flex justify-end">
          <button
            className="px-4 py-1.5 bg-slate-800 hover:bg-slate-700 text-slate-200 rounded-lg text-xs font-medium transition"
            onClick={onClose}
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}
