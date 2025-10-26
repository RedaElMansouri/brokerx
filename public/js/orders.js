function requireAuth() {
    const token = localStorage.getItem('auth_token');
    if (!token) {
    alert('Vous devez vous connecter (MFA)');
    window.location.href = '/';
    return null;
    }
    return token;
}

(function() {
    try {
    const raw = localStorage.getItem('auth_user');
    let name = 'Bienvenue';
    if (raw) {
        const user = JSON.parse(raw);
        name = `Bienvenue ${user.full_name || [user.first_name, user.last_name].filter(Boolean).join(' ')}`.trim();
    }
    const el = document.getElementById('welcomeName');
    if (el) el.textContent = name;
    } catch (e) {}
})();

// Header logout
(function() {
    const btn = document.getElementById('headerLogoutBtn');
    if (btn) {
    btn.addEventListener('click', (e) => {
        e.preventDefault();
        localStorage.removeItem('auth_token');
        localStorage.removeItem('auth_user');
        window.location.href = '/';
    });
    }
})();

// Order form submit
(function(){
    const form = document.getElementById('orderForm');
    if (!form) return;
    form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const token = requireAuth();
    if (!token) return;
    function uuidv4(){
        if (window.crypto && window.crypto.randomUUID) { return window.crypto.randomUUID(); }
      // Fallback simple UUID v4
        return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random()*16|0, v = c === 'x' ? r : (r&0x3|0x8);
        return v.toString(16);
        });
    }
    const providedId = (document.getElementById('client_order_id').value || '').trim();
    const effectiveClientOrderId = providedId || uuidv4();
    if (!providedId) {
        try { document.getElementById('client_order_id').value = effectiveClientOrderId; } catch(_){}
    }
    const payload = {
        symbol: document.getElementById('symbol').value,
        order_type: document.getElementById('order_type').value,
        direction: document.getElementById('direction').value,
        quantity: document.getElementById('quantity').value,
        price: document.getElementById('price').value || null,
        client_order_id: effectiveClientOrderId
    };
    const feedback = document.getElementById('orderFeedback');
    if (feedback) feedback.textContent = '';
    try {
        const res = await fetch('/api/v1/orders', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Accept': 'application/json', 'Authorization': 'Bearer ' + token },
        body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (!res.ok) {
        if (feedback) {
            feedback.style.color = '#e53e3e';
            feedback.textContent = data.error || (data.errors && JSON.stringify(data.errors)) || 'Erreur';
        }
        } else {
        if (feedback) {
            feedback.style.color = '#2f855a';
            feedback.textContent = data.message || 'Ordre accepté';
        }
        try {
            await OrdersPanel.fetchAndAdd(data.order_id);
        } catch(_) {}
        try { document.getElementById('client_order_id').value = ''; } catch(_) {}
        }
    } catch (err) {
        if (feedback) {
        feedback.style.color = '#e53e3e';
        feedback.textContent = 'Impossible de contacter le serveur';
        }
    }
    });
})();

// Génération manuelle d'un Client Order ID
(function(){
    const btn = document.getElementById('genClientOrderId');
    if (!btn) return;
    btn.addEventListener('click', function(){
    if (window.crypto && window.crypto.randomUUID) {
        document.getElementById('client_order_id').value = window.crypto.randomUUID();
    } else {
            const s4 = () => Math.floor((1+Math.random())*0x10000).toString(16).substring(1);
        document.getElementById('client_order_id').value = `${s4()}${s4()}-${s4()}-4${s4().substr(0,3)}-a${s4().substr(0,3)}-${s4()}${s4()}${s4()}`;
    }
    });
})();

