/** 任务类型的名称由自定义分类表下发（task_type），任务里只存 id */

/** 优先级档位 id 由 task_priority 表下发，id 越大档位越高 */

export enum TaskStatus {
  PENDING = 0,
  DONE = 1
}

/** 紧迫度分级（PRD R1） */
export enum Urgency {
  OVERDUE = 0,
  TODAY = 1,
  TOMORROW = 2,
  WEEK = 3,
  LATER = 4,
  DONE = 5
}

export class Task {
  id: number = 0;
  title: string = '';
  /** 关联 task_type.id */
  type: number = 0;
  /** 关联 task_priority.id，越大越优先 */
  priority: number = 1;
  /** 截止时间（毫秒时间戳，含时刻） */
  deadline: number = 0;
  /** 关联课程 id，-1 表示未关联 */
  courseId: number = -1;
  status: number = TaskStatus.PENDING;
  doneAt: number = 0;
  createdAt: number = 0;
  updatedAt: number = 0;

  static copy(t: Task): Task {
    const n = new Task();
    n.id = t.id;
    n.title = t.title;
    n.type = t.type;
    n.priority = t.priority;
    n.deadline = t.deadline;
    n.courseId = t.courseId;
    n.status = t.status;
    n.doneAt = t.doneAt;
    n.createdAt = t.createdAt;
    n.updatedAt = t.updatedAt;
    return n;
  }
}

/** 紧迫度主色（逾期红 / 今天橙 / 明天黄 / 一周内蓝 / 更远灰），资源色随深浅色模式切换 */
export function urgencyColor(u: number): ResourceColor {
  switch (u) {
    case Urgency.OVERDUE:
      return $r('app.color.urgency_overdue');
    case Urgency.TODAY:
      return $r('app.color.urgency_today');
    case Urgency.TOMORROW:
      return $r('app.color.urgency_tomorrow');
    case Urgency.WEEK:
      return $r('app.color.urgency_week');
    default:
      return $r('app.color.urgency_later');
  }
}

export function urgencyLabel(u: number): string {
  switch (u) {
    case Urgency.OVERDUE:
      return '逾期';
    case Urgency.TODAY:
      return '今天';
    case Urgency.TOMORROW:
      return '明天';
    case Urgency.WEEK:
      return '一周内';
    case Urgency.DONE:
      return '已完成';
    default:
      return '更远';
  }
}

const TimeDayMs: number = 24 * 3600 * 1000;

/** 计算紧迫度（逾期为派生状态，无需落库） */
export function urgencyOf(t: Task): number {
  if (t.status === TaskStatus.DONE) {
    return Urgency.DONE;
  }
  const days = Math.round(
    (new Date(t.deadline).setHours(0, 0, 0, 0) - new Date().setHours(0, 0, 0, 0)) / TimeDayMs
  );
  if (days < 0) {
    return Urgency.OVERDUE;
  }
  if (days === 0) {
    return Urgency.TODAY;
  }
  if (days === 1) {
    return Urgency.TOMORROW;
  }
  if (days <= 7) {
    return Urgency.WEEK;
  }
  return Urgency.LATER;
}

/** PRD R2 排序：紧迫度升序 → 优先级降序 → 截止时间升序 */
export function compareTasks(a: Task, b: Task): number {
  const ua = urgencyOf(a);
  const ub = urgencyOf(b);
  if (ua !== ub) {
    return ua - ub;
  }
  if (a.priority !== b.priority) {
    return b.priority - a.priority;
  }
  return a.deadline - b.deadline;
}
