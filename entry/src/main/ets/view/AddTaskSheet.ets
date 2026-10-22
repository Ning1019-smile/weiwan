import { AppDb } from '../db/AppDb';
import { Store } from '../common/Store';
import { TimeUtil } from '../common/TimeUtil';
import { Task } from '../model/Task';
import { TaskCategory, PriorityLevel } from '../model/Category';
import { Course } from '../model/Course';
import { promptAction } from '@kit.ArkUI';

/** 分段选择器：独立组件保证状态变化触发刷新（@Builder 按值传参不会刷新） */
@Component
struct SegSelect {
  @Prop options: string[] = [];
  @Prop current: number = 0;
  onSelect: (i: number) => void = (_i: number) => {};

  build() {
    Row({ space: 6 }) {
      ForEach(this.options, (label: string, i: number) => {
        Text(label)
          .fontSize(13)
          .fontColor(i === this.current ? Color.White : $r('app.color.text_secondary'))
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .borderRadius(14)
          .backgroundColor(i === this.current ? $r('app.color.brand') : $r('app.color.input_bg'))
          .onClick(() => this.onSelect(i))
      }, (label: string) => label)
    }
  }
}

/**
 * 新建/编辑任务面板（FR-01/04/05）。类型/优先级来自自定义分类（我的页可管理）。
 */
@Component
export struct AddTaskSheet {
  @Prop @Watch('onTaskChange') task: Task = new Task();
  @StorageLink('courseList') courses: Course[] = [];
  @StorageLink('typeList') types: TaskCategory[] = [];
  @StorageLink('priList') prios: PriorityLevel[] = [];
  @State title: string = '';
  @State typeIdx: number = 0;
  @State priIdx: number = 1;
  @State dateStart: number = TimeUtil.startOfToday();
  @State timeText: string = '23:59';
  @State courseIdx: number = -1;
  @State isEdit: boolean = false;
  onClose: () => void = () => {};

  onTaskChange(): void {
    this.initFields();
  }

  aboutToAppear(): void {
    this.initFields();
  }

  initFields(): void {
    this.isEdit = this.task.id > 0;
    this.title = this.task.title;
    this.typeIdx = this.types.findIndex((c: TaskCategory) => c.id === this.task.type);
    if (this.typeIdx < 0) {
      this.typeIdx = 0;
    }
    this.priIdx = this.prios.findIndex((p: PriorityLevel) => p.id === this.task.priority);
    if (this.priIdx < 0) {
      this.priIdx = this.prios.length > 0 ? this.prios.length - 1 : 0;
    }
    if (this.task.deadline > 0) {
      this.dateStart = TimeUtil.startOfDay(new Date(this.task.deadline));
      this.timeText = TimeUtil.fmtTime(this.task.deadline);
    } else {
      this.dateStart = TimeUtil.startOfToday();
      this.timeText = '23:59';
    }
    this.courseIdx = this.courses.findIndex((c: Course) => c.id === this.task.courseId);
  }

  composedDeadline(): number {
    const d = new Date(this.dateStart);
    const parts: string[] = this.timeText.split(':');
    const h = parts.length > 0 ? parseInt(parts[0]) : 23;
    const m = parts.length > 1 ? parseInt(parts[1]) : 59;
    d.setHours(isNaN(h) ? 23 : h, isNaN(m) ? 59 : m, 0, 0);
    return d.getTime();
  }

  save(): void {
    const t = this.title.trim();
    if (t === '') {
      promptAction.showToast({ message: '标题不能为空' });
      return;
    }
    const nt = Task.copy(this.task);
    nt.title = t;
    nt.type = this.typeIdx < this.types.length ? this.types[this.typeIdx].id : 0;
    nt.priority = this.priIdx < this.prios.length ? this.prios[this.priIdx].id : 1;
    nt.deadline = this.composedDeadline();
    nt.courseId = this.courseIdx >= 0 && this.courseIdx < this.courses.length
      ? this.courses[this.courseIdx].id : -1;
    const job = nt.id > 0 ? AppDb.updateTask(nt) : AppDb.addTask(nt);
    job.then(() => {
      Store.bumpDb();
      this.onClose();
    });
  }

