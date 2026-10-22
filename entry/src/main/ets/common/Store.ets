import { preferences } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';
import { Course } from '../model/Course';
import { Exam } from '../model/Exam';
import { TaskCategory, PriorityLevel } from '../model/Category';
import { AppDb } from '../db/AppDb';

// 全局 AppStorage 键的默认值（模块加载即注册，早于任何组件构建）
AppStorage.setOrCreate<number>('dbVersion', 0);
AppStorage.setOrCreate<boolean>('studentMode', true);
AppStorage.setOrCreate<Course[]>('courseList', []);
AppStorage.setOrCreate<Exam[]>('examList', []);
AppStorage.setOrCreate<TaskCategory[]>('typeList', []);
AppStorage.setOrCreate<PriorityLevel[]>('priList', []);
AppStorage.setOrCreate<string>('activeTabKey', 'today');
AppStorage.setOrCreate<number>('topInset', 0);
AppStorage.setOrCreate<number>('bottomInset', 0);
AppStorage.setOrCreate<boolean>('privacyAgreed', false);

const PREF_NAME = 'weiwan_prefs';
const KEY_STUDENT_MODE = 'studentMode';
const KEY_PRIVACY_AGREED = 'privacyAgreed';

/** 全局状态：AppStorage 版本号驱动各页重查；偏好用 preferences 落盘 */
export class Store {
  private static prefs: preferences.Preferences | null = null;

  /** 数据变更后调用，各页通过 @Watch('dbVersion') 感知并重查 */
  static bumpDb(): void {
    const v = AppStorage.get<number>('dbVersion') ?? 0;
    AppStorage.setOrCreate<number>('dbVersion', v + 1);
  }

  static bumpCourses(): void {
    const c = AppStorage.get<number>('courseVersion') ?? 0;
    AppStorage.setOrCreate<number>('courseVersion', c + 1);
    Store.bumpDb();
  }

  static async initPrefs(context: Context): Promise<void> {
    if (Store.prefs !== null) {
      return;
    }
    Store.prefs = await preferences.getPreferences(context, PREF_NAME);
    const sm = await Store.prefs.get(KEY_STUDENT_MODE, true);
    AppStorage.setOrCreate<boolean>('studentMode', sm === true);
    const pa = await Store.prefs.get(KEY_PRIVACY_AGREED, false);
    AppStorage.setOrCreate<boolean>('privacyAgreed', pa === true);
  }

  static async setStudentMode(v: boolean): Promise<void> {
    AppStorage.setOrCreate<boolean>('studentMode', v);
    if (Store.prefs !== null) {
      await Store.prefs.put(KEY_STUDENT_MODE, v);
      await Store.prefs.flush();
    }
  }

  /** 隐私政策同意状态：首启弹窗与"我的"页共用 */
  static async setPrivacyAgreed(v: boolean): Promise<void> {
    AppStorage.setOrCreate<boolean>('privacyAgreed', v);
    if (Store.prefs !== null) {
      await Store.prefs.put(KEY_PRIVACY_AGREED, v);
      await Store.prefs.flush();
    }
  }

  /** 直接把最新列表写入 AppStorage（列表数据统一从这里下发） */
  static async refreshCourses(): Promise<void> {
    AppStorage.setOrCreate<Course[]>('courseList', await AppDb.loadCourses());
  }

  static async refreshExams(): Promise<void> {
    AppStorage.setOrCreate<Exam[]>('examList', await AppDb.loadExams());
  }

  static async refreshCategories(): Promise<void> {
    const cats = await AppDb.loadCategories();
    AppStorage.setOrCreate<TaskCategory[]>('typeList', cats.types);
    AppStorage.setOrCreate<PriorityLevel[]>('priList', cats.prios);
  }
}
