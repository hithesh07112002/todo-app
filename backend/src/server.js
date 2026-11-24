import { randomUUID } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer as createHttpServer } from 'node:http';
import cors from 'cors';
import express from 'express';
import { WebSocket, WebSocketServer } from 'ws';

import { createDatabase } from './database.js';

const statuses = new Set(['pending', 'in_progress', 'completed']);

export function createTodoServer({ db, databasePath = 'data/todos.sqlite' } = {}) {
  if (!db) {
    mkdirSync(dirname(databasePath), { recursive: true });
    db = createDatabase(databasePath);
  }

  const app = express();
  app.use(cors());
  app.use(express.json({ limit: '32kb' }));

  app.get('/health', (_request, response) => {
    response.json({ status: 'ok' });
  });

  app.get('/api/tasks', (_request, response) => {
    response.json(db.list());
  });

  app.post('/api/tasks', (request, response) => {
    const { title, description = '', createdBy } = request.body ?? {};
    if (
      !isText(title, 120) ||
      !isOptionalText(description, 1000) ||
      !isText(createdBy, 60)
    ) {
      return response.status(400).json({ error: 'Invalid task fields.' });
    }
    const now = new Date().toISOString();
    const task = db.create({
      id: randomUUID(),
      title: title.trim(),
      description: description.trim(),
      status: 'pending',
      createdBy: createdBy.trim(),
      updatedBy: createdBy.trim(),
      createdAt: now,
      updatedAt: now,
    });
    broadcast({ type: 'task_created', task });
    response.status(201).json(task);
  });

  app.put('/api/tasks/:id', (request, response) => {
    const { title, description = '', status, updatedBy } = request.body ?? {};
    if (
      !isText(title, 120) ||
      !isOptionalText(description, 1000) ||
      !statuses.has(status) ||
      !isText(updatedBy, 60)
    ) {
      return response.status(400).json({ error: 'Invalid task fields.' });
    }
    const task = db.update({
      id: request.params.id,
      title: title.trim(),
      description: description.trim(),
      status,
      updatedBy: updatedBy.trim(),
      updatedAt: new Date().toISOString(),
    });
    if (!task) return response.status(404).json({ error: 'Task not found.' });
    broadcast({ type: 'task_updated', task });
    response.json(task);
  });

  app.delete('/api/tasks/:id', (request, response) => {
    const actor = request.get('x-actor');
    if (!isText(actor, 60)) {
      return response.status(400).json({ error: 'A valid x-actor header is required.' });
    }
    if (!db.remove(request.params.id)) {
      return response.status(404).json({ error: 'Task not found.' });
    }
    broadcast({
      type: 'task_deleted',
      id: request.params.id,
      deletedBy: actor.trim(),
      deletedAt: new Date().toISOString(),
    });
    response.status(204).end();
  });

  app.use((error, _request, response, _next) => {
    if (error instanceof SyntaxError && 'body' in error) {
      return response.status(400).json({ error: 'Invalid JSON body.' });
    }
    console.error(error);
    response.status(500).json({ error: 'Internal server error.' });
  });

  const server = createHttpServer(app);
  const sockets = new WebSocketServer({ server, path: '/ws' });

  function broadcast(event) {
    const serialized = JSON.stringify(event);
    for (const socket of sockets.clients) {
      if (socket.readyState === WebSocket.OPEN) socket.send(serialized);
    }
  }

  sockets.on('connection', (socket) => {
    socket.send(JSON.stringify({ type: 'snapshot', tasks: db.list() }));
  });

  return {
    app,
    server,
    db,
    listen(port = Number(process.env.PORT ?? 3000), host = '0.0.0.0') {
      return new Promise((resolveListen, reject) => {
        server.once('error', reject);
        server.listen(port, host, () => {
          server.removeListener('error', reject);
          resolveListen(server);
        });
      });
    },
    close() {
      return new Promise((resolveClose, reject) => {
        if (!server.listening) {
          db.close?.();
          resolveClose();
          return;
        }
        server.close((error) => {
          if (error) {
            reject(error);
            return;
          }
          db.close?.();
          resolveClose();
        });
      });
    },
  };
}

function isText(value, maxLength) {
  return typeof value === 'string' && value.trim().length > 0 && value.length <= maxLength;
}

function isOptionalText(value, maxLength) {
  return typeof value === 'string' && value.length <= maxLength;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const databasePath = resolve(process.env.DATABASE_PATH ?? 'data/todos.sqlite');
  const todoServer = createTodoServer({ databasePath });
  const port = Number(process.env.PORT ?? 3000);
  await todoServer.listen(port);
  console.log(`Todo API and WebSocket listening on port ${port}`);

  for (const signal of ['SIGINT', 'SIGTERM']) {
    process.on(signal, async () => {
      await todoServer.close();
      process.exit(0);
    });
  }
}
