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