// ---- UC-04: Intégration temps réel via ActionCable ----
(function() {
    const token = localStorage.getItem('auth_token');
    const statusTextNode = document.getElementById('wsStatusText');
    if (!token) {
    if (statusTextNode) statusTextNode.textContent = 'non authentifié (connectez-vous)';
    return; // pas connecté => pas de flux
    }

  // Charger client ActionCable via CDN si absent
    function ensureCable(cb) {
    if (window.ActionCable) return cb();
    const primary = 'https://cdn.jsdelivr.net/npm/@rails/actioncable@7.1.5/dist/actioncable.umd.js';
    const fallback = 'https://unpkg.com/@rails/actioncable@7.1.5/dist/actioncable.umd.js';
    const s = document.createElement('script');
    s.src = primary;
    s.onload = cb;
    s.onerror = () => {
        console.warn('Primary ActionCable CDN failed, trying fallback');
        const s2 = document.createElement('script');
        s2.src = fallback;
        s2.onload = cb;
        s2.onerror = () => {
        console.error('Failed to load ActionCable client from both CDNs');
        cb();
        };
        document.head.appendChild(s2);
    };
    document.head.appendChild(s);
    }

    ensureCable(() => {
    try {
        const symbolInput = document.getElementById('symbol');
        const throttleToggle = document.getElementById('throttleToggle');
        const quoteBox = document.getElementById('quoteBox');
        const bookBox = document.getElementById('bookBox');
        const degradedBanner = document.getElementById('degradedBanner');

        let consumer, subscription;
        let throttledTimer = null;
        let lastQuote = null;
        let lastBook = null;

        function connect() {
        const mode = throttleToggle.checked ? 'throttled' : 'normal';
        const wsURL = (location.protocol === 'https:' ? 'wss://' : 'ws://') + location.host + `/cable?token=${encodeURIComponent(token)}`;
        const statusText = document.getElementById('wsStatusText');
        statusText.textContent = 'connexion…';
        const sym = (symbolInput.value || 'AAPL').toUpperCase();

        if (window.ActionCable) {
            consumer = window.ActionCable.createConsumer(wsURL);
            subscription = consumer.subscriptions.create({ channel: 'MarketChannel', symbols: [sym], mode }, {
            initialized(){ console.debug('MarketChannel initialized'); },
            connected(){ statusText.textContent = `connecté (${sym})`; },
            rejected(){ statusText.textContent = 'rejeté (JWT manquant/invalide)'; },
            disconnected(){ statusText.textContent = 'déconnecté'; },
            received: handleReceived
            });
            return;
        }

        // Fallback minimal ActionCable client using raw WebSocket (no external JS)
        try {
            const ws = new WebSocket(wsURL);
            consumer = { _ws: ws };
            const identifier = JSON.stringify({ channel: 'MarketChannel', symbols: [sym], mode });

            ws.addEventListener('open', () => {
            statusText.textContent = `connecté (${sym})`;
            ws.send(JSON.stringify({ command: 'subscribe', identifier }));
            });

            ws.addEventListener('close', () => {
            statusText.textContent = 'déconnecté';
            });

            ws.addEventListener('message', (ev) => {
            try {
                const msg = JSON.parse(ev.data);
                if (msg.type === 'welcome' || msg.type === 'ping' || msg.type === 'confirm_subscription') return;
                if (msg.type === 'reject_subscription') { statusText.textContent = 'rejeté (JWT manquant/invalide)'; return; }
                if (msg.message) { handleReceived(msg.message); }
            } catch (err) {
                console.warn('WS parse error', err);
            }
            });

            subscription = {
            unsubscribe(){ try { ws.close(); } catch(_){} }
            };
        } catch (err) {
            console.error('WS fallback error', err);
            statusText.textContent = 'erreur de connexion';
        }
        }

        function handleReceived(data) {
        if (data.type === 'status') {
            degradedBanner.style.display = (data.level === 'degraded') ? 'block' : 'none';
            return;
        }
        if (data.type === 'quote') {
            lastQuote = data;
        } else if (data.type === 'orderbook') {
            lastBook = data;
        }
        if (throttleToggle.checked) {
            if (!throttledTimer) {
            throttledTimer = setTimeout(() => {
                throttledTimer = null;
                render();
            }, 1000);
            }
        } else {
            render();
        }
        }

        function disconnect() {
        if (subscription) {
            try { subscription.unsubscribe(); } catch(_) {}
            subscription = null;
        }
        if (consumer) {
            try {
            if (typeof consumer.disconnect === 'function') {
                consumer.disconnect();
            } else if (consumer._ws && typeof consumer._ws.close === 'function') {
                consumer._ws.close();
            }
            } catch(_) {}
            consumer = null;
        }
        }

        function render() {
        if (lastQuote) {
            quoteBox.innerHTML = `${lastQuote.symbol}: bid=${lastQuote.bid} ask=${lastQuote.ask} mid=${lastQuote.mid} <small style="color:#64748b">${lastQuote.ts}</small>`;
        }
        if (lastBook) {
            const bids = (lastBook.bids || []).map(([p,q]) => `${p}@${q}`).join(' | ');
            const asks = (lastBook.asks || []).map(([p,q]) => `${p}@${q}`).join(' | ');
            bookBox.innerHTML = `${lastBook.symbol}: <span style="color:#16a34a">BIDS</span> [${bids}] &nbsp; <span style="color:#dc2626">ASKS</span> [${asks}] <small style="color:#64748b">${lastBook.ts}</small>`;
        }
        }

      // Reconnect on symbol change or throttle mode change
        function rewire() {
        const statusText = document.getElementById('wsStatusText');
        disconnect();
        lastQuote = lastBook = null;
        quoteBox.innerHTML = '<em>…</em>';
        bookBox.innerHTML = '<em>…</em>';
        if (statusText) statusText.textContent = 'connexion…';
        connect();
        }
        symbolInput.addEventListener('change', rewire);
        let inputTimer = null;
        symbolInput.addEventListener('input', () => { if (inputTimer) clearTimeout(inputTimer); inputTimer = setTimeout(rewire, 500); });
        throttleToggle.addEventListener('change', rewire);

        connect();
        window.addEventListener('beforeunload', disconnect);
    } catch (e) {
        console.warn('Cable error', e);
    }
    });
})();

