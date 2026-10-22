import { AppDb } from '../db/AppDb';
import { Store } from '../common/Store';
import { TimeUtil } from '../common/TimeUtil';
import { Task, TaskStatus, compareTasks } from '../model/Task';
import { Course } from '../model/Course';
import { Exam } from '../model/Exam';
import { TaskCard } from './TaskCard';

/** 今日页课程行 */
class SlotView {
  name: string = '';
  location: string = '';
  time: string = '';
  startMin: number = 0;
  ongoing: boolean = false;
}

/**
 * 今日聚焦页（FR-14）：考试倒计时卡（学生模式）、今日课程、逾期区、今日区、已完成。
 */
@Component
export struct TodayView {
  @StorageLink('dbVersion') @Watch('reload') dbVer: number = 0;
  @StorageLink('studentMode') studentMode: boolean = true;
  @StorageLink('courseList') courses: Course[] = [];
  @StorageLink('examList') exams: Exam[] = [];
  @State overdue: Task[] = [];
  @State today: Task[] = [];
  @State doneToday: Task[] = [];
  openAdd: () => void = () => {};
  openEdit: (t: Task) => void = (_t: Task) => {};

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    AppDb.loadTasks().then((all: Task[]) => {
      this.overdue = all
        .filter((t: Task) => t.status === TaskStatus.PENDING && TimeUtil.daysUntil(t.deadline) < 0)
        .sort(compareTasks);
      this.today = all
        .filter((t: Task) => t.status === TaskStatus.PENDING && TimeUtil.daysUntil(t.deadline) === 0)
        .sort(compareTasks);
      this.doneToday = all
        .filter((t: Task) => t.status === TaskStatus.DONE && TimeUtil.sameDay(t.doneAt, Date.now()))
        .sort((a: Task, b: Task) => b.doneAt - a.doneAt);
    });
  }

  /** 全部未开考的考试（按时间升序） */
  private upcomingExams(): Exam[] {
    const today0 = TimeUtil.startOfToday();
    return this.exams
      .filter((e: Exam) => e.examAt >= today0)
      .sort((a: Exam, b: Exam) => a.examAt - b.examAt);
  }

  countdownText(e: Exam): string {
    const d = TimeUtil.daysUntil(e.examAt);
    return d <= 0 ? '今天开考' : `还有 ${d} 天`;
  }

  courseName(courseId: number): string {
    const c = this.courses.find((x: Course) => x.id === courseId);
    return c !== undefined ? c.name : '';
  }

  /** 今天还没结束的课程（按开始时间排序） */
  private todaySlots(): SlotView[] {
    const now = new Date();
    const wd = now.getDay() === 0 ? 7 : now.getDay();
    const nowMin = now.getHours() * 60 + now.getMinutes();
    const items: SlotView[] = [];
    for (const c of this.courses) {
      for (const s of c.slots) {
        if (s.day !== wd || s.start === '') {
          continue;
        }
        const sp: string[] = s.start.split(':');
        const sm = sp.length > 1 ? parseInt(sp[0]) * 60 + parseInt(sp[1]) : 0;
        let em = sm;
        if (s.end !== '') {
          const ep: string[] = s.end.split(':');
          em = ep.length > 1 ? parseInt(ep[0]) * 60 + parseInt(ep[1]) : sm;
        }
        if (em < nowMin) {
          continue; // 已结束
        }
        const v = new SlotView();
        v.name = c.name;
        v.location = c.location;
        v.time = s.end !== '' ? `${s.start}-${s.end}` : s.start;
        v.startMin = sm;
        v.ongoing = sm <= nowMin && nowMin <= em;
        items.push(v);
      }
    }
    items.sort((a: SlotView, b: SlotView) => a.startMin - b.startMin);
    return items;
  }

  toggle(t: Task): void {
    AppDb.setTaskDone(t.id, t.status !== TaskStatus.DONE).then(() => Store.bumpDb());
  }

  reschedule(t: Task, days: number): void {
    const nt = Task.copy(t);
    nt.deadline = TimeUtil.shiftDeadline(t.deadline, days);
    AppDb.updateTask(nt).then(() => Store.bumpDb());
  }

  build() {
    Column() {
      Text('今日聚焦')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ top: 16, bottom: 4 })
      Text(`${new Date().getMonth() + 1}月${new Date().getDate()}日 周${TimeUtil.WEEKDAY[new Date().getDay()]}`)
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'))

      Scroll() {
        Column() {
          // 考试倒计时卡（学生模式，列出全部未开考考试）
          if (this.studentMode && this.upcomingExams().length > 0) {
            Column({ space: 12 }) {
              Row({ space: 6 }) {
                Text('考试倒计时')
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .opacity(0.75)
                Blank()
                Text('📚').fontSize(16)
              }
              .width('100%')

              ForEach(this.upcomingExams(), (e: Exam) => {
                Row({ space: 12 }) {
                  Text(`距《${e.title}》`)
                    .fontSize(14)
                    .fontColor('#FFFFFF')
                    .opacity(0.92)
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  Text(this.countdownText(e))
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
                .width('100%')
                .alignItems(VerticalAlign.Center)
              }, (e: Exam) => `exam-${e.id}-${e.examAt}`)
            }
            .width('100%')
            .padding(18)
            .margin({ top: 14 })
            .borderRadius(16)
            .linearGradient({
              angle: 135,
              colors: [['#5B33B8', 0], ['#8A3DBE', 0.6], ['#B54880', 1]]
            })
          }

          // 今日课程（学生模式，未结束的按时间排序）
          if (this.studentMode && this.todaySlots().length > 0) {
            Column({ space: 8 }) {
              Row({ space: 8 }) {
                Column().width(8).height(8).borderRadius(4).backgroundColor($r('app.color.brand'))
                Text('今日课程').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
                Text(`${this.todaySlots().length}`).fontSize(13).fontColor($r('app.color.text_tertiary'))
                Blank()
              }
              .width('100%')
              .margin({ top: 18, bottom: 2 })

              ForEach(this.todaySlots(), (v: SlotView) => {
                Row({ space: 10 }) {
                  Text(v.time)
                    .fontSize(12)
                    .fontColor($r('app.color.brand'))
                    .width(84)
                  Text(v.name)
                    .fontSize(13)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .layoutWeight(1)
                  if (v.ongoing) {
                    Text('进行中')
                      .fontSize(10)
                      .fontColor($r('app.color.urgency_today'))
                      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                      .borderRadius(4)
                      .border({ width: 1, color: $r('app.color.urgency_today') })
                  }
                  if (v.location !== '') {
                    Text(v.location)
                      .fontSize(11)
                      .fontColor($r('app.color.text_tertiary'))
                      .maxLines(1)
                  }
                }
                .width('100%')
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .borderRadius(10)
                .backgroundColor($r('app.color.card_bg'))
                .alignItems(VerticalAlign.Center)
              }, (v: SlotView) => `${v.name}-${v.time}`)
            }
          }

          if (this.overdue.length === 0 && this.today.length === 0 && this.doneToday.length === 0) {
            Column({ space: 8 }) {
              Text('🌙').fontSize(40)
              Text('今天还没有任务')
                .fontSize(14)
                .fontColor($r('app.color.text_tertiary'))
              Text('点右下角 + 添加任务')
                .fontSize(12)
                .fontColor($r('app.color.text_disabled'))
            }
            .width('100%')
            .padding({ top: 60, bottom: 60 })
            .alignItems(HorizontalAlign.Center)
          }

          if (this.overdue.length > 0) {
            Row({ space: 8 }) {
              Column().width(8).height(8).borderRadius(4).backgroundColor($r('app.color.urgency_overdue'))
              Text('逾期').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              Text(`${this.overdue.length}`).fontSize(13).fontColor($r('app.color.text_tertiary'))
              Blank()
            }
            .width('100%')
            .margin({ top: 18, bottom: 8 })

            ForEach(this.overdue, (t: Task) => {
              TaskCard({
                task: t,
                courseName: this.courseName(t.courseId),
                onToggle: (x: Task) => this.toggle(x),
                onEdit: (x: Task) => this.openEdit(x),
                onReschedule: (x: Task, d: number) => this.reschedule(x, d)
              })
            }, (t: Task) => `ov-${t.id}-${t.updatedAt}`)
          }

          if (this.today.length > 0) {
            Row({ space: 8 }) {
              Column().width(8).height(8).borderRadius(4).backgroundColor($r('app.color.urgency_today'))
              Text('今天').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              Text(`${this.today.length}`).fontSize(13).fontColor($r('app.color.text_tertiary'))
              Blank()
            }
            .width('100%')
            .margin({ top: 18, bottom: 8 })

            ForEach(this.today, (t: Task) => {
              TaskCard({
                task: t,
                courseName: this.courseName(t.courseId),
                onToggle: (x: Task) => this.toggle(x),
                onEdit: (x: Task) => this.openEdit(x),
                onReschedule: (x: Task, d: number) => this.reschedule(x, d)
              })
            }, (t: Task) => `td-${t.id}-${t.updatedAt}`)
          }

          if (this.doneToday.length > 0) {
            Row({ space: 8 }) {
              Column().width(8).height(8).borderRadius(4).backgroundColor($r('app.color.text_tertiary'))
              Text('已完成').fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              Text(`${this.doneToday.length}`).fontSize(13).fontColor($r('app.color.text_tertiary'))
              Blank()
            }
            .width('100%')
            .margin({ top: 18, bottom: 8 })

            ForEach(this.doneToday, (t: Task) => {
              TaskCard({
                task: t,
                courseName: this.courseName(t.courseId),
                onToggle: (x: Task) => this.toggle(x),
                onEdit: (x: Task) => this.openEdit(x)
              })
            }, (t: Task) => `dn-${t.id}-${t.doneAt}`)
          }
        }
        .padding({ left: 16, right: 16, bottom: 90 })
        .constraintSize({ minHeight: '100%' })
      }
      .layoutWeight(1)
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }
}
