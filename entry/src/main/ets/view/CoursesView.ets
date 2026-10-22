import { AppDb } from '../db/AppDb';
import { Store } from '../common/Store';
import { Course, courseTimeText } from '../model/Course';

/**
 * 课程页（学生模式，FR-16）：课程列表 + 新增/编辑入口。
 */
@Component
export struct CoursesView {
  @StorageLink('dbVersion') @Watch('reload') dbVer: number = 0;
  @StorageLink('courseList') courses: Course[] = [];
  openAddCourse: () => void = () => {};
  openEditCourse: (c: Course) => void = (_c: Course) => {};

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    AppDb.loadCourses().then((list: Course[]) => {
      AppStorage.setOrCreate<Course[]>('courseList', list);
    });
  }

  build() {
    Column() {
      Row() {
        Text('课程')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
      }
      .width('100%')
      .padding({ top: 16, bottom: 4, left: 16, right: 16 })

      Scroll() {
        Column({ space: 10 }) {
          if (this.courses.length === 0) {
            Column({ space: 8 }) {
              Text('🎓').fontSize(40)
              Text('还没有课程')
                .fontSize(14)
                .fontColor($r('app.color.text_tertiary'))
              Text('添加课程后，任务可以关联到课程')
                .fontSize(12)
                .fontColor($r('app.color.text_disabled'))
            }
            .width('100%')
            .padding({ top: 80, bottom: 80 })
            .alignItems(HorizontalAlign.Center)
          }

          ForEach(this.courses, (c: Course) => {
            Column({ space: 6 }) {
              Row() {
                Text(c.name)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                  .layoutWeight(1)
                if (courseTimeText(c) !== '') {
                  Text(courseTimeText(c))
                    .fontSize(12)
                    .fontColor($r('app.color.brand'))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(10)
                    .backgroundColor($r('app.color.brand_chip_bg'))
                }
              }
              .width('100%')

              if (c.teacher !== '' || c.location !== '') {
                Text([c.teacher, c.location].filter((s: string) => s !== '').join(' · '))
                  .fontSize(12)
                  .fontColor($r('app.color.text_tertiary'))
              }
            }
            .width('100%')
            .padding(14)
            .borderRadius(12)
            .backgroundColor($r('app.color.card_bg'))
            .alignItems(HorizontalAlign.Start)
            .onClick(() => this.openEditCourse(c))
          }, (c: Course) => `c-${c.id}-${c.name}-${c.slots.length}`)
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
