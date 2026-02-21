import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../../hooks/useAuth';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';

type Gender = 'male' | 'female' | 'other';

export function RegisterPage() {
  const { t } = useTranslation('auth');
  const { register, isLoading, error, clearError } = useAuth();

  const [phoneNumber, setPhoneNumber] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [gender, setGender] = useState<Gender | ''>('');
  const [dateOfBirth, setDateOfBirth] = useState('');
  const [validationErrors, setValidationErrors] = useState<Record<string, string>>({});

  function validate(): boolean {
    const errors: Record<string, string> = {};

    if (!phoneNumber.trim()) {
      errors.phoneNumber = t('errors.phoneRequired');
    } else if (!/^0[789]0-?\d{4}-?\d{4}$/.test(phoneNumber.replace(/[-\s]/g, ''))) {
      errors.phoneNumber = t('errors.invalidPhone');
    }

    if (!password) {
      errors.password = t('errors.passwordRequired');
    } else if (password.length < 8) {
      errors.password = t('errors.passwordTooShort');
    }

    if (password !== confirmPassword) {
      errors.confirmPassword = t('errors.passwordMismatch');
    }

    if (!gender) {
      errors.gender = t('errors.genderRequired');
    }

    if (!dateOfBirth) {
      errors.dateOfBirth = t('errors.dobRequired');
    }

    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    clearError();
    if (!validate()) return;

    try {
      await register({
        phone_number: phoneNumber.replace(/[-\s]/g, ''),
        password,
        gender: gender as Gender,
        date_of_birth: dateOfBirth,
      });
    } catch {
      // Error is set in store
    }
  }

  return (
    <div>
      <h1 className="mb-6 text-center text-2xl font-bold text-gray-900">
        {t('register.title')}
      </h1>

      {error && (
        <div className="mb-4 rounded-lg bg-red-50 p-3 text-sm text-red-700">
          {t('errors.registerFailed')}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <Input
          label={t('register.phoneNumber')}
          type="tel"
          placeholder={t('register.phonePlaceholder')}
          value={phoneNumber}
          onChange={(e) => setPhoneNumber(e.target.value)}
          error={validationErrors.phoneNumber}
          autoComplete="tel"
        />

        <Input
          label={t('register.password')}
          type="password"
          placeholder={t('register.passwordPlaceholder')}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          error={validationErrors.password}
          autoComplete="new-password"
        />

        <Input
          label={t('register.confirmPassword')}
          type="password"
          placeholder={t('register.confirmPasswordPlaceholder')}
          value={confirmPassword}
          onChange={(e) => setConfirmPassword(e.target.value)}
          error={validationErrors.confirmPassword}
          autoComplete="new-password"
        />

        <div className="w-full">
          <label className="mb-1 block text-sm font-medium text-gray-700">
            {t('register.gender')}
          </label>
          <div className="grid grid-cols-3 gap-2">
            {(['male', 'female', 'other'] as const).map((g) => (
              <button
                key={g}
                type="button"
                onClick={() => setGender(g)}
                className={`rounded-lg border px-3 py-2 text-sm font-medium transition-colors ${
                  gender === g
                    ? 'border-rose-500 bg-rose-50 text-rose-700'
                    : 'border-gray-300 text-gray-700 hover:bg-gray-50'
                }`}
              >
                {t(`register.genderOptions.${g}`)}
              </button>
            ))}
          </div>
          {validationErrors.gender && (
            <p className="mt-1 text-sm text-red-600">{validationErrors.gender}</p>
          )}
        </div>

        <Input
          label={t('register.dateOfBirth')}
          type="date"
          value={dateOfBirth}
          onChange={(e) => setDateOfBirth(e.target.value)}
          error={validationErrors.dateOfBirth}
          max={new Date(new Date().setFullYear(new Date().getFullYear() - 18))
            .toISOString()
            .split('T')[0]}
        />

        <Button type="submit" fullWidth isLoading={isLoading}>
          {t('register.submit')}
        </Button>

        <p className="text-center text-xs text-gray-500">
          {t('register.termsNotice')}
        </p>
      </form>

      <p className="mt-6 text-center text-sm text-gray-600">
        {t('register.hasAccount')}{' '}
        <Link to="/login" className="font-medium text-rose-600 hover:text-rose-500">
          {t('register.login')}
        </Link>
      </p>
    </div>
  );
}