// ---- UC-06: Panneau ordres avec modifier/annuler ----
const OrdersPanel = (function(){
    const tbody = document.getElementById('ordersTbody');
    const empty = document.getElementById('ordersEmpty');
    const state = {}; // id -> order

    function requireToken(){ return localStorage.getItem('auth_token'); }

    async function fetchAndAdd(id){
    const token = requireToken();
    if (!token) return;
    const res = await fetch(`/api/v1/orders/${id}`, { headers: { 'Accept': 'application/json', 'Authorization': 'Bearer ' + token }});
    if (!res.ok) throw new Error('fetch failed');
    const ord = await res.json();
    if (!ord || !ord.success) throw new Error('bad body');
    state[id] = ord;
    render();
    }

    function render(){
    tbody.innerHTML = '';
    const ids = Object.keys(state);
    empty.style.display = ids.length === 0 ? 'block' : 'none';
    ids.sort((a,b)=>parseInt(b)-parseInt(a)).forEach((id)=>{
        const o = state[id];
        const tr = document.createElement('tr');
        tr.innerHTML = `
        <td>${o.id}</td>
        <td>${o.symbol}</td>
        <td>${o.order_type}</td>
        <td>${o.direction}</td>
        <td>
            <input type="number" min="1" value="${o.quantity}" class="input input-narrow" data-field="qty" />
        </td>
        <td>
            <input type="number" step="0.01" value="${o.price || ''}" class="input input-price" data-field="price" />
        </td>
        <td>${o.status}</td>
        <td>${o.reserved_amount}</td>
        <td>${o.lock_version}</td>
        <td>
            <button data-action="modify" class="btn btn-blue mr-1">Modifier</button>
            <button data-action="cancel" class="btn btn-danger mr-1">Annuler</button>
            <button data-action="refresh" class="btn btn-slate">Rafraîchir</button>
        </td>
        `;
        tr.querySelector('[data-action="modify"]').addEventListener('click', ()=>modifyOrder(o.id, tr));
        tr.querySelector('[data-action="cancel"]').addEventListener('click', ()=>cancelOrder(o.id));
        tr.querySelector('[data-action="refresh"]').addEventListener('click', ()=>fetchAndAdd(o.id));
        tbody.appendChild(tr);
    });
    }

    async function modifyOrder(id, row){
    const token = requireToken(); if (!token) return;
    const o = state[id]; if (!o) return;
    const qtyInput = row.querySelector('input[data-field="qty"]');
    const priceInput = row.querySelector('input[data-field="price"]');
    const newQty = qtyInput.value ? parseInt(qtyInput.value, 10) : null;
    const newPrice = priceInput.value ? parseFloat(priceInput.value) : null;
    const body = { order: { client_version: o.lock_version } };
    if (newQty && newQty !== o.quantity) body.order.quantity = newQty;
    if ((newPrice || newPrice === 0) && newPrice !== parseFloat(o.price)) body.order.price = newPrice;
    if (!body.order.quantity && !('price' in body.order)) {
        alert('Aucun changement');
        return;
    }
    const res = await fetch(`/api/v1/orders/${id}/replace`, { method:'POST', headers:{ 'Content-Type':'application/json','Accept':'application/json','Authorization':'Bearer '+token }, body: JSON.stringify(body) });
    const data = await res.json();
    if (res.ok) {
        state[id] = Object.assign({}, o, data, { id: id });
        render();
    } else if (res.status === 409) {
        alert('Conflit de version, rechargement…');
        await fetchAndAdd(id);
    } else {
        alert((data && (data.message || data.error)) || 'Erreur');
    }
    }

    async function cancelOrder(id){
    const token = requireToken(); if (!token) return;
    const o = state[id]; if (!o) return;
    const res = await fetch(`/api/v1/orders/${id}/cancel`, { method:'POST', headers:{ 'Content-Type':'application/json','Accept':'application/json','Authorization':'Bearer '+token }, body: JSON.stringify({ client_version: o.lock_version }) });
    const data = await res.json();
    if (res.ok) {
        state[id] = Object.assign({}, o, { status: 'cancelled', lock_version: data.lock_version });
        render();
    } else if (res.status === 409) {
        alert('Conflit de version, rechargement…');
        await fetchAndAdd(id);
    } else {
        alert((data && (data.message || data.error)) || 'Erreur');
    }
    }

    return { fetchAndAdd };
})();