  remove(): void {
    this.getUIContext().showAlertDialog({
      title: '删除任务',
      message: `确定删除「${this.task.title}」吗？`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.urgency_overdue'),
        action: () => {
          AppDb.deleteTask(this.task.id).then(() => {
            Store.bumpDb();
            this.onClose();
          });
        }
      }
    });
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text(this.isEdit ? '编辑任务' : '新建任务')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        if (this.isEdit) {
          Text('删除')
            .fontSize(14)
            .fontColor($r('app.color.urgency_overdue'))
            .onClick(() => this.remove())
        }
      }.width('100%')

      TextInput({ text: this.title, placeholder: '任务标题' })
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .height(44)
        .borderRadius(10)
        .backgroundColor($r('app.color.input_bg'))
        .onChange((v: string) => {
          this.title = v;
        })

      Row() {
        Text('类型').fontSize(14).fontColor($r('app.color.text_secondary')).width(64)
        SegSelect({
          options: this.types.map((c: TaskCategory) => c.name),
          current: this.typeIdx,
          onSelect: (i: number) => {
            this.typeIdx = i;
          }
        })
      }.width('100%')

      Row() {
        Text('优先级').fontSize(14).fontColor($r('app.color.text_secondary')).width(64)
        SegSelect({
          options: this.prios.map((p: PriorityLevel) => p.name),
          current: this.priIdx,
          onSelect: (i: number) => {
            this.priIdx = i;
          }
        })
      }.width('100%')

      Row() {
        Text('截止日期').fontSize(14).fontColor($r('app.color.text_secondary')).width(64)
        Blank()
        Text(`${TimeUtil.fmtDate(this.dateStart)} 周${TimeUtil.WEEKDAY[new Date(this.dateStart).getDay()]}`)
          .fontSize(14)
          .fontColor($r('app.color.brand'))
          .onClick(() => {
            this.getUIContext().showDatePickerDialog({
              start: new Date(TimeUtil.startOfToday() - 5 * 365 * TimeUtil.DAY_MS),
              end: new Date(TimeUtil.startOfToday() + 5 * 365 * TimeUtil.DAY_MS),
              selected: new Date(this.dateStart),
              onDateAccept: (v: Date) => {
                this.dateStart = TimeUtil.startOfDay(v);
              }
            });
          })
      }.width('100%')

      Row() {
        Text('时刻').fontSize(14).fontColor($r('app.color.text_secondary')).width(64)
        Blank()
        Text(this.timeText)
          .fontSize(14)
          .fontColor($r('app.color.brand'))
          .onClick(() => {
            const cur = this.composedDeadline();
            this.getUIContext().showTimePickerDialog({
              selected: new Date(cur),
              useMilitaryTime: true,
              onAccept: (v: TimePickerResult) => {
                this.timeText = `${TimeUtil.pad(v.hour)}:${TimeUtil.pad(v.minute)}`;
              }
            });
          })
      }.width('100%')

      Row() {
        Text('关联课程').fontSize(14).fontColor($r('app.color.text_secondary')).width(64)
        Blank()
        Select([{ value: '不关联' } as SelectOption].concat(
          this.courses.map((c: Course) => ({ value: c.name } as SelectOption))
        ))
          .selected(this.courseIdx + 1)
          .value(this.courseIdx >= 0 && this.courseIdx < this.courses.length ? this.courses[this.courseIdx].name : '不关联')
          .font({ size: 14 })
          .onSelect((i: number) => {
            this.courseIdx = i - 1;
          })
      }.width('100%')

      Blank()

      Button(this.isEdit ? '保存修改' : '创建任务')
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor($r('app.color.brand'))
        .onClick(() => this.save())
    }
    .padding(20)
    .width('100%')
  }
}
