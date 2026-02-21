import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../../hooks/useAuth';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';

export function LoginPage() {
  const { t } = useTranslation('auth');
  const { login, isLoading, error, clearError } = useAuth();
  const [phoneNumber, setPhoneNumber] = useState('');
  const [password, setPassword] = useState('');
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
    setValidationErrors(errors);
    return Object.keys(errors).length === 0;
  }

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    clearError();
    if (!validate()) return;

    try {
      await login({
        phone_number: phoneNumber.replace(/[-\s]/g, ''),
        password,
      });
    } catch {
      // Error is set in store
    }
  }

  return (
    <div>
      <h1 className="mb-6 text-center text-2xl font-bold text-gray-900">
        {t('login.title')}
      </h1>

      {error && (
        <div className="mb-4 rounded-lg bg-red-50 p-3 text-sm text-red-700">
          {t('errors.loginFailed')}
        </div>
      )}

      <form onSubmit={handleSubmit} className="space-y-4">
        <Input
          label={t('login.phoneNumber')}
          type="tel"
          placeholder={t('login.phonePlaceholder')}
          value={phoneNumber}
          onChange={(e) => setPhoneNumber(e.target.value)}
          error={validationErrors.phoneNumber}
          autoComplete="tel"
        />

        <Input
          label={t('login.password')}
          type="password"
          placeholder={t('login.passwordPlaceholder')}
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          error={validationErrors.password}
          autoComplete="current-password"
        />

        <Button type="submit" fullWidth isLoading={isLoading}>
          {t('login.submit')}
        </Button>
      </form>

      <p className="mt-6 text-center text-sm text-gray-600">
        {t('login.noAccount')}{' '}
        <Link to="/register" className="font-medium text-rose-600 hover:text-rose-500">
          {t('login.register')}
        </Link>
      </p>
    </div>
  );
}
