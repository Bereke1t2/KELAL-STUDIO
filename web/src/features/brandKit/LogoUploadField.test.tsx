import { afterEach, describe, expect, it, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';

import { I18nProvider } from '../../i18n/I18nContext';
import { mockFetch } from '../../test/fetchMock';
import { LogoUploadField } from './LogoUploadField';

afterEach(() => vi.unstubAllGlobals());

function setup(overrides?: Partial<Parameters<typeof LogoUploadField>[0]>) {
  const onUploaded = vi.fn();
  const onCleared = vi.fn();
  render(
    <I18nProvider>
      <LogoUploadField
        assetId={null}
        onUploaded={onUploaded}
        onCleared={onCleared}
        {...overrides}
      />
    </I18nProvider>,
  );
  return { onUploaded, onCleared };
}

const png = new File([new Uint8Array([1, 2, 3])], 'mark.png', {
  type: 'image/png',
});

describe('LogoUploadField', () => {
  it('shows dimensions and filename after upload, not an image', async () => {
    mockFetch({
      'POST /v1/assets': {
        status: 201,
        body: { id: 'a1', width: 512, height: 512, mime_type: 'image/png' },
      },
    });
    const { onUploaded } = setup();
    const input = document.querySelector('input[type="file"]') as HTMLInputElement;
    await userEvent.upload(input, png);

    expect(await screen.findByText(/mark\.png/)).toHaveTextContent('512×512');
    expect(document.querySelector('img')).toBeNull();
    expect(onUploaded).toHaveBeenCalledWith('a1', png);
  });

  it('surfaces a validation_error in plain language', async () => {
    mockFetch({
      'POST /v1/assets': {
        status: 400,
        body: { error_code: 'validation_error', message: 'File is too large.' },
      },
    });
    setup();
    const input = document.querySelector('input[type="file"]') as HTMLInputElement;
    await userEvent.upload(input, png);

    expect(await screen.findByRole('alert')).toHaveTextContent('File is too large.');
  });
});
