import { AppDb } from '../db/AppDb';
import { Store } from '../common/Store';
import { Task } from '../model/Task';
import { Course } from '../model/Course';
import { Exam } from '../model/Exam';
import { TimeUtil } from '../common/TimeUtil';
import { TodayView } from '../view/TodayView';
import { TasksView } from '../view/TasksView';
import { CoursesView } from '../view/CoursesView';
import { ExamsView } from '../view/ExamsView';
import { MineView } from '../view/MineView';
import { AddTaskSheet } from '../view/AddTaskSheet';
import { CourseSheet } from '../view/CourseSheet';
import { ExamSheet } from '../view/ExamSheet';
import { PrivacyDialog } from '../view/PrivacyDialog';
import { common } from '@kit.AbilityKit';
import { window, display } from '@kit.ArkUI';

type TabKey = 'today' | 'tasks' | 'exams' | 'courses' | 'mine';
type SheetKind = 'task' | 'course' | 'exam';

@Entry
@Component
struct Index {
  @StorageLink('studentMode') @Watch('rebuildTabs') studentMode: boolean = true;
  @State tabKeys: TabKey[] = ['today', 'tasks', 'exams', 'courses', 'mine'];
  @State tabIdx: number = 0;
  @State sheetVisible: boolean = false;
  @State sheetKind: SheetKind = 'task';
  @State editingTask: Task = new Task();
  @State editingCourse: Course = new Course();
  @State editingExam: Exam = new Exam();
  @StorageLink('topInset') topInset: number = 0;
  @StorageLink('bottomInset') bottomInset: number = 0;

  // 首启隐私政策弹窗：必须同意才能使用，不同意则退出应用
  privacyCtrl: CustomDialogController = new CustomDialogController({
    builder: PrivacyDialog({ cancel: () => {}, confirm: () => {} }),
    autoCancel: false,
    customStyle: true
  });

  aboutToAppear(): void {
    const ctx = getContext(this) as common.UIAbilityContext;
    // 页面侧再取一次避让区（UI 上下文内取值最可靠），兜底 EntryAbility 的计算
    this.refreshInsets();
    AppDb.init(ctx).then(() => {
      Promise.all([
        Store.refreshCourses(),
        Store.refreshExams(),
        Store.refreshCategories()
      ]).then(() => {
        Store.initPrefs(ctx).then(() => {
          this.rebuildTabs();
          Store.bumpDb();
          if (AppStorage.get<boolean>('privacyAgreed') !== true) {
            this.privacyCtrl.open();
          }
        });
      });
    });
  }

  rebuildTabs(): void {
    // 记住当前页签，重建后停留在原页签（如“我的”），不跳页
    const cur = this.currentTabKey();
    const keys: TabKey[] = ['today', 'tasks'];
    if (this.studentMode) {
      keys.push('exams');
      keys.push('courses');
    }
    keys.push('mine');
    this.tabKeys = keys;
    const ni = keys.findIndex((k: TabKey) => k === cur);
    this.tabIdx = ni >= 0 ? ni : 0;
    if (this.tabIdx >= 0 && this.tabIdx < keys.length) {
      AppStorage.setOrCreate<string>('activeTabKey', keys[this.tabIdx]);
    }
  }

  currentTabKey(): TabKey {
    if (this.tabIdx >= 0 && this.tabIdx < this.tabKeys.length) {
      return this.tabKeys[this.tabIdx];
    }
    return 'today';
  }

  tabLabel(k: TabKey): string {
    switch (k) {
      case 'today':
        return '今日';
      case 'tasks':
        return '任务';
      case 'exams':
        return '考试';
      case 'courses':
        return '课程';
      default:
        return '我的';
    }
  }

  openAddTask(): void {
    const t = new Task();
    t.deadline = TimeUtil.endOfToday();
    this.editingTask = t;
    this.sheetKind = 'task';
    this.sheetVisible = true;
  }

  openEditTask(t: Task): void {
    this.editingTask = Task.copy(t);
    this.sheetKind = 'task';
    this.sheetVisible = true;
  }

