import { h } from "preact";
import { useEffect, useState } from "preact/hooks";
import { useTranslation } from "../i18n";
import { useModalScrollLock } from "../utils/scrollLock";
import { SteamIcon } from "./SteamIcon";

export interface SteamSyncModalProps {
  isOpen: boolean;
  incomingId: string;
  onConfirm: () => void | Promise<void>;
  onCancel: () => void;
}

export function SteamSyncModal({ isOpen, incomingId, onConfirm, onCancel }: SteamSyncModalProps) {
  useModalScrollLock(isOpen);
  const { t } = useTranslation();
  const [isSubmitting, setIsSubmitting] = useState(false);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === "Escape" && !isSubmitting) {
        onCancel();
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [onCancel, isSubmitting]);

  if (!isOpen) return null;

  const handleConfirm = async () => {
    setIsSubmitting(true);
    try {
      await onConfirm();
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <div
      data-testid="steam-sync-modal"
      class="modal-backdrop"
      onClick={isSubmitting ? undefined : onCancel}
      onTouchMove={(e) => {
        if (e.target === e.currentTarget) {
          e.preventDefault();
        }
      }}
    >
      <div
        class="shortcuts-dialog max-w-md w-full mx-4"
        onClick={(e) => e.stopPropagation()}
      >
        <div class="shortcuts-header">
          <div class="flex items-center gap-2">
            <SteamIcon class="w-6 h-6 text-[#66c0f4]" />
            <h2 class="shortcuts-title godot-text-outline">{t("account.sync_steam_title")}</h2>
          </div>
          <button
            data-testid="btn-close-steam-sync"
            onClick={onCancel}
            disabled={isSubmitting}
            class="shortcuts-close-btn"
            title={t("account.close")}
            aria-label={t("account.close")}
          >
            ✕
          </button>
        </div>

        <div class="shortcuts-content p-5 space-y-4">
          <p class="text-sm text-[rgba(217,255,226,0.9)] leading-relaxed">
            {t("account.sync_steam_desc")}
          </p>
          <div class="p-3 bg-[rgba(0,9,36,0.4)] border border-[rgba(217,255,226,0.15)] rounded-lg">
            <span class="block text-[11px] text-[rgba(217,255,226,0.6)] uppercase font-semibold mb-1">
              {t("account.recovery_key_title")}
            </span>
            <code class="text-xs font-mono text-[var(--game-mint)] break-all select-all">
              {incomingId}
            </code>
          </div>
        </div>

        <div class="px-5 py-4 border-t border-[rgba(217,255,226,0.15)] bg-[rgba(0,9,36,0.2)] flex flex-col sm:flex-row gap-2.5 justify-end shrink-0">
          <button
            type="button"
            data-testid="btn-steam-sync-cancel"
            class="btn-secondary text-xs px-4 py-2 order-2 sm:order-1 justify-center"
            onClick={onCancel}
            disabled={isSubmitting}
          >
            {t("account.sync_steam_cancel")}
          </button>
          <button
            type="button"
            data-testid="btn-steam-sync-confirm"
            class="btn-shortcuts text-xs px-4 py-2 order-1 sm:order-2 justify-center flex items-center gap-1.5 font-bold"
            onClick={handleConfirm}
            disabled={isSubmitting}
          >
            <SteamIcon class="w-4 h-4" />
            <span>{isSubmitting ? t("account.saving") : t("account.sync_steam_confirm")}</span>
          </button>
        </div>
      </div>
    </div>
  );
}
