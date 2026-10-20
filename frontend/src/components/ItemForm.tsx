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