  openAddCourse(): void {
    this.editingCourse = new Course();
    this.sheetKind = 'course';
    this.sheetVisible = true;
  }

  openEditCourse(c: Course): void {
    this.editingCourse = Course.copy(c);
    this.sheetKind = 'course';
    this.sheetVisible = true;
  }

  openAddExam(): void {
    this.editingExam = new Exam();
    this.sheetKind = 'exam';
    this.sheetVisible = true;
  }

  openEditExam(e: Exam): void {
    this.editingExam = Exam.copy(e);
    this.sheetKind = 'exam';
    this.sheetVisible = true;
  }

  /** 查询系统栏避让高度：状态栏（为 0 时回退刘海区）+ 底部手势条 */
  private refreshInsets(): void {
    window.getLastWindow(getContext(this) as common.UIAbilityContext).then((win: window.Window) => {
      try {
        const density = display.getDefaultDisplaySync().densityPixels;
        const sys = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        const cut = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
        const nav = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
        const topPx = sys.topRect.height > 0 ? sys.topRect.height : cut.topRect.height;
        AppStorage.setOrCreate<number>('topInset', topPx / density);
        AppStorage.setOrCreate<number>('bottomInset', nav.bottomRect.height / density);
      } catch (err) {
        console.error('refreshInsets failed: ' + JSON.stringify(err));
      }
    });
  }

  /** 右下角加号跟随当前页签：任务/考试/课程 */
  onFabClick(): void {
    const k = this.currentTabKey();
    if (k === 'courses') {
      this.openAddCourse();
    } else if (k === 'exams') {
      this.openAddExam();
    } else {
      this.openAddTask();
    }
  }

  @Builder
  tabContent(k: TabKey) {
    if (k === 'today') {
      TodayView({ openEdit: (t: Task) => this.openEditTask(t) })
    } else if (k === 'tasks') {
      TasksView({ openEdit: (t: Task) => this.openEditTask(t) })
    } else if (k === 'exams') {
      ExamsView({
        openAddExam: () => this.openAddExam(),
        openEditExam: (e: Exam) => this.openEditExam(e)
      })
    } else if (k === 'courses') {
      CoursesView({
        openAddCourse: () => this.openAddCourse(),
        openEditCourse: (c: Course) => this.openEditCourse(c)
      })
    } else {
      MineView()
    }
  }

  @Builder
  sheetContent() {
    if (this.sheetKind === 'task') {
      AddTaskSheet({
        task: this.editingTask,
        onClose: () => {
          this.sheetVisible = false;
        }
      })
    } else if (this.sheetKind === 'exam') {
      ExamSheet({
        exam: this.editingExam,
        onClose: () => {
          this.sheetVisible = false;
        }
      })
    } else {
      CourseSheet({
        course: this.editingCourse,
        onClose: () => {
          this.sheetVisible = false;
        }
      })
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Tabs({ index: this.tabIdx, barPosition: BarPosition.End }) {
        ForEach(this.tabKeys, (k: TabKey) => {
          TabContent() {
            this.tabContent(k)
          }
          .tabBar(this.tabLabel(k))
        }, (k: TabKey) => k)
      }
      .layoutWeight(1)
      .barHeight(56)
      .scrollable(true)
      .onChange((i: number) => {
        this.tabIdx = i;
        if (i >= 0 && i < this.tabKeys.length) {
          AppStorage.setOrCreate<string>('activeTabKey', this.tabKeys[i]);
        }
      })

      // 悬浮新建按钮：按当前页签添加任务/考试/课程
      Button('+')
        .fontSize(28)
        .fontColor(Color.White)
        .width(56)
        .height(56)
        .type(ButtonType.Circle)
        .backgroundColor($r('app.color.brand'))
        .shadow({ radius: 8, color: 'rgba(91,51,184,0.35)', offsetY: 3 })
        .margin({ right: 20, bottom: 76 })
        .onClick(() => this.onFabClick())
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topInset, bottom: this.bottomInset })
    .backgroundColor($r('app.color.page_bg'))
    .bindSheet($$this.sheetVisible, this.sheetContent(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      showClose: false
    })
  }
}
