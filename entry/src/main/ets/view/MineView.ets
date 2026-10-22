import { AppDb } from '../db/AppDb';
import { Store } from '../common/Store';
import { Task, TaskStatus } from '../model/Task';
import { TaskCategory, PriorityLevel } from '../model/Category';
import { PrivacyDialog } from './PrivacyDialog';
import { promptAction } from '@kit.ArkUI';

/**
 * 我的页：统计、学生模式开关（FR-24）、类型/优先级自定义管理、隐私政策。
 */
@Component
export struct MineView {
  @StorageLink('dbVersion') @Watch('reload') dbVer: number = 0;
  @StorageLink('studentMode') studentMode: boolean = true;
  @StorageLink('typeList') types: TaskCategory[] = [];
  @StorageLink('priList') prios: PriorityLevel[] = [];
  @State pendingCount: number = 0;
  @State doneCount: number = 0;
  @State overdueCount: number = 0;
  @State mgrVisible: boolean = false;
  @State mgrKind: string = 'type'; // 'type' | 'prio'
  @State newTypeName: string = '';
  @State newPrioName: string = '';

  // 隐私政策查阅弹窗（不做首启强制，仅阅读）
  privacyCtrl: CustomDialogController = new CustomDialogController({
    builder: PrivacyDialog({ cancel: () => {}, confirm: () => {}, reviewMode: true }),
    autoCancel: true,
    customStyle: true
  });

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    AppDb.loadTasks().then((all: Task[]) => {
      this.pendingCount = all.filter((t: Task) => t.status === TaskStatus.PENDING).length;
      this.doneCount = all.filter((t: Task) => t.status === TaskStatus.DONE).length;
      const today0 = new Date().setHours(0, 0, 0, 0);
      this.overdueCount = all.filter((t: Task) =>
        t.status === TaskStatus.PENDING && t.deadline < today0).length;
    });
  }

  onModeChange(v: boolean): void {
    Store.setStudentMode(v);
  }

  openMgr(kind: string): void {
    this.mgrKind = kind;
    this.mgrVisible = true;
  }

  addCategory(): void {
    if (this.mgrKind === 'type') {
      const n = this.newTypeName.trim();
      if (n === '') {
        return;
      }
      AppDb.addType(n).then(() => {
        this.newTypeName = '';
        Store.refreshCategories();
        Store.bumpDb();
      });
    } else {
      const n = this.newPrioName.trim();
      if (n === '') {
        return;
      }
      AppDb.addPrio(n).then(() => {
        this.newPrioName = '';
        Store.refreshCategories();
        Store.bumpDb();
      });
    }
  }

  renameType(c: TaskCategory, name: string): void {
    const n = name.trim();
    if (n === '') {
      Store.refreshCategories();
      return;
    }
    AppDb.updateType(c.id, n).then(() => {
      Store.refreshCategories();
      Store.bumpDb();
    });
  }

  renamePrio(p: PriorityLevel, name: string): void {
    const n = name.trim();
    if (n === '') {
      Store.refreshCategories();
      return;
    }
    AppDb.updatePrio(p.id, n).then(() => {
      Store.refreshCategories();
      Store.bumpDb();
    });
  }

  removeType(c: TaskCategory): void {
    if (this.types.length <= 1) {
      promptAction.showToast({ message: '至少保留一个类型' });
      return;
    }
    AppDb.deleteType(c.id).then(() => {
      Store.refreshCategories();
      Store.bumpDb();
    });
  }

  removePrio(p: PriorityLevel): void {
    if (this.prios.length <= 1) {
      promptAction.showToast({ message: '至少保留一个优先级' });
      return;
    }
    AppDb.deletePrio(p.id).then(() => {
      Store.refreshCategories();
      Store.bumpDb();
    });
  }

  build() {
    Column() {
      Text('我的')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ top: 16, bottom: 12, left: 16, right: 16 })

      Scroll() {
        Column({ space: 12 }) {
          // 统计卡（内联渲染，避免 @Builder 按值传参不刷新）
          Row() {
            Column({ space: 4 }) {
              Text(`${this.pendingCount}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.brand'))
              Text('待办').fontSize(12).fontColor($r('app.color.text_tertiary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            Divider().height(28).vertical(true).color($r('app.color.divider'))
            Column({ space: 4 }) {
              Text(`${this.overdueCount}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.urgency_overdue'))
              Text('逾期').fontSize(12).fontColor($r('app.color.text_tertiary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
            Divider().height(28).vertical(true).color($r('app.color.divider'))
            Column({ space: 4 }) {
              Text(`${this.doneCount}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_tertiary'))
              Text('已完成').fontSize(12).fontColor($r('app.color.text_tertiary'))
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%')
          .padding(18)
          .borderRadius(16)
          .backgroundColor($r('app.color.card_bg'))

          // 类型 / 优先级自定义
          Column() {
            Row() {
              Text('任务分类')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text('管理 >')
                .fontSize(13)
                .fontColor($r('app.color.brand'))
                .onClick(() => this.openMgr('type'))
            }.width('100%')
            Text(this.types.map((c: TaskCategory) => c.name).join(' · '))
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
              .margin({ top: 4 })

            Divider().height(1).color($r('app.color.divider')).margin({ top: 12, bottom: 12 })

            Row() {
              Text('优先级')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text('管理 >')
                .fontSize(13)
                .fontColor($r('app.color.brand'))
                .onClick(() => this.openMgr('prio'))
            }.width('100%')
            Text(this.prios.map((p: PriorityLevel) => p.name).join(' · '))
              .fontSize(12)
              .fontColor($r('app.color.text_tertiary'))
              .margin({ top: 4 })
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor($r('app.color.card_bg'))
          .alignItems(HorizontalAlign.Start)

          // 学生模式
          Column({ space: 2 }) {
            Row() {
              Column({ space: 2 }) {
                Text('学生模式')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text('开启后显示课程页与考试页')
                  .fontSize(12)
                  .fontColor($r('app.color.text_tertiary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.studentMode })
                .selectedColor($r('app.color.brand'))
                .onChange((v: boolean) => this.onModeChange(v))
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor($r('app.color.card_bg'))
          .alignItems(HorizontalAlign.Start)

          // 隐私政策（离线可查看）
          Row() {
            Text('隐私政策')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Text('查看 >')
              .fontSize(13)
              .fontColor($r('app.color.brand'))
          }
          .width('100%')
          .padding(16)
          .borderRadius(16)
          .backgroundColor($r('app.color.card_bg'))
          .onClick(() => this.privacyCtrl.open())
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
    .bindSheet($$this.mgrVisible, this.mgrBuilder(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: false
    })
  }

  @Builder
  mgrBuilder() {
    Column({ space: 14 }) {
      Text(this.mgrKind === 'type' ? '管理任务类型' : '管理优先级')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      if (this.mgrKind === 'prio') {
        Text('档位从低到高排列，新增的优先级排在最高档')
          .fontSize(12)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      }

      Scroll() {
        Column({ space: 8 }) {
          if (this.mgrKind === 'type') {
            ForEach(this.types, (c: TaskCategory) => {
              Row({ space: 8 }) {
                TextInput({ text: c.name })
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .height(40)
                  .borderRadius(8)
                  .backgroundColor($r('app.color.input_bg'))
                  .layoutWeight(1)
                  .onChange((v: string) => {
                    c.name = v;
                  })
                  .onSubmit(() => this.renameType(c, c.name))
                Text('删除')
                  .fontSize(13)
                  .fontColor($r('app.color.urgency_overdue'))
                  .padding(6)
                  .onClick(() => this.removeType(c))
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }, (c: TaskCategory) => `t-${c.id}`)
          } else {
            ForEach(this.prios, (p: PriorityLevel) => {
              Row({ space: 8 }) {
                TextInput({ text: p.name })
                  .fontSize(14)
                  .fontColor($r('app.color.text_primary'))
                  .height(40)
                  .borderRadius(8)
                  .backgroundColor($r('app.color.input_bg'))
                  .layoutWeight(1)
                  .onChange((v: string) => {
                    p.name = v;
                  })
                  .onSubmit(() => this.renamePrio(p, p.name))
                Text('删除')
                  .fontSize(13)
                  .fontColor($r('app.color.urgency_overdue'))
                  .padding(6)
                  .onClick(() => this.removePrio(p))
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }, (p: PriorityLevel) => `p-${p.id}`)
          }
        }
        .constraintSize({ maxHeight: 320 })
      }
      .align(Alignment.Top)
      .scrollBar(BarState.Off)

      Row({ space: 8 }) {
        TextInput({ placeholder: '新名称' })
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .height(40)
          .borderRadius(8)
          .backgroundColor($r('app.color.input_bg'))
          .layoutWeight(1)
          .onChange((v: string) => {
            if (this.mgrKind === 'type') {
              this.newTypeName = v;
            } else {
              this.newPrioName = v;
            }
          })
        Button('添加')
          .height(40)
          .fontSize(14)
          .backgroundColor($r('app.color.brand'))
          .onClick(() => this.addCategory())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .padding(20)
    .width('100%')
  }
}
