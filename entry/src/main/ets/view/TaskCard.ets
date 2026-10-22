import { Task, Urgency, urgencyColor, urgencyOf, TaskStatus } from '../model/Task';
import { TaskCategory } from '../model/Category';
import { TimeUtil } from '../common/TimeUtil';

/**
 * 任务卡：左侧紧迫度色边 + 标题/元信息 + 完成勾选。
 * 逾期未完成任务附一键改期按钮（FR-06）。
 */
@Component
export struct TaskCard {
  @Prop @Watch('onTaskChange') task: Task = new Task();
  @Prop courseName: string = '';
  @StorageLink('typeList') types: TaskCategory[] = [];
  onToggle: (t: Task) => void = (_t: Task) => {};
  onEdit: (t: Task) => void = (_t: Task) => {};
  onReschedule: (t: Task, days: number) => void = (_t: Task, _d: number) => {};

  onTaskChange(): void {
  }

  private isDone(): boolean {
    return this.task.status === TaskStatus.DONE;
  }

  private typeName(): string {
    const c = this.types.find((x: TaskCategory) => x.id === this.task.type);
    return c !== undefined ? c.name : '';
  }

  build() {
    Row({ space: 10 }) {
      Column({ space: 4 }) {
        Text(this.task.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isDone() ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .decoration({
            type: this.isDone() ? TextDecorationType.LineThrough : TextDecorationType.None,
            color: $r('app.color.text_tertiary')
          })

        Row({ space: 6 }) {
          if (this.typeName() !== '') {
            Text(this.typeName())
              .fontSize(10)
              .fontColor($r('app.color.text_secondary'))
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .borderRadius(4)
              .backgroundColor($r('app.color.input_bg'))
          }

          if (this.courseName !== '') {
            Text(this.courseName)
              .fontSize(10)
              .fontColor($r('app.color.brand'))
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .borderRadius(4)
              .backgroundColor($r('app.color.brand_chip_bg'))
          }

          Text(TimeUtil.fmtDeadline(this.task.deadline))
            .fontSize(11)
            .fontColor(this.isDone() ? $r('app.color.text_tertiary') : urgencyColor(urgencyOf(this.task)))
        }
        .alignItems(VerticalAlign.Center)

        // 逾期未完成：一键改期
        if (urgencyOf(this.task) === Urgency.OVERDUE && !this.isDone()) {
          Row({ space: 8 }) {
            Text('改为今天')
              .fontSize(11)
              .fontColor($r('app.color.urgency_today'))
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(10)
              .border({ width: 1, color: $r('app.color.urgency_today') })
              .onClick(() => {
                this.onReschedule(this.task, 0);
              })
            Text('改为明天')
              .fontSize(11)
              .fontColor($r('app.color.urgency_tomorrow'))
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .borderRadius(10)
              .border({ width: 1, color: $r('app.color.urgency_tomorrow') })
              .onClick(() => {
                this.onReschedule(this.task, 1);
              })
          }
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .onClick(() => {
        this.onEdit(this.task);
      })

      // 完成勾选
      if (this.isDone()) {
        Text('✓')
          .fontSize(12)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
          .width(20)
          .height(20)
          .borderRadius(10)
          .backgroundColor($r('app.color.text_tertiary'))
          .onClick(() => {
            this.onToggle(this.task);
          })
      } else {
        Column()
          .width(20)
          .height(20)
          .borderRadius(10)
          .border({ width: 2, color: $r('app.color.text_disabled') })
          .onClick(() => {
            this.onToggle(this.task);
          })
      }
    }
    .width('100%')
    .padding(10)
    .margin({ bottom: 8 })
    .borderRadius(10)
    .backgroundColor($r('app.color.card_bg'))
    .border({
      width: { left: 3 },
      color: { left: urgencyColor(urgencyOf(this.task)) }
    })
    .alignItems(VerticalAlign.Center)
  }
}
