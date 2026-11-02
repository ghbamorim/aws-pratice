import React, { useEffect, useState } from 'react'
import { createRoot } from 'react-dom/client'
import './style.css'

function App() {
  const [orders, setOrders] = useState([])
  const [customer, setCustomer] = useState('Test Customer')
  const [amount, setAmount] = useState('49.90')
  const [message, setMessage] = useState('Ready to test.')
  async function request(path, options) {
    const started = performance.now()
    try {
      const response = await fetch('/api' + path, options)
      const body = await response.json()
      if (!response.ok) throw new Error(`${response.status}: ${body.detail || JSON.stringify(body)}`)
      setMessage(`OK (${Math.round(performance.now() - started)} ms): ${JSON.stringify(body)}`)
      return body
    } catch (error) {
      setMessage(`ERROR (${Math.round(performance.now() - started)} ms): ${error.message}`)
      return null
    }
  }
  async function refresh() {
    const response = await fetch('/api/orders')
    if (response.ok) setOrders(await response.json())
  }
  useEffect(() => { refresh().catch(console.error) }, [])
  async function create(event) {
    event.preventDefault()
    const result = await request('/orders', { method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify({ customer, amount }) })
    if (result) await refresh()
  }
  async function process(id, fault) {
    await request(`/orders/${id}/process?fault=${fault}`, { method: 'POST' })
    await refresh()
  }
  return <main>
    <header><h1>Datadog Lab</h1><p>Observability lab · React / FastAPI / PostgreSQL / Lambda</p></header>
    <section><h2>New order</h2><form onSubmit={create}><input aria-label="Customer" value={customer} onChange={e=>setCustomer(e.target.value)} required/><input aria-label="Amount" type="number" step="0.01" min="0.01" value={amount} onChange={e=>setAmount(e.target.value)} required/><button>Create order</button></form></section>
    <section><h2>Orders</h2><button onClick={refresh}>Refresh orders</button>{orders.map(o=><article key={o.id}><strong>#{o.id} — {o.customer}</strong><span>R$ {o.amount} · {o.status}</span><div className="actions"><button onClick={()=>process(o.id,'none')}>Process</button><button onClick={()=>process(o.id,'error')}>Lambda: error</button><button onClick={()=>process(o.id,'timeout')}>Lambda: timeout</button></div></article>)}</section>
    <section><h2>Intentional faults</h2><div className="actions"><button onClick={()=>request('/faults/latency')}>API latency</button><button onClick={()=>request('/faults/error')}>HTTP 500 error</button><button onClick={()=>request('/faults/slow-query')}>Slow query</button><button onClick={()=>request('/faults/memory',{method:'POST'})}>Allocate +5 MiB</button><button onClick={()=>request('/faults/memory',{method:'DELETE'})}>Release memory</button></div></section>
    <section className="output"><h2>Latest operation result</h2><pre>{message}</pre></section>
  </main>
}
createRoot(document.getElementById('root')).render(<App />)
