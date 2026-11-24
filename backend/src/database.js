import { DatabaseSync } from 'node:sqlite';

export function createDatabase(databasePath = 'data/todos.sqlite') {
  const db = new DatabaseSync(databasePath);
  db.exec(`
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;

    CREATE TABLE IF NOT EXISTS tasks (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT NOT NULL DEFAULT '',
      status TEXT NOT NULL CHECK (status IN ('pending', 'in_progress', 'completed')),
      createdBy TEXT NOT NULL,
      updatedBy TEXT NOT NULL,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    );
    CREATE INDEX IF NOT EXISTS tasks_updated_at_idx ON tasks(updatedAt DESC);
  `);

  const list = db.prepare('SELECT * FROM tasks ORDER BY updatedAt DESC');
  const get = db.prepare('SELECT * FROM tasks WHERE id = ?');
  const insert = db.prepare(`
    INSERT INTO tasks
      (id, title, description, status, createdBy, updatedBy, createdAt, updatedAt)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `);
  const update = db.prepare(`
    UPDATE tasks SET title = ?, description = ?, status = ?,
      updatedBy = ?, updatedAt = ?
    WHERE id = ?
  `);
  const remove = db.prepare('DELETE FROM tasks WHERE id = ?');

  return {
    list: () => list.all(),
    get: (id) => get.get(id),
    create(task) {
      insert.run(
        task.id,
        task.title,
        task.description,
        task.status,
        task.createdBy,
        task.updatedBy,
        task.createdAt,
        task.updatedAt,
      );
      return get.get(task.id);
    },
    update(task) {
      const result = update.run(
        task.title,
        task.description,
        task.status,
        task.updatedBy,
        task.updatedAt,
        task.id,
      );
      return result.changes === 0 ? undefined : get.get(task.id);
    },
    remove(id) {
      return remove.run(id).changes > 0;
    },
    close: () => db.close(),
  };
}
