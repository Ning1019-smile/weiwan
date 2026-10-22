import { Store } from '../common/Store';
import { TimeUtil } from '../common/TimeUtil';
import { Exam } from '../model/Exam';
import { Course } from '../model/Course';

/**
 * 考试页（学生模式）：未结束的考试按时间升序，倒计时徽标 + 关联课程。
 */
@Component
export struct ExamsView {
  @StorageLink('examList') exams: Exam[] = [];
  @StorageLink('courseList') courses: Course[] = [];
  openAddExam: () => void = () => {};
  openEditExam: (e: Exam) => void = (_e: Exam) => {};

  /** 直接派生自 AppStorage 的 examList，添加/编辑后立即反映 */
  private upcoming(): Exam[] {
    const today0 = TimeUtil.startOfToday();
    return this.exams.filter((e: Exam) => e.examAt >= today0);
  }

  courseName(courseId: number): string {
    const c = this.courses.find((x: Course) => x.id === courseId);
    return c !== undefined ? c.name : '';
  }

  daysLeft(e: Exam): number {
    return TimeUtil.daysUntil(e.examAt);
  }

  countdownText(e: Exam): string {
    const d = this.daysLeft(e);
    if (d <= 0) {
      return '今天';
    }
    return `${d}天`;
  }

  build() {
    Column() {
      Text('考试')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ top: 16, bottom: 4, left: 16, right: 16 })

      Scroll() {
        Column({ space: 10 }) {
          if (this.upcoming().length === 0) {
            Column({ space: 8 }) {
              Text('📝').fontSize(40)
              Text('暂无考试')
                .fontSize(14)
                .fontColor($r('app.color.text_tertiary'))
              Text('点右下角 + 添加考试')
                .fontSize(12)
                .fontColor($r('app.color.text_disabled'))
            }
            .width('100%')
            .padding({ top: 80, bottom: 80 })
            .alignItems(HorizontalAlign.Center)
          }

          ForEach(this.upcoming(), (e: Exam) => {
            Row({ space: 12 }) {
              // 倒计时徽标
              Column({ space: 2 }) {
                Text('还有')
                  .fontSize(10)
                  .fontColor(Color.White)
                  .opacity(0.85)
                Text(this.countdownText(e))
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
              }
              .width(64)
              .height(64)
              .borderRadius(12)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .linearGradient({
                angle: 135,
                colors: [['#5B33B8', 0], ['#8A3DBE', 1]]
              })

              Column({ space: 4 }) {
                Text(e.title)
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Row({ space: 6 }) {
                  Text(`${TimeUtil.fmtDate(e.examAt)} ${TimeUtil.fmtTime(e.examAt)}`)
                    .fontSize(12)
                    .fontColor($r('app.color.text_secondary'))
                  if (this.courseName(e.courseId) !== '') {
                    Text(this.courseName(e.courseId))
                      .fontSize(10)
                      .fontColor($r('app.color.brand'))
                      .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                      .borderRadius(4)
                      .backgroundColor($r('app.color.brand_chip_bg'))
                  }
                }
                .alignItems(VerticalAlign.Center)
                if (e.location !== '') {
                  Text(e.location)
                    .fontSize(11)
                    .fontColor($r('app.color.text_tertiary'))
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding(12)
            .borderRadius(12)
            .backgroundColor($r('app.color.card_bg'))
            .alignItems(VerticalAlign.Center)
            .onClick(() => this.openEditExam(e))
          }, (e: Exam) => `e-${e.id}-${e.examAt}-${e.title}`)
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
