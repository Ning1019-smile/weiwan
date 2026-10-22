import { AppDb } from '../db/AppDb';
import { Store } from '../common/Store';
import { TimeUtil } from '../common/TimeUtil';
import { Course, CourseSlot, WEEKDAY_NAMES } from '../model/Course';
import { promptAction } from '@kit.ArkUI';

/**
 * 新增/编辑课程面板（FR-16）：支持多个上课时间段。
 */
@Component
export struct CourseSheet {
  @Prop @Watch('onCourseChange') course: Course = new Course();
  @State name: string = '';
  @State teacher: string = '';
  @State location: string = '';
  @State slots: CourseSlot[] = [];
  @State isEdit: boolean = false;
  @State timePickVisible: boolean = false;
  @State timePickIdx: number = 0;
  @State timePickIsStart: boolean = false;
  onClose: () => void = () => {};

  onCourseChange(): void {
    this.initFields();
  }

  aboutToAppear(): void {
    this.initFields();
  }

  initFields(): void {
    this.isEdit = this.course.id > 0;
    this.name = this.course.name;
    this.teacher = this.course.teacher;
    this.location = this.course.location;
    this.slots = this.course.slots.length > 0
      ? this.course.slots.map((s: CourseSlot) => CourseSlot.copy(s))
      : [new CourseSlot()];
  }

  addSlot(): void {
    const s = new CourseSlot();
    s.day = 1;
    this.slots.push(s);
  }

  removeSlot(i: number): void {
    this.slots.splice(i, 1);
    if (this.slots.length === 0) {
      const s = new CourseSlot();
      s.day = 1;
      this.slots.push(s);
    }
  }

  /** 打开自定义时间选择面板：标题显示该时间段对应的星期几 */
  openTimePick(i: number, isStart: boolean): void {
    this.timePickIdx = i;
    this.timePickIsStart = isStart;
    this.timePickVisible = true;
  }

  pickerDate(): Date {
    const cur = this.timePickIdx < this.slots.length ? this.slots[this.timePickIdx] : new CourseSlot();
    const src = this.timePickIsStart ? cur.start : cur.end;
    const parts: string[] = src.split(':');
    const h = parts.length > 0 && !isNaN(parseInt(parts[0])) ? parseInt(parts[0]) : 8;
    const m = parts.length > 1 && !isNaN(parseInt(parts[1])) ? parseInt(parts[1]) : 0;
    const d = new Date();
    d.setHours(h, m, 0, 0);
    return d;
  }

  applyPick(h: number, m: number): void {
    const i = this.timePickIdx;
    if (i < 0 || i >= this.slots.length) {
      return;
    }
    const updated = CourseSlot.copy(this.slots[i]);
    const val = `${TimeUtil.pad(h)}:${TimeUtil.pad(m)}`;
    if (this.timePickIsStart) {
      updated.start = val;
    } else {
      updated.end = val;
    }
    this.slots.splice(i, 1, updated);
  }

  pickTitle(): string {
    const i = this.timePickIdx;
    const day = i >= 0 && i < this.slots.length ? this.slots[i].day : 1;
    const wd = day >= 1 && day <= 7 ? WEEKDAY_NAMES[day - 1] : '周一';
    return `${wd} · ${this.timePickIsStart ? '开始' : '结束'}时间`;
  }

  save(): void {
    const n = this.name.trim();
    if (n === '') {
      promptAction.showToast({ message: '课程名不能为空' });
      return;
    }
    const c = Course.copy(this.course);
    c.name = n;
    c.teacher = this.teacher.trim();
    c.location = this.location.trim();
    // 丢弃一行都没填时间的空时间段
    c.slots = this.slots.filter((s: CourseSlot) => s.start !== '' || s.end !== '');
    const job = c.id > 0 ? AppDb.updateCourse(c) : AppDb.addCourse(c);
    job.then(() => {
      Store.refreshCourses();
      Store.bumpCourses();
      this.onClose();
    });
  }

