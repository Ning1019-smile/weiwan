import { Store } from '../common/Store';
import { PRIVACY_TEXT, PRIVACY_UPDATE_DATE } from '../common/PrivacyText';
import { common } from '@kit.AbilityKit';

/**
 * 隐私政策弹窗：
 * - 首启模式（reviewMode=false）：必须选择"同意并继续"或"不同意并退出"，不可点击遮罩关闭；
 * - 查阅模式（reviewMode=true）：从"我的"页进入，仅"我知道了"按钮，可点遮罩关闭。
 */
@CustomDialog
export struct PrivacyDialog {
  controller?: CustomDialogController;
  cancel: () => void = () => {};
  confirm: () => void = () => {};
  reviewMode: boolean = false;

  agree(): void {
    Store.setPrivacyAgreed(true);
    if (this.controller) {
      this.controller.close();
    }
    this.confirm();
  }

  disagree(): void {
    Store.setPrivacyAgreed(false);
    if (this.controller) {
      this.controller.close();
    }
    (getContext(this) as common.UIAbilityContext).terminateSelf();
    this.cancel();
  }

  build() {
    Column({ space: 12 }) {
      Text('隐私政策')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')

      Text(`更新日期：${PRIVACY_UPDATE_DATE}`)
        .fontSize(11)
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')

      Scroll() {
        Text(PRIVACY_TEXT)
          .fontSize(13)
          .lineHeight(21)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .align(Alignment.Top)
      .scrollBar(BarState.Auto)
      .constraintSize({ maxHeight: 380 })

      if (this.reviewMode) {
        Button('我知道了')
          .width('100%')
          .height(42)
          .fontSize(15)
          .backgroundColor($r('app.color.brand'))
          .onClick(() => {
            if (this.controller) {
              this.controller.close();
            }
            this.confirm();
          })
      } else {
        Row({ space: 10 }) {
          Button('不同意并退出')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .backgroundColor($r('app.color.input_bg'))
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => this.disagree())
          Button('同意并继续')
            .layoutWeight(1)
            .height(42)
            .fontSize(14)
            .backgroundColor($r('app.color.brand'))
            .onClick(() => this.agree())
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .padding(20)
    .width('92%')
    .borderRadius(20)
    .backgroundColor($r('app.color.card_bg'))
    .alignItems(HorizontalAlign.Start)
  }
}
