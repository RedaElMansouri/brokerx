import ws from 'k6/ws';
import { check, sleep } from 'k6';

const WS_URL = __ENV.WS_URL || 'ws://host.docker.internal:3000/cable';
const TOKEN = __ENV.TOKEN || '';
const HOLD_MS = Number(__ENV.WS_HOLD_MS || 25000);

export const options = {
    vus: Number(__ENV.VUS || 5),
    duration: __ENV.DURATION || '30s',
};

export default function () {
    const url = `${WS_URL}?token=${encodeURIComponent(TOKEN)}`;

    const res = ws.connect(url, {}, function (socket) {
    let welcomed = false;
    let confirmed = false;

    socket.on('open', function () {
      // Subscribe to MarketChannel (requires only valid JWT on connection)
        const identifier = JSON.stringify({ channel: 'MarketChannel' });
        socket.send(JSON.stringify({ command: 'subscribe', identifier }));
    });

    socket.on('message', function (msg) {
        try {
        const data = JSON.parse(msg);
        if (data.type === 'welcome') {
            welcomed = true;
        }
        if (data.type === 'confirm_subscription') {
            confirmed = true;
        }
        } catch (_e) {
        // ignore non-JSON pings/frames
        }
    });

        // Keep the connection open so Prometheus can scrape a non-zero gauge
        socket.setTimeout(function () {
            socket.close();
        }, HOLD_MS);
    });

    check(res, {
    'ws status is 101': (r) => r && r.status === 101,
    });

  // brief think time between VU connects
    sleep(1);
}
