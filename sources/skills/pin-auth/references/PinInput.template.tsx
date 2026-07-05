"use client";

import { useState, useRef, useEffect, useCallback, KeyboardEvent } from "react";
import { cn } from "{{IMPORT_PREFIX}}/utils";

interface PinInputProps {
  onComplete: (pin: string) => void;
  disabled?: boolean;
  countdown?: number | null;
  error?: boolean;
}

export function PinInput({ onComplete, disabled, countdown, error }: PinInputProps) {
  const PIN_LENGTH = {{PIN_LENGTH}};
  const [values, setValues] = useState<string[]>(Array(PIN_LENGTH).fill(""));
  const [focusedIndex, setFocusedIndex] = useState(0);
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

  useEffect(() => { inputRefs.current[0]?.focus(); }, []);

  useEffect(() => {
    if (countdown === 0) {
      setValues(Array(PIN_LENGTH).fill(""));
      setFocusedIndex(0);
      inputRefs.current[0]?.focus();
    }
  }, [countdown]);

  const handleDigitInput = useCallback((index: number, key: string) => {
    const newValues = [...values];
    newValues[index] = key;
    setValues(newValues);
    if (index < PIN_LENGTH - 1) {
      setFocusedIndex(index + 1);
      inputRefs.current[index + 1]?.focus();
    } else {
      const pin = newValues.join("");
      if (pin.length === PIN_LENGTH) onComplete(pin);
    }
  }, [values, onComplete]);

  const handleBackspace = useCallback((index: number) => {
    const newValues = [...values];
    if (newValues[index]) {
      newValues[index] = "";
      setValues(newValues);
    } else if (index > 0) {
      newValues[index - 1] = "";
      setValues(newValues);
      setFocusedIndex(index - 1);
      inputRefs.current[index - 1]?.focus();
    }
  }, [values]);

  const handleArrowNavigation = useCallback((index: number, direction: "left" | "right") => {
    if (direction === "left" && index > 0) {
      setFocusedIndex(index - 1);
      inputRefs.current[index - 1]?.focus();
    } else if (direction === "right" && index < PIN_LENGTH - 1) {
      setFocusedIndex(index + 1);
      inputRefs.current[index + 1]?.focus();
    }
  }, []);

  const handleKeyDown = useCallback((index: number, e: KeyboardEvent<HTMLInputElement>) => {
    if (disabled || countdown) return;
    const key = e.key;
    if (/^[0-9]$/.test(key)) { e.preventDefault(); handleDigitInput(index, key); }
    else if (key === "Backspace") { e.preventDefault(); handleBackspace(index); }
    else if (key === "ArrowLeft") { e.preventDefault(); handleArrowNavigation(index, "left"); }
    else if (key === "ArrowRight") { e.preventDefault(); handleArrowNavigation(index, "right"); }
  }, [disabled, countdown, handleDigitInput, handleBackspace, handleArrowNavigation]);

  const handlePaste = (e: React.ClipboardEvent) => {
    e.preventDefault();
    const pastedData = e.clipboardData.getData("text").replace(/\D/g, "").slice(0, PIN_LENGTH);
    if (pastedData.length === PIN_LENGTH) {
      setValues(pastedData.split(""));
      onComplete(pastedData);
    }
  };

  return (
    <div className="relative flex flex-col items-center justify-center min-h-dvh bg-gray-950">
      {countdown !== null && countdown !== undefined && countdown > 0 && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-gray-950/95">
          <span className="font-mono font-bold text-amber-500 tabular-nums text-[120px]">{countdown}</span>
        </div>
      )}
      <div className="flex flex-col items-center gap-6">
        <h1 className="text-xl font-medium text-white/90">{{LANG_TITLE}}</h1>
        <div className="flex items-center justify-center gap-3">
          {Array.from({ length: PIN_LENGTH }, (_, index) => (
            <div key={index} className={cn(
              "relative w-16 h-[72px] rounded-lg border transition-all duration-200",
              "flex items-center justify-center bg-gray-900",
              focusedIndex === index && !disabled && !countdown
                ? "border-amber-500 ring-1 ring-amber-500/30"
                : "border-gray-700",
              error && "border-red-500/50",
            )}>
              <input
                ref={(el) => { inputRefs.current[index] = el; }}
                type="text" inputMode="numeric" autoComplete="off" maxLength={1}
                value="" onChange={() => {}}
                onKeyDown={(e) => handleKeyDown(index, e)}
                onFocus={() => setFocusedIndex(index)}
                onPaste={handlePaste}
                disabled={disabled || (countdown !== null && countdown !== undefined && countdown > 0)}
                className="absolute inset-0 w-full h-full opacity-0 cursor-default"
                aria-label={`{{LANG_ARIA}} ${index + 1}`}
              />
              {values[index] ? (
                <span className="text-3xl text-amber-500">&#9679;</span>
              ) : focusedIndex === index && !disabled && !countdown ? (
                <span className="text-2xl text-amber-500/70 animate-pulse">|</span>
              ) : null}
            </div>
          ))}
        </div>
        {error && <p className="text-sm text-red-400">{{LANG_ERROR}}</p>}
      </div>
    </div>
  );
}
