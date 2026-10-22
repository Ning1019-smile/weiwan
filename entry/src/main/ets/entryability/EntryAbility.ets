import { AbilityConstant, ConfigurationConstant, UIAbility, Want, Configuration } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window, display } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      // 沉浸式：内容延伸到状态栏/导航条之下，系统栏透明，颜色由页面背景资源接管
      this.setupImmersive(windowStage);
    });

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private async setupImmersive(windowStage: window.WindowStage): Promise<void> {
    try {
      const win = await windowStage.getMainWindow();
      await win.setWindowLayoutFullScreen(true);
      await win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: this.isDark() ? '#FFFFFF' : '#000000'
      });
      // px → vp，把状态栏/导航条高度下发给页面做避让（状态栏为 0 时回退刘海区）
      const density = display.getDefaultDisplaySync().densityPixels;
      const sys = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const cut = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
      const nav = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const topPx = sys.topRect.height > 0 ? sys.topRect.height : cut.topRect.height;
      AppStorage.setOrCreate<number>('topInset', topPx / density);
      AppStorage.setOrCreate<number>('bottomInset', nav.bottomRect.height / density);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to setup immersive window. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private isDark(): boolean {
    const mode = this.context.config.colorMode;
    return mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }

  /** 跟随系统深浅色切换时，更新状态栏图标颜色 */
  onConfigurationUpdate(newConfig: Configuration): void {
    window.getLastWindow(this.context).then((win: window.Window) => {
      const dark = newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
      win.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: dark ? '#FFFFFF' : '#000000'
      });
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
