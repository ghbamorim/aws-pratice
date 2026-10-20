#!/usr/bin/env bash
set -euo pipefail
if [[ ! -f frontend/package.json || ! -d frontend/src ]]; then
  echo 'Execute na raiz do repositorio, depois de inicializar o Vite em frontend/.' >&2
  exit 1
fi
for f in frontend/src/App.tsx frontend/src/App.css frontend/src/index.css frontend/vite.config.ts; do
  if [[ -f "$f" ]]; then cp -n "$f" "$f.before-fullstack-lab.bak"; fi
done
mkdir -p frontend/src/{components,services,types}
cat > frontend/src/types/item.ts <<'EOF'
export type Item = {
  id: number;
  name: string;
  attachment_key: string | null;
};
EOF
cat > frontend/src/services/itemApi.ts <<'EOF'
import type { Item } from '../types/item';

async function parseResponse<T>(response: Response): Promise<T> {
  if (!response.ok) {
    let detail = `Erro HTTP ${response.status}`;
    try {
      const body: unknown = await response.json();
      if (typeof body === 'object' && body !== null && 'detail' in body) {
        const value = (body as { detail: unknown }).detail;
        if (typeof value === 'string') detail = value;
      }
    } catch { /* Keep the HTTP status error. */ }
    throw new Error(detail);
  }
  return response.json() as Promise<T>;
}

export async function createItem(name: string): Promise<Item> {
  return parseResponse<Item>(await fetch('/api/items', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name }),
  }));
}

export async function getItem(id: number): Promise<Item> {
  return parseResponse<Item>(await fetch(`/api/items/${id}`));
}

export async function uploadAttachment(id: number, file: File): Promise<Item> {
  const form = new FormData();
  form.append('file', file);
  return parseResponse<Item>(await fetch(`/api/items/${id}/attachment`, {
    method: 'POST', body: form,
  }));
}

export async function getAttachmentUrl(id: number): Promise<string> {
  const result = await parseResponse<{ url: string }>(
    await fetch(`/api/items/${id}/attachment`),
  );
  return result.url;
}
EOF
cat > frontend/src/components/ItemForm.tsx <<'EOF'
import { useState, type FormEvent } from 'react';
import { createItem, getAttachmentUrl, getItem, uploadAttachment } from '../services/itemApi';
import type { Item } from '../types/item';

