import { AppDb } from '../db/AppDb';
import { Store } from '../common/Store';
import { TimeUtil } from '../common/TimeUtil';
import { Exam } from '../model/Exam';
import { Course } from '../model/Course';
import { promptAction } from '@kit.ArkUI';

/**
 * 新增/编辑考试面板：考试是独立实体（有确定的考试时刻），与"备考"任务区分。
 */
@Component
export struct ExamSheet {
  @Prop @Watch('onExamChange') exam: Exam = new Exam();
  @StorageLink('courseList') courses: Course[] = [];
  @State title: string = '';
  @State location: string = '';
  @State courseId: number = -1;
  @State dateStart: number = TimeUtil.startOfToday();
  @State timeText: string = '09:00';
  @State isEdit: boolean = false;
  onClose: () => void = () => {};

  onExamChange(): void {
    this.initFields();
  }

  aboutToAppear(): void {
    this.initFields();
  }

  initFields(): void {
    this.isEdit = this.exam.id > 0;
    this.title = this.exam.title;
    this.location = this.exam.location;
    this.courseId = this.exam.courseId;
    if (this.exam.examAt > 0) {
      this.dateStart = TimeUtil.startOfDay(new Date(this.exam.examAt));
      this.timeText = TimeUtil.fmtTime(this.exam.examAt);
    } else {
      this.dateStart = TimeUtil.startOfToday();
      this.timeText = '09:00';
    }
  }

  composedExamAt(): number {
    const d = new Date(this.dateStart);
    const parts: string[] = this.timeText.split(':');
    const h = parts.length > 0 ? parseInt(parts[0]) : 9;
    const m = parts.length > 1 ? parseInt(parts[1]) : 0;
    d.setHours(isNaN(h) ? 9 : h, isNaN(m) ? 0 : m, 0, 0);
    return d.getTime();
  }

  save(): void {
    const t = this.title.trim();
    if (t === '') {
      promptAction.showToast({ message: '考试名称不能为空' });
      return;
    }
    const ne = Exam.copy(this.exam);
    ne.title = t;
    ne.location = this.location.trim();
    ne.examAt = this.composedExamAt();
    ne.courseId = this.courseId;
    const job = ne.id > 0 ? AppDb.updateExam(ne) : AppDb.addExam(ne);
    job.then(() => {
      Store.refreshExams();
      Store.bumpDb();
      this.onClose();
    });
  }

  remove(): void {
    this.getUIContext().showAlertDialog({
      title: '删除考试',
      message: `确定删除「${this.exam.title}」吗？`,
      primaryButton: {
        value: '取消',
        action: () => {}
      },
      secondaryButton: {
        value: '删除',
        fontColor: $r('app.color.urgency_overdue'),
        action: () => {
          AppDb.deleteExam(this.exam.id).then(() => {
            Store.refreshExams();
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
        Text(this.isEdit ? '编辑考试' : '添加考试')
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

      TextInput({ text: this.title, placeholder: '考试名称（如：高等数学 期中）' })
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
        Text('关联课程').fontSize(14).fontColor($r('app.color.text_secondary')).width(64)
        Blank()
        Select([{ value: '不关联' } as SelectOption].concat(
          this.courses.map((c: Course) => ({ value: c.name } as SelectOption))
        ))
          .selected(this.courseId < 0 ? 0 : this.courses.findIndex((c: Course) => c.id === this.courseId) + 1)
          .value(this.courseName())
          .font({ size: 14 })
          .onSelect((i: number) => {
            this.courseId = i === 0 ? -1 : this.courses[i - 1].id;
          })
      }.width('100%')

      Row() {
        Text('考试日期').fontSize(14).fontColor($r('app.color.text_secondary')).width(64)
        Blank()
        Text(`${TimeUtil.fmtDate(this.dateStart)} 周${TimeUtil.WEEKDAY[new Date(this.dateStart).getDay()]}`)
          .fontSize(14)
          .fontColor($r('app.color.brand'))
          .onClick(() => {
            this.getUIContext().showDatePickerDialog({
              start: new Date(TimeUtil.startOfToday() - 365 * TimeUtil.DAY_MS),
              end: new Date(TimeUtil.startOfToday() + 5 * 365 * TimeUtil.DAY_MS),
              selected: new Date(this.dateStart),
              onDateAccept: (v: Date) => {
                this.dateStart = TimeUtil.startOfDay(v);
              }
            });
          })
      }.width('100%')

      Row() {
        Text('开考时刻').fontSize(14).fontColor($r('app.color.text_secondary')).width(64)
        Blank()
        Text(this.timeText)
          .fontSize(14)
          .fontColor($r('app.color.brand'))
          .onClick(() => {
            const cur = this.composedExamAt();
            this.getUIContext().showTimePickerDialog({
              selected: new Date(cur),
              useMilitaryTime: true,
              onAccept: (v: TimePickerResult) => {
                this.timeText = `${TimeUtil.pad(v.hour)}:${TimeUtil.pad(v.minute)}`;
              }
            });
          })
      }.width('100%')

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

      Blank()

      Button(this.isEdit ? '保存修改' : '添加考试')
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor($r('app.color.brand'))
        .onClick(() => this.save())
    }
    .padding(20)
    .width('100%')
  }

  private courseName(): string {
    if (this.courseId < 0) {
      return '不关联';
    }
    const c = this.courses.find((x: Course) => x.id === this.courseId);
    return c !== undefined ? c.name : '不关联';
  }
}
