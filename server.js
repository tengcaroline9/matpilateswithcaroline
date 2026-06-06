// Local preview server for the Mat Pilates site (no dependencies).
// Run with: npm run dev   ->   http://localhost:3000
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
const PORT = process.env.PORT || 3000;
const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.jsx': 'text/babel',
  '.css': 'text/css', '.png': 'image/png', '.jpeg': 'image/jpeg', '.jpg': 'image/jpeg',
  '.mp4': 'video/mp4', '.svg': 'image/svg+xml', '.json': 'application/json',
  '.ico': 'image/x-icon', '.webmanifest': 'application/manifest+json',
};

http.createServer((req, res) => {
  let p = decodeURIComponent(req.url.split('?')[0]);
  if (p === '/' || p === '') p = '/index.html';
  const fp = path.join(ROOT, p);
  if (!fp.startsWith(ROOT)) { res.writeHead(403); res.end('forbidden'); return; }
  fs.readFile(fp, (err, data) => {
    if (err) {
      // Unknown route with no file extension -> serve index.html (hash routing app)
      if (!path.extname(fp)) {
        fs.readFile(path.join(ROOT, 'index.html'), (e2, d2) => {
          if (e2) { res.writeHead(404); res.end('not found'); }
          else { res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' }); res.end(d2); }
        });
        return;
      }
      res.writeHead(404); res.end('not found'); return;
    }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(fp).toLowerCase()] || 'application/octet-stream' });
    res.end(data);
  });
}).listen(PORT, () => console.log(`\n  Mat Pilates preview running at  http://localhost:${PORT}\n  (Ctrl+C to stop)\n`));
