/** 时间与紧迫度相关工具 */
export class TimeUtil {
  static readonly DAY_MS: number = 24 * 3600 * 1000;
  static readonly WEEKDAY: string[] = ['日', '一', '二', '三', '四', '五', '六'];

  /** 某天 0 点的毫秒时间戳 */
  static startOfDay(d: Date): number {
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
  }

  static startOfToday(): number {
    return TimeUtil.startOfDay(new Date());
  }

  /** 今天 23:59:59.999 */
  static endOfToday(): number {
    return TimeUtil.startOfToday() + TimeUtil.DAY_MS - 1;
  }

  /** 距离 days 天后那天的 0 点 */
  static dayStartPlus(days: number): number {
    return TimeUtil.startOfToday() + days * TimeUtil.DAY_MS;
  }

  static sameDay(a: number, b: number): boolean {
    const da = new Date(a);
    const db = new Date(b);
    return da.getFullYear() === db.getFullYear()
      && da.getMonth() === db.getMonth()
      && da.getDate() === db.getDate();
  }

  /** deadline 距今天的天数：0=今天，负数=已过 */
  static daysUntil(deadline: number): number {
    return Math.round((TimeUtil.startOfDay(new Date(deadline)) - TimeUtil.startOfToday()) / TimeUtil.DAY_MS);
  }

  static pad(n: number): string {
    return n < 10 ? '0' + n : '' + n;
  }

  static fmtDate(ms: number): string {
    const d = new Date(ms);
    return `${d.getMonth() + 1}月${d.getDate()}日`;
  }

  static fmtTime(ms: number): string {
    const d = new Date(ms);
    return `${TimeUtil.pad(d.getHours())}:${TimeUtil.pad(d.getMinutes())}`;
  }

  /** 任务卡上的截止文案：今天/明天/M月D日周X + 时刻 */
  static fmtDeadline(ms: number): string {
    const days = TimeUtil.daysUntil(ms);
    const d = new Date(ms);
    let day: string;
    if (days === 0) {
      day = '今天';
    } else if (days === 1) {
      day = '明天';
    } else {
      day = `${TimeUtil.fmtDate(ms)} 周${TimeUtil.WEEKDAY[d.getDay()]}`;
    }
    return `${day} ${TimeUtil.fmtTime(ms)}`;
  }

  /** 保持原时刻、把截止改到 days 天后 */
  static shiftDeadline(deadline: number, days: number): number {
    const oldTimeOfDay = deadline - TimeUtil.startOfDay(new Date(deadline));
    return TimeUtil.dayStartPlus(days) + oldTimeOfDay;
  }
}
