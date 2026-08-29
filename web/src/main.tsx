import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';

// Order matters: primitives and the type scale define the custom properties
// that the Tailwind bridge (theme.css) and base.css consume.
import './styles/tokens.css';
import './styles/typography.css';
import './styles/fonts.css';
import './styles/theme.css';
import './styles/base.css';

import { App } from './App';

const root = document.getElementById('root');
if (!root) throw new Error('#root missing from index.html');

createRoot(root).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
