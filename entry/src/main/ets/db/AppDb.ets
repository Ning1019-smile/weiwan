import { relationalStore } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { Task, TaskStatus } from '../model/Task';
import { Course, CourseSlot } from '../model/Course';
import { Exam } from '../model/Exam';
import { TaskCategory, PriorityLevel, CategoryPair } from '../model/Category';

const T_TASK = 'task';
const T_COURSE = 'course';
const T_SLOT = 'course_slot';
const T_EXAM = 'exam';
const T_TYPE = 'task_type';
const T_PRIO = 'task_priority';

/** 本地 RDB（单机 SQLite）封装：全部任务常驻内存做分组排序，量级足够 */
export class AppDb {
  private static store: relationalStore.RdbStore | null = null;

  static async init(context: Context): Promise<void> {
    if (AppDb.store !== null) {
      return;
    }
    const cfg: relationalStore.StoreConfig = {
      name: 'weiwan.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const store = await relationalStore.getRdbStore(context, cfg);
    await store.executeSql(
      `CREATE TABLE IF NOT EXISTS task (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type INTEGER DEFAULT 0,
        priority INTEGER DEFAULT 1,
        deadline INTEGER DEFAULT 0,
        courseId INTEGER DEFAULT -1,
        status INTEGER DEFAULT 0,
        doneAt INTEGER DEFAULT 0,
        createdAt INTEGER DEFAULT 0,
        updatedAt INTEGER DEFAULT 0
      )`
    );
    await store.executeSql(
      `CREATE INDEX IF NOT EXISTS idx_task_deadline ON task (deadline)`
    );
    await store.executeSql(
      `CREATE TABLE IF NOT EXISTS course (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        teacher TEXT DEFAULT '',
        location TEXT DEFAULT '',
        dayOfWeek INTEGER DEFAULT -1,
        startTime TEXT DEFAULT '',
        endTime TEXT DEFAULT '',
        createdAt INTEGER DEFAULT 0
      )`
    );
    // 多时间段（新表；旧库的 course 保留旧列不再使用）
    await store.executeSql(
      `CREATE TABLE IF NOT EXISTS course_slot (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        courseId INTEGER NOT NULL,
        day INTEGER DEFAULT 1,
        startTime TEXT DEFAULT '',
        endTime TEXT DEFAULT ''
      )`
    );
    // 考试（独立实体）
    await store.executeSql(
      `CREATE TABLE IF NOT EXISTS exam (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        courseId INTEGER DEFAULT -1,
        examAt INTEGER DEFAULT 0,
        location TEXT DEFAULT '',
        createdAt INTEGER DEFAULT 0
      )`
    );
    // 自定义类型 / 优先级
    await store.executeSql(
      `CREATE TABLE IF NOT EXISTS task_type (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )`
    );
    await store.executeSql(
      `CREATE TABLE IF NOT EXISTS task_priority (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL
      )`
    );
    AppDb.store = store;
    await AppDb.seedCategories();
  }

  /** 首次启动时播种默认分类（id 与旧任务数据的 0/1/2 数值兼容） */
  private static async seedCategories(): Promise<void> {
    const rs = await AppDb.s().query(new relationalStore.RdbPredicates(T_TYPE));
    const typeCount = rs.rowCount;
    rs.close();
    if (typeCount === 0) {
      await AppDb.s().executeSql(`INSERT INTO task_type (name) VALUES ('日常'), ('作业'), ('备考')`);
    }
    const rs2 = await AppDb.s().query(new relationalStore.RdbPredicates(T_PRIO));
    const prioCount = rs2.rowCount;
    rs2.close();
    if (prioCount === 0) {
      await AppDb.s().executeSql(`INSERT INTO task_priority (name) VALUES ('低'), ('中'), ('高')`);
    }
  }

  private static s(): relationalStore.RdbStore {
    if (AppDb.store === null) {
      throw new Error('AppDb not initialized');
    }
    return AppDb.store;
  }

  // ---------------- 任务 ----------------

  static async addTask(t: Task): Promise<void> {
    const now = Date.now();
    const bucket: relationalStore.ValuesBucket = {
      'title': t.title,
      'type': t.type,
      'priority': t.priority,
      'deadline': t.deadline,
      'courseId': t.courseId,
      'status': t.status,
      'doneAt': t.doneAt,
      'createdAt': now,
      'updatedAt': now
    };
    await AppDb.s().insert(T_TASK, bucket);
  }

  static async updateTask(t: Task): Promise<void> {
    const pred = new relationalStore.RdbPredicates(T_TASK);
    pred.equalTo('id', t.id);
    const bucket: relationalStore.ValuesBucket = {
      'title': t.title,
      'type': t.type,
      'priority': t.priority,
      'deadline': t.deadline,
      'courseId': t.courseId,
      'status': t.status,
      'doneAt': t.doneAt,
      'updatedAt': Date.now()
    };
    await AppDb.s().update(bucket, pred);
  }

  static async setTaskDone(id: number, done: boolean): Promise<void> {
    const pred = new relationalStore.RdbPredicates(T_TASK);
    pred.equalTo('id', id);
    const bucket: relationalStore.ValuesBucket = {
      'status': done ? TaskStatus.DONE : TaskStatus.PENDING,
      'doneAt': done ? Date.now() : 0,
      'updatedAt': Date.now()
    };
    await AppDb.s().update(bucket, pred);
  }

  static async deleteTask(id: number): Promise<void> {
    const pred = new relationalStore.RdbPredicates(T_TASK);
    pred.equalTo('id', id);
    await AppDb.s().delete(pred);
  }

  static async loadTasks(): Promise<Task[]> {
    const pred = new relationalStore.RdbPredicates(T_TASK);
    pred.orderByAsc('deadline');
    const rs = await AppDb.s().query(pred);
    const list: Task[] = [];
    while (rs.goToNextRow()) {
      const t = new Task();
      t.id = rs.getLong(rs.getColumnIndex('id'));
      t.title = rs.getString(rs.getColumnIndex('title'));
      t.type = rs.getLong(rs.getColumnIndex('type'));
      t.priority = rs.getLong(rs.getColumnIndex('priority'));
      t.deadline = rs.getLong(rs.getColumnIndex('deadline'));
      t.courseId = rs.getLong(rs.getColumnIndex('courseId'));
      t.status = rs.getLong(rs.getColumnIndex('status'));
      t.doneAt = rs.getLong(rs.getColumnIndex('doneAt'));
      t.createdAt = rs.getLong(rs.getColumnIndex('createdAt'));
      t.updatedAt = rs.getLong(rs.getColumnIndex('updatedAt'));
      list.push(t);
    }
    rs.close();
    return list;
  }

  // ---------------- 课程 ----------------

  /** 保存课程的时间段：先清后插 */
  private static async saveSlots(courseId: number, slots: CourseSlot[]): Promise<void> {
    const pred = new relationalStore.RdbPredicates(T_SLOT);
    pred.equalTo('courseId', courseId);
    await AppDb.s().delete(pred);
    for (const s of slots) {
      const bucket: relationalStore.ValuesBucket = {
        'courseId': courseId,
        'day': s.day,
        'startTime': s.start,
        'endTime': s.end
      };
      await AppDb.s().insert(T_SLOT, bucket);
    }
  }

  static async addCourse(c: Course): Promise<void> {
    const bucket: relationalStore.ValuesBucket = {
      'name': c.name,
      'teacher': c.teacher,
      'location': c.location,
      'createdAt': Date.now()
    };
    const rowId = await AppDb.s().insert(T_COURSE, bucket);
    if (rowId > 0) {
      await AppDb.saveSlots(rowId, c.slots);
    }
  }

  static async updateCourse(c: Course): Promise<void> {
    const pred = new relationalStore.RdbPredicates(T_COURSE);
    pred.equalTo('id', c.id);
    const bucket: relationalStore.ValuesBucket = {
      'name': c.name,
      'teacher': c.teacher,
      'location': c.location
    };
    await AppDb.s().update(bucket, pred);
    await AppDb.saveSlots(c.id, c.slots);
  }

  /** 删除课程时把关联任务的 courseId 置为未关联 */
  static async deleteCourse(id: number): Promise<void> {
    const taskPred = new relationalStore.RdbPredicates(T_TASK);
    taskPred.equalTo('courseId', id);
    const bucket: relationalStore.ValuesBucket = { 'courseId': -1 };
    await AppDb.s().update(bucket, taskPred);
    const slotPred = new relationalStore.RdbPredicates(T_SLOT);
    slotPred.equalTo('courseId', id);
    await AppDb.s().delete(slotPred);
    const pred = new relationalStore.RdbPredicates(T_COURSE);
    pred.equalTo('id', id);
    await AppDb.s().delete(pred);
  }

  static async loadCourses(): Promise<Course[]> {
    const pred = new relationalStore.RdbPredicates(T_COURSE);
    pred.orderByAsc('id');
    const rs = await AppDb.s().query(pred);
    const list: Course[] = [];
    while (rs.goToNextRow()) {
      const c = new Course();
      c.id = rs.getLong(rs.getColumnIndex('id'));
      c.name = rs.getString(rs.getColumnIndex('name'));
      c.teacher = rs.getString(rs.getColumnIndex('teacher'));
      c.location = rs.getString(rs.getColumnIndex('location'));
      c.createdAt = rs.getLong(rs.getColumnIndex('createdAt'));
      list.push(c);
    }
    rs.close();

    const slotPred = new relationalStore.RdbPredicates(T_SLOT);
    slotPred.orderByAsc('day');
    const sr = await AppDb.s().query(slotPred);
    while (sr.goToNextRow()) {
      const courseId = sr.getLong(sr.getColumnIndex('courseId'));
      const target = list.find((c: Course) => c.id === courseId);
      if (target !== undefined) {
        const s = new CourseSlot();
        s.day = sr.getLong(sr.getColumnIndex('day'));
        s.start = sr.getString(sr.getColumnIndex('startTime'));
        s.end = sr.getString(sr.getColumnIndex('endTime'));
        target.slots.push(s);
      }
    }
    sr.close();
    return list;
  }

  // ---------------- 考试 ----------------

  static async addExam(e: Exam): Promise<void> {
    const bucket: relationalStore.ValuesBucket = {
      'title': e.title,
      'courseId': e.courseId,
      'examAt': e.examAt,
      'location': e.location,
      'createdAt': Date.now()
    };
    await AppDb.s().insert(T_EXAM, bucket);
  }

  static async updateExam(e: Exam): Promise<void> {
    const pred = new relationalStore.RdbPredicates(T_EXAM);
    pred.equalTo('id', e.id);
    const bucket: relationalStore.ValuesBucket = {
      'title': e.title,
      'courseId': e.courseId,
      'examAt': e.examAt,
      'location': e.location
    };
    await AppDb.s().update(bucket, pred);
  }

  static async deleteExam(id: number): Promise<void> {
    const pred = new relationalStore.RdbPredicates(T_EXAM);
    pred.equalTo('id', id);
    await AppDb.s().delete(pred);
  }

  static async loadExams(): Promise<Exam[]> {
    const pred = new relationalStore.RdbPredicates(T_EXAM);
    pred.orderByAsc('examAt');
    const rs = await AppDb.s().query(pred);
    const list: Exam[] = [];
    while (rs.goToNextRow()) {
      const e = new Exam();
      e.id = rs.getLong(rs.getColumnIndex('id'));
      e.title = rs.getString(rs.getColumnIndex('title'));
      e.courseId = rs.getLong(rs.getColumnIndex('courseId'));
      e.examAt = rs.getLong(rs.getColumnIndex('examAt'));
      e.location = rs.getString(rs.getColumnIndex('location'));
      e.createdAt = rs.getLong(rs.getColumnIndex('createdAt'));
      list.push(e);
    }
    rs.close();
    return list;
  }

  // ---------------- 自定义分类 ----------------

  static async loadCategories(): Promise<CategoryPair> {
    const types: TaskCategory[] = [];
    const prios: PriorityLevel[] = [];
    const rs = await AppDb.s().query(new relationalStore.RdbPredicates(T_TYPE));
    while (rs.goToNextRow()) {
      types.push(new TaskCategory(rs.getLong(rs.getColumnIndex('id')), rs.getString(rs.getColumnIndex('name'))));
    }
    rs.close();
    const rs2 = await AppDb.s().query(new relationalStore.RdbPredicates(T_PRIO));
    while (rs2.goToNextRow()) {
      prios.push(new PriorityLevel(rs2.getLong(rs2.getColumnIndex('id')), rs2.getString(rs2.getColumnIndex('name'))));
    }
    rs2.close();
    const result: CategoryPair = { 'types': types, 'prios': prios };
    return result;
  }

  static async addType(name: string): Promise<void> {
    const bucket: relationalStore.ValuesBucket = { 'name': name };
    await AppDb.s().insert(T_TYPE, bucket);
  }

  static async updateType(id: number, name: string): Promise<void> {
    const pred = new relationalStore.RdbPredicates(T_TYPE);
    pred.equalTo('id', id);
    const bucket: relationalStore.ValuesBucket = { 'name': name };
    await AppDb.s().update(bucket, pred);
  }

  /** 删除类型：至少保留一个；该类型下的任务改挂到剩余的第一个类型 */
  static async deleteType(id: number): Promise<void> {
    const rs = await AppDb.s().query(new relationalStore.RdbPredicates(T_TYPE));
    const all: TaskCategory[] = [];
    while (rs.goToNextRow()) {
      all.push(new TaskCategory(rs.getLong(rs.getColumnIndex('id')), rs.getString(rs.getColumnIndex('name'))));
    }
    rs.close();
    const remain = all.filter((t: TaskCategory) => t.id !== id);
    if (remain.length === 0) {
      return;
    }
    const taskPred = new relationalStore.RdbPredicates(T_TASK);
    taskPred.equalTo('type', id);
    const bucket: relationalStore.ValuesBucket = { 'type': remain[0].id };
    await AppDb.s().update(bucket, taskPred);
    const pred = new relationalStore.RdbPredicates(T_TYPE);
    pred.equalTo('id', id);
    await AppDb.s().delete(pred);
  }

  static async addPrio(name: string): Promise<void> {
    const bucket: relationalStore.ValuesBucket = { 'name': name };
    await AppDb.s().insert(T_PRIO, bucket);
  }

  static async updatePrio(id: number, name: string): Promise<void> {
    const pred = new relationalStore.RdbPredicates(T_PRIO);
    pred.equalTo('id', id);
    const bucket: relationalStore.ValuesBucket = { 'name': name };
    await AppDb.s().update(bucket, pred);
  }

  /** 删除优先级：至少保留一档；该档任务改挂到中档（无中档则挂剩余最低档） */
  static async deletePrio(id: number): Promise<void> {
    const rs = await AppDb.s().query(new relationalStore.RdbPredicates(T_PRIO));
    const all: PriorityLevel[] = [];
    while (rs.goToNextRow()) {
      all.push(new PriorityLevel(rs.getLong(rs.getColumnIndex('id')), rs.getString(rs.getColumnIndex('name'))));
    }
    rs.close();
    const remain = all.filter((p: PriorityLevel) => p.id !== id);
    if (remain.length === 0) {
      return;
    }
    let fallback = remain[0].id;
    for (const p of remain) {
      if (p.id < fallback) {
        fallback = p.id;
      }
    }
    const taskPred = new relationalStore.RdbPredicates(T_TASK);
    taskPred.equalTo('priority', id);
    const bucket: relationalStore.ValuesBucket = { 'priority': fallback };
    await AppDb.s().update(bucket, taskPred);
    const pred = new relationalStore.RdbPredicates(T_PRIO);
    pred.equalTo('id', id);
    await AppDb.s().delete(pred);
  }
}
