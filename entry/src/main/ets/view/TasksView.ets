import { AppDb } from '../db/AppDb';
import { Store } from '../common/Store';
import { TimeUtil } from '../common/TimeUtil';
import {
  Task, TaskStatus, compareTasks, urgencyColor, urgencyLabel, urgencyOf, Urgency
} from '../model/Task';
import { Course } from '../model/Course';
import { TaskCard } from './TaskCard';

class TaskGroup {
  label: string = '';
  color: ResourceColor = '';
  items: Task[] = [];
}

/**
 * 任务列表页（FR-02）：全部待办按紧迫度分组，已完成折叠展示。
 */
@Component
export struct TasksView {
  @StorageLink('dbVersion') @Watch('reload') dbVer: number = 0;
  @StorageLink('courseList') courses: Course[] = [];
  @State groups: TaskGroup[] = [];
  @State done: Task[] = [];
  @State showDone: boolean = false;
  openAdd: () => void = () => {};
  openEdit: (t: Task) => void = (_t: Task) => {};

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    AppDb.loadTasks().then((all: Task[]) => {
      const pending = all.filter((t: Task) => t.status === TaskStatus.PENDING).sort(compareTasks);
      const order: number[] = [Urgency.OVERDUE, Urgency.TODAY, Urgency.TOMORROW, Urgency.WEEK, Urgency.LATER];
      const gs: TaskGroup[] = [];
      for (const u of order) {
        const items = pending.filter((t: Task) => this.uOf(t) === u);
        if (items.length > 0) {
          const g = new TaskGroup();
          g.label = urgencyLabel(u);
          g.color = urgencyColor(u);
          g.items = items;
          gs.push(g);
        }
      }
      this.groups = gs;
      this.done = all
        .filter((t: Task) => t.status === TaskStatus.DONE)
        .sort((a: Task, b: Task) => b.doneAt - a.doneAt);
    });
  }

  uOf(t: Task): number {
    return urgencyOf(t);
  }

  courseName(courseId: number): string {
    const c = this.courses.find((x: Course) => x.id === courseId);
    return c !== undefined ? c.name : '';
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
      Row() {
        Text('任务')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(`待办 ${this.groups.reduce((n: number, g: TaskGroup) => n + g.items.length, 0)} · 已完成 ${this.done.length}`)
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
      }
      .width('100%')
      .padding({ top: 16, bottom: 4, left: 16, right: 16 })

      Scroll() {
        Column() {
          if (this.groups.length === 0 && this.done.length === 0) {
            Column({ space: 8 }) {
              Text('📋').fontSize(40)
              Text('还没有任务')
                .fontSize(14)
                .fontColor($r('app.color.text_tertiary'))
              Text('点右下角 + 新建第一个任务')
                .fontSize(12)
                .fontColor($r('app.color.text_disabled'))
            }
            .width('100%')
            .padding({ top: 80, bottom: 80 })
            .alignItems(HorizontalAlign.Center)
          }

          ForEach(this.groups, (g: TaskGroup) => {
            Row({ space: 8 }) {
              Column().width(8).height(8).borderRadius(4).backgroundColor(g.color)
              Text(g.label).fontSize(14).fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
              Text(`${g.items.length}`).fontSize(13).fontColor($r('app.color.text_tertiary'))
              Blank()
            }
            .width('100%')
            .margin({ top: 16, bottom: 8 })

            ForEach(g.items, (t: Task) => {
              TaskCard({
                task: t,
                courseName: this.courseName(t.courseId),
                onToggle: (x: Task) => this.toggle(x),
                onEdit: (x: Task) => this.openEdit(x),
                onReschedule: (x: Task, d: number) => this.reschedule(x, d)
              })
            }, (t: Task) => `g-${t.id}-${t.updatedAt}`)
          }, (g: TaskGroup) => `${g.label}-${g.items.length}`)

          if (this.done.length > 0) {
            Row({ space: 6 }) {
              Text(this.showDone ? '▾' : '▸').fontSize(12).fontColor($r('app.color.text_tertiary'))
              Text(`已完成 (${this.done.length})`)
                .fontSize(14)
                .fontColor($r('app.color.text_tertiary'))
              Blank()
            }
            .width('100%')
            .margin({ top: 20, bottom: 8 })
            .onClick(() => {
              this.showDone = !this.showDone;
            })

            if (this.showDone) {
              ForEach(this.done, (t: Task) => {
                TaskCard({
                  task: t,
                  courseName: this.courseName(t.courseId),
                  onToggle: (x: Task) => this.toggle(x),
                  onEdit: (x: Task) => this.openEdit(x)
                })
              }, (t: Task) => `d-${t.id}-${t.doneAt}`)
            }
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
