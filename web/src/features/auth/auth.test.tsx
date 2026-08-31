import { afterEach, describe, expect, it, vi } from 'vitest';
import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

import { tokens } from '../../api/tokens';
import { en } from '../../i18n/en';
import { mockFetch } from '../../test/fetchMock';
import { renderWithProviders } from '../../test/renderWithProviders';
import { ForgotPasswordPage } from './ForgotPasswordPage';
import { LoginPage } from './LoginPage';
import { RegisterPage } from './RegisterPage';
import { ResetPasswordPage } from './ResetPasswordPage';
import { VerifyEmailPage } from './VerifyEmailPage';

afterEach(() => {
  vi.unstubAllGlobals();
  tokens.clear();
});

/** Parsed JSON body of a mock fetch's most recent call. */
function lastRequestBody(fn: ReturnType<typeof mockFetch>): unknown {
  const call = fn.mock.calls.at(-1);
  if (!call) throw new Error('fetch was not called');
  return JSON.parse((call[1] as RequestInit).body as string);
}

describe('RegisterPage', () => {
  it('registers without establishing a session and shows the check-email panel', async () => {
    const fetchFn = mockFetch({
      'POST /v1/auth/register': {
        status: 201,
        body: { user_id: 'u1', verification_sent: true },
      },
    });
    const user = userEvent.setup();
    renderWithProviders(<RegisterPage />, { path: '/register' });

    await user.type(screen.getByLabelText(en['field.email']), 'a@b.com');
    await user.type(screen.getByLabelText(en['field.password']), 'password123');
    await user.type(
      screen.getByLabelText(en['field.confirmPassword']),
      'password123',
    );
    await user.click(screen.getByRole('button', { name: en['register.submit'] }));

    await screen.findByText(en['register.done.title']);
    expect(fetchFn).toHaveBeenCalledTimes(1);
    expect(tokens.getAccess()).toBeNull();
    expect(tokens.getRefresh()).toBeNull();
  });

  it('blocks submit when the passwords do not match', async () => {
    const fetchFn = mockFetch({});
    const user = userEvent.setup();
    renderWithProviders(<RegisterPage />, { path: '/register' });

    await user.type(screen.getByLabelText(en['field.email']), 'a@b.com');
    await user.type(screen.getByLabelText(en['field.password']), 'password123');
    await user.type(
      screen.getByLabelText(en['field.confirmPassword']),
      'different999',
    );
    await user.click(screen.getByRole('button', { name: en['register.submit'] }));

    expect(screen.getByText(en['field.passwordMismatch'])).toBeInTheDocument();
    expect(fetchFn).not.toHaveBeenCalled();
  });
});

describe('VerifyEmailPage', () => {
  it('consumes the token from the query string and confirms success', async () => {
    const fetchFn = mockFetch({
      'POST /v1/auth/verify-email': { status: 200, body: { verified: true } },
    });
    renderWithProviders(<VerifyEmailPage />, {
      path: '/verify-email',
      initialEntries: ['/verify-email?token=abc123'],
    });

    await screen.findByText(en['verify.success.title']);
    const body = lastRequestBody(fetchFn);
    expect(body).toEqual({ token: 'abc123' });
  });

  it('with no token, offers a resend form and acknowledges neutrally', async () => {
    mockFetch({
      'POST /v1/auth/verify-email/resend': { status: 200 },
    });
    const user = userEvent.setup();
    renderWithProviders(<VerifyEmailPage />, { path: '/verify-email' });

    await user.type(screen.getByLabelText(en['field.email']), 'x@y.com');
    await user.click(
      screen.getByRole('button', { name: en['verify.resend.submit'] }),
    );
    await screen.findByText(en['verify.resend.sent']);
  });
});

describe('ForgotPasswordPage', () => {
  it('always shows the same acknowledgement panel', async () => {
    mockFetch({ 'POST /v1/auth/password-reset/request': { status: 200 } });
    const user = userEvent.setup();
    renderWithProviders(<ForgotPasswordPage />, { path: '/forgot-password' });

    await user.type(screen.getByLabelText(en['field.email']), 'nobody@nowhere.io');
    await user.click(
      screen.getByRole('button', { name: en['forgot.submit'] }),
    );
    await screen.findByText(en['forgot.done.title']);
  });
});

describe('ResetPasswordPage', () => {
  it('shows the invalid-link panel when there is no token', () => {
    renderWithProviders(<ResetPasswordPage />, { path: '/reset-password' });
    expect(screen.getByText(en['reset.noToken.title'])).toBeInTheDocument();
  });

  it('submits the new password with the token from the query', async () => {
    const fetchFn = mockFetch({
      'POST /v1/auth/password-reset/confirm': { status: 200 },
    });
    const user = userEvent.setup();
    renderWithProviders(<ResetPasswordPage />, {
      path: '/reset-password',
      initialEntries: ['/reset-password?token=reset-xyz'],
    });

    await user.type(screen.getByLabelText(en['field.newPassword']), 'newpass1234');
    await user.type(
      screen.getByLabelText(en['field.confirmPassword']),
      'newpass1234',
    );
    await user.click(screen.getByRole('button', { name: en['reset.submit'] }));

    await screen.findByText(en['reset.success.title']);
    const body = lastRequestBody(fetchFn);
    expect(body).toEqual({ token: 'reset-xyz', new_password: 'newpass1234' });
  });
});

describe('LoginPage', () => {
  it('links to register and password reset', () => {
    renderWithProviders(<LoginPage />, { path: '/login' });
    expect(
      screen.getByRole('link', { name: en['login.toRegister'] }),
    ).toHaveAttribute('href', '/register');
    expect(
      screen.getByRole('link', { name: en['login.toForgot'] }),
    ).toHaveAttribute('href', '/forgot-password');
  });

  it('redirects on a successful sign in', async () => {
    mockFetch({
      'POST /v1/auth/login': {
        status: 200,
        body: { access_token: 'a.b.c', refresh_token: 'r1' },
      },
    });
    const user = userEvent.setup();
    renderWithProviders(<LoginPage />, { path: '/login' });

    await user.type(screen.getByLabelText(en['field.email']), 'admin@k.io');
    await user.type(screen.getByLabelText(en['field.password']), 'password123');
    await user.click(screen.getByRole('button', { name: en['login.submit'] }));

    await waitFor(() =>
      expect(screen.getByTestId('redirected')).toBeInTheDocument(),
    );
    expect(tokens.getAccess()).toBe('a.b.c');
  });
});