  remove(): void {
    this.getUIContext().showAlertDialog({
      title: '删除课程',
      message: `确定删除「${this.course.name}」吗？关联任务的课程标记会被移除。`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.urgency_overdue'),
        action: () => {
          AppDb.deleteCourse(this.course.id).then(() => {
            Store.refreshCourses();
            Store.bumpCourses();
            this.onClose();
          });
        }
      }
    });
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text(this.isEdit ? '编辑课程' : '新增课程')
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

      TextInput({ text: this.name, placeholder: '课程名称（必填）' })
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .height(44)
        .borderRadius(10)
        .backgroundColor($r('app.color.input_bg'))
        .onChange((v: string) => {
          this.name = v;
        })

      TextInput({ text: this.teacher, placeholder: '教师（选填）' })
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .height(44)
        .borderRadius(10)
        .backgroundColor($r('app.color.input_bg'))
        .onChange((v: string) => {
          this.teacher = v;
        })

      TextInput({ text: this.location, placeholder: '地点（选填）' })
        .fontSize(15)
        .fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary'))
        .height(44)
        .borderRadius(10)
        .backgroundColor($r('app.color.input_bg'))
        .onChange((v: string) => {
          this.location = v;
        })

      // 多时间段
      Column({ space: 8 }) {
        Text('上课时间（可添加多个时间段）')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))

        ForEach(this.slots, (s: CourseSlot, i: number) => {
          Row({ space: 8 }) {
            Select(WEEKDAY_NAMES.map((w: string) => ({ value: w } as SelectOption)))
              .selected(s.day - 1)
              .value(s.day >= 1 && s.day <= 7 ? WEEKDAY_NAMES[s.day - 1] : '周一')
              .font({ size: 13 })
              .onSelect((idx: number) => {
                this.slots[i].day = idx + 1;
              })

            Text(s.start === '' ? '开始' : s.start)
              .fontSize(13)
              .fontColor(s.start === '' ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
              .textAlign(TextAlign.Center)
              .height(38)
              .borderRadius(8)
              .backgroundColor($r('app.color.input_bg'))
              .layoutWeight(1)
              .onClick(() => {
                this.openTimePick(i, true);
              })

            Text('-').fontSize(12).fontColor($r('app.color.text_tertiary'))

            Text(s.end === '' ? '结束' : s.end)
              .fontSize(13)
              .fontColor(s.end === '' ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
              .textAlign(TextAlign.Center)
              .height(38)
              .borderRadius(8)
              .backgroundColor($r('app.color.input_bg'))
              .layoutWeight(1)
              .onClick(() => {
                this.openTimePick(i, false);
              })

            Text('×')
              .fontSize(16)
              .fontColor($r('app.color.text_tertiary'))
              .width(26)
              .height(26)
              .textAlign(TextAlign.Center)
              .borderRadius(13)
              .backgroundColor($r('app.color.input_bg'))
              .onClick(() => this.removeSlot(i))
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }, (s: CourseSlot, i: number) => `slot-${i}-${s.start}-${s.end}`)

        Text('+ 添加时间段')
          .fontSize(13)
          .fontColor($r('app.color.brand'))
          .padding({ top: 4, bottom: 4 })
          .onClick(() => this.addSlot())
      }
      .width('100%')
      .padding(12)
      .borderRadius(10)
      .backgroundColor($r('app.color.card_bg'))
      .border({ width: 1, color: $r('app.color.divider') })
      .alignItems(HorizontalAlign.Start)

      Blank()

      Button(this.isEdit ? '保存修改' : '添加课程')
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor($r('app.color.brand'))
        .onClick(() => this.save())
    }
    .padding(20)
    .width('100%')
    .bindSheet($$this.timePickVisible, this.timePickBuilder(), {
      detents: [SheetSize.FIT_CONTENT],
      showClose: false
    })
  }

  @Builder
  timePickBuilder() {
    Column({ space: 12 }) {
      Text(this.pickTitle())
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      TimePicker({ selected: this.pickerDate() })
        .onChange((v: TimePickerResult) => {
          this.applyPick(v.hour, v.minute);
        })

      Button('完成')
        .width('100%')
        .height(42)
        .fontSize(15)
        .backgroundColor($r('app.color.brand'))
        .onClick(() => {
          this.timePickVisible = false;
        })
    }
    .padding(20)
    .width('100%')
  }
}