export function ItemForm() {
  const [name, setName] = useState('');
  const [lookupId, setLookupId] = useState('');
  const [file, setFile] = useState<File | null>(null);
  const [item, setItem] = useState<Item | null>(null);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [loading, setLoading] = useState(false);

  async function save(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!name.trim()) return;
    setLoading(true); setError(''); setMessage('');
    try {
      const created = await createItem(name.trim());
      setItem(created);
      setLookupId(String(created.id));
      setName('');
      setMessage(`Item #${created.id} criado com sucesso.`);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Falha ao salvar.');
    } finally { setLoading(false); }
  }

  async function find(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const id = Number(lookupId);
    if (!Number.isInteger(id) || id < 1) { setError('Informe um ID válido.'); return; }
    setLoading(true); setError(''); setMessage('');
    try { setItem(await getItem(id)); }
    catch (err) { setError(err instanceof Error ? err.message : 'Falha na consulta.'); }
    finally { setLoading(false); }
  }

  async function sendFile() {
    if (!item || !file) return;
    setLoading(true); setError(''); setMessage('');
    try {
      setItem(await uploadAttachment(item.id, file));
      setFile(null);
      setMessage('Anexo enviado ao S3.');
    } catch (err) { setError(err instanceof Error ? err.message : 'Falha no envio.'); }
    finally { setLoading(false); }
  }

  async function downloadFile() {
    if (!item) return;
    setLoading(true); setError('');
    try {
      const url = await getAttachmentUrl(item.id);
      window.open(url, '_blank', 'noopener,noreferrer');
    } catch (err) { setError(err instanceof Error ? err.message : 'Falha ao obter o anexo.'); }
    finally { setLoading(false); }
  }

  return (
    <main className="container">
      <header><span className="eyebrow">AWS · FULLSTACK LAB</span><h1>Cadastro de itens</h1>
        <p>React + FastAPI + PostgreSQL. Anexos privados no Amazon S3.</p></header>
      <section className="panel">
        <h2>Novo item</h2>
        <form onSubmit={save} className="stack">
          <label htmlFor="name">Nome</label>
          <input id="name" value={name} onChange={e => setName(e.target.value)}
            maxLength={255} placeholder="Ex.: Documento de teste" required />
          <button disabled={loading || !name.trim()} type="submit">Salvar item</button>
        </form>
      </section>
      <section className="panel">
        <h2>Consultar item</h2>
        <form onSubmit={find} className="inline">
          <input aria-label="ID do item" type="number" min="1" value={lookupId}
            onChange={e => setLookupId(e.target.value)} placeholder="ID do item" required />
          <button type="submit" disabled={loading}>Buscar</button>
        </form>
      </section>
      {error && <p className="notice error" role="alert">{error}</p>}
      {message && <p className="notice success" role="status">{message}</p>}
      {item && <section className="panel">
        <h2>Item #{item.id}</h2><p><strong>Nome:</strong> {item.name}</p>
        <p><strong>Anexo:</strong> {item.attachment_key ? 'Disponível no S3' : 'Nenhum'}</p>
        <div className="stack">
          <label htmlFor="attachment">Enviar PDF, PNG ou JPEG (até 5 MiB)</label>
          <input id="attachment" type="file" accept="application/pdf,image/png,image/jpeg"
            onChange={e => setFile(e.target.files?.[0] ?? null)} />
          <button type="button" disabled={!file || loading} onClick={sendFile}>Enviar anexo</button>
          {item.attachment_key && <button className="secondary" type="button" disabled={loading}
            onClick={downloadFile}>Abrir anexo</button>}
          <small>O envio requer um bucket S3 configurado no backend.</small>
        </div>
      </section>}
    </main>
  );
}
EOF
cat > frontend/src/App.tsx <<'EOF'
import { ItemForm } from './components/ItemForm';
import './App.css';

function App() { return <ItemForm />; }
export default App;
EOF
cat > frontend/src/index.css <<'EOF'
:root { font-family: Inter, system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  color: #182335; background: #f4f6fa; font-synthesis: none; text-rendering: optimizeLegibility; }
* { box-sizing: border-box; }
body { margin: 0; min-width: 320px; }
button, input { font: inherit; }
EOF
cat > frontend/src/App.css <<'EOF'
.container { max-width: 690px; margin: 0 auto; padding: 54px 20px 80px; }
header { margin-bottom: 28px; }
h1 { font-size: 2.4rem; margin: 10px 0 8px; letter-spacing: -.04em; }
header p, small { color: #617086; }
.eyebrow { color: #3d65ac; font-size: .75rem; font-weight: 800; letter-spacing: .14em; }
.panel { background: white; border: 1px solid #e1e6ee; border-radius: 14px;
  padding: 25px; margin: 16px 0; box-shadow: 0 5px 20px #20305008; }
h2 { font-size: 1.1rem; margin: 0 0 18px; }
.stack { display: flex; flex-direction: column; gap: 12px; }
.inline { display: flex; gap: 10px; }
.inline input { min-width: 0; flex: 1; }
label { font-size: .9rem; font-weight: 600; }
input { border: 1px solid #cdd5e2; border-radius: 8px; padding: 12px; width: 100%; }
input:focus { outline: 2px solid #90b2f5; outline-offset: 1px; }
input[type=file] { padding: 10px; }
button { border: 0; background: #285bb4; color: white; border-radius: 8px;
  padding: 12px 18px; cursor: pointer; font-weight: 600; }
button.secondary { background: #e8effc; color: #224b92; }
button:disabled { opacity: .5; cursor: not-allowed; }
.notice { border-radius: 9px; padding: 14px 16px; }
.error { background: #fff0ef; color: #a12620; }
.success { background: #e9f8ee; color: #166d37; }
small { font-size: .78rem; }
EOF
cat > frontend/vite.config.ts <<'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    host: '127.0.0.1',
    proxy: { '/api': { target: 'http://127.0.0.1:8001', changeOrigin: true } },
  },
});
EOF
printf '\nFrontend configurado. Agora execute:\n  cd frontend && npm run dev\n'
