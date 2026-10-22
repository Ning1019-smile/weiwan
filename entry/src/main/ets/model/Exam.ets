/** 考试（独立实体，学生模式展示）：与"备考"任务区分，考试有确定的考试时刻 */
export class Exam {
  id: number = 0;
  title: string = '';
  /** 关联课程 id，-1 未关联 */
  courseId: number = -1;
  /** 考试时刻（毫秒时间戳） */
  examAt: number = 0;
  location: string = '';
  createdAt: number = 0;

  static copy(e: Exam): Exam {
    const n = new Exam();
    n.id = e.id;
    n.title = e.title;
    n.courseId = e.courseId;
    n.examAt = e.examAt;
    n.location = e.location;
    n.createdAt = e.createdAt;
    return n;
  }
}
