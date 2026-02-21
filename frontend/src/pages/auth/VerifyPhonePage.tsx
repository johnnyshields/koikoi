import { useState, useEffect, useRef, useCallback } from 'react';
import type { KeyboardEvent, ClipboardEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../../hooks/useAuth';
import { Button } from '../../components/ui/Button';
import { toast } from '../../components/ui/Toast';

const CODE_LENGTH = 6;
const RESEND_COOLDOWN = 60;

export function VerifyPhonePage() {
  const { t } = useTranslation('auth');
  const navigate = useNavigate();
  const { user, requestVerificationCode, verifyPhone } = useAuth();

  const [digits, setDigits] = useState<string[]>(Array(CODE_LENGTH).fill(''));
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState('');
  const [cooldown, setCooldown] = useState(0);
  const inputRefs = useRef<(HTMLInputElement | null)[]>([]);

  useEffect(() => {
    if (cooldown > 0) {
      const timer = setTimeout(() => setCooldown((c) => c - 1), 1000);
      return () => clearTimeout(timer);
    }
  }, [cooldown]);

  const submitCode = useCallback(
    async (code: string) => {
      if (!user?.phone_number) return;
      setIsSubmitting(true);
      setError('');
      try {
        await verifyPhone(user.phone_number, code);
        toast(t('verify.success'), 'success');
        navigate('/');
      } catch {
        setError(t('errors.verificationFailed'));
        setDigits(Array(CODE_LENGTH).fill(''));
        inputRefs.current[0]?.focus();
      } finally {
        setIsSubmitting(false);
      }
    },
    [user?.phone_number, verifyPhone, navigate, t]
  );

  function handleChange(index: number, value: string) {
    if (!/^\d*$/.test(value)) return;

    const newDigits = [...digits];
    newDigits[index] = value.slice(-1);
    setDigits(newDigits);

    if (value && index < CODE_LENGTH - 1) {
      inputRefs.current[index + 1]?.focus();
    }

    const code = newDigits.join('');
    if (code.length === CODE_LENGTH) {
      submitCode(code);
    }
  }

  function handleKeyDown(index: number, e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Backspace' && !digits[index] && index > 0) {
      inputRefs.current[index - 1]?.focus();
    }
  }

  function handlePaste(e: ClipboardEvent<HTMLInputElement>) {
    e.preventDefault();
    const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, CODE_LENGTH);
    if (!pasted) return;

    const newDigits = Array(CODE_LENGTH).fill('');
    for (let i = 0; i < pasted.length; i++) {
      newDigits[i] = pasted[i];
    }
    setDigits(newDigits);

    const focusIndex = Math.min(pasted.length, CODE_LENGTH - 1);
    inputRefs.current[focusIndex]?.focus();

    if (pasted.length === CODE_LENGTH) {
      submitCode(pasted);
    }
  }

  async function handleResend() {
    if (cooldown > 0 || !user?.phone_number) return;
    try {
      await requestVerificationCode(user.phone_number);
      setCooldown(RESEND_COOLDOWN);
    } catch {
      setError(t('errors.verificationFailed'));
    }
  }

  return (
    <div>
      <h1 className="mb-2 text-center text-2xl font-bold text-gray-900">
        {t('verify.title')}
      </h1>
      <p className="mb-8 text-center text-sm text-gray-600">
        {t('verify.description')}
      </p>

      {error && (
        <div className="mb-4 rounded-lg bg-red-50 p-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <div className="mb-6 flex justify-center gap-2">
        {digits.map((digit, i) => (
          <input
            key={i}
            ref={(el) => { inputRefs.current[i] = el; }}
            type="text"
            inputMode="numeric"
            maxLength={1}
            value={digit}
            onChange={(e) => handleChange(i, e.target.value)}
            onKeyDown={(e) => handleKeyDown(i, e)}
            onPaste={i === 0 ? handlePaste : undefined}
            disabled={isSubmitting}
            className={`h-12 w-12 rounded-lg border text-center text-xl font-semibold transition-colors
              focus:border-rose-500 focus:outline-none focus:ring-2 focus:ring-rose-500/20
              disabled:cursor-not-allowed disabled:bg-gray-50
              ${error ? 'border-red-300' : 'border-gray-300'}`}
          />
        ))}
      </div>

      <div className="text-center">
        {cooldown > 0 ? (
          <p className="text-sm text-gray-500">
            {t('verify.resendCountdown', { seconds: cooldown })}
          </p>
        ) : (
          <Button variant="ghost" size="sm" onClick={handleResend}>
            {t('verify.resend')}
          </Button>
        )}
      </div>
    </div>
  );
}
