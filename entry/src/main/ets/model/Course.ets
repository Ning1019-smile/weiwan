export class Course {
  id: number = 0;
  name: string = '';
  teacher: string = '';
  location: string = '';
  /** 上课时间段（可多个），存储在 course_slot 表 */
  slots: CourseSlot[] = [];
  createdAt: number = 0;

  static copy(c: Course): Course {
    const n = new Course();
    n.id = c.id;
    n.name = c.name;
    n.teacher = c.teacher;
    n.location = c.location;
    n.createdAt = c.createdAt;
    n.slots = c.slots.map((s: CourseSlot) => CourseSlot.copy(s));
    return n;
  }
}

export class CourseSlot {
  /** 周几，1-7 */
  day: number = 1;
  start: string = '';
  end: string = '';

  static copy(s: CourseSlot): CourseSlot {
    const n = new CourseSlot();
    n.day = s.day;
    n.start = s.start;
    n.end = s.end;
    return n;
  }
}

export const WEEKDAY_NAMES: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

/** 多时间段合并展示：周一 08:00-09:40 · 周三 10:00-11:40 */
export function courseTimeText(c: Course): string {
  const parts: string[] = [];
  for (const s of c.slots) {
    if (s.day < 1 || s.day > 7) {
      continue;
    }
    let p = WEEKDAY_NAMES[s.day - 1];
    if (s.start !== '') {
      p += ` ${s.start}`;
      if (s.end !== '') {
        p += `-${s.end}`;
      }
    }
    parts.push(p);
  }
  return parts.join(' · ');
}
