import assert from 'node:assert/strict';
import { afterEach, test } from 'node:test';
import { once } from 'node:events';
import { WebSocket } from 'ws';

import { createDatabase } from '../src/database.js';
import { createTodoServer } from '../src/server.js';

const servers = [];

async function startTestServer() {
  const todoServer = createTodoServer({ db: createDatabase(':memory:') });
  servers.push(todoServer);
  await todoServer.listen(0, '127.0.0.1');
  const address = todoServer.server.address();
  return {
    baseUrl: `http://127.0.0.1:${address.port}`,
    socketUrl: `ws://127.0.0.1:${address.port}/ws`,
  };
}

afterEach(async () => {
  await Promise.all(servers.splice(0).map((server) => server.close()));
});

test('creates tasks and broadcasts changes to connected clients', async () => {
  const { baseUrl, socketUrl } = await startTestServer();
  const socket = new WebSocket(socketUrl);
  const snapshotEvent = once(socket, 'message');
  await once(socket, 'open');
  const [snapshotData] = await snapshotEvent;
  assert.deepEqual(JSON.parse(snapshotData.toString()), { type: 'snapshot', tasks: [] });

  const createdEvent = once(socket, 'message');
  const response = await fetch(`${baseUrl}/api/tasks`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      title: 'Review changes',
      description: 'Check the shared list',
      createdBy: 'Alex',
    }),
  });
  assert.equal(response.status, 201);
  const task = await response.json();
  const [eventData] = await createdEvent;
  assert.equal(JSON.parse(eventData.toString()).task.id, task.id);
  assert.equal(task.status, 'pending');
  assert.equal(task.updatedBy, 'Alex');
  socket.close();
  await once(socket, 'close');
});

test('rejects invalid task data and returns updated tasks from SQLite', async () => {
  const { baseUrl } = await startTestServer();
  const invalidResponse = await fetch(`${baseUrl}/api/tasks`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ title: ' ', createdBy: 'Alex' }),
  });
  assert.equal(invalidResponse.status, 400);

  const createdResponse = await fetch(`${baseUrl}/api/tasks`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ title: 'Review', createdBy: 'Alex' }),
  });
  const created = await createdResponse.json();
  const updateResponse = await fetch(`${baseUrl}/api/tasks/${created.id}`, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      title: 'Review updates',
      description: '',
      status: 'completed',
      updatedBy: 'Sam',
    }),
  });
  assert.equal(updateResponse.status, 200);
  const tasksResponse = await fetch(`${baseUrl}/api/tasks`);
  const tasks = await tasksResponse.json();
  assert.equal(tasks[0].status, 'completed');
  assert.equal(tasks[0].updatedBy, 'Sam');
});

test('deletes tasks and broadcasts the removed task id', async () => {
  const { baseUrl, socketUrl } = await startTestServer();
  const createdResponse = await fetch(`${baseUrl}/api/tasks`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ title: 'Remove me', createdBy: 'Alex' }),
  });
  const created = await createdResponse.json();
  const socket = new WebSocket(socketUrl);
  const snapshotEvent = once(socket, 'message');
  await once(socket, 'open');
  await snapshotEvent;
  const deletedEvent = once(socket, 'message');
  const deleteResponse = await fetch(`${baseUrl}/api/tasks/${created.id}`, {
    method: 'DELETE',
    headers: { 'x-actor': 'Sam' },
  });

  assert.equal(deleteResponse.status, 204);
  const [eventData] = await deletedEvent;
  const event = JSON.parse(eventData.toString());
  assert.equal(event.type, 'task_deleted');
  assert.equal(event.id, created.id);
  assert.equal(event.deletedBy, 'Sam');
  socket.close();
  await once(socket, 'close');
});
