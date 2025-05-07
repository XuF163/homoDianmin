import hilog from '@ohos.hilog';
import promptAction from '@ohos.promptAction';
import type resourceManager from '@ohos.resourceManager';
// 移除了所有NFC、WiFi、权限等复杂导入

const TAG: string = 'SignInComponentSimplified';
const DOMAIN: number = 0xFF00;

@Component
export struct SignInComponent {
  @State nfcStatusText: string = "NFC 功能待实现";
  @State isNfcDataPrepared: boolean = false; // 仅用于UI模拟

  @Prop appResourceManager: resourceManager.ResourceManager; // 改为非可选

  // 假设 getStringValue 是异步的
  private async getString(resource: Resource, defaultValue: string): Promise<string> {
    if (this.appResourceManager) {
      try {
        const value = await this.appResourceManager.getStringValue(resource);
        return value;
      } catch (e) {
        hilog.error(DOMAIN, TAG, "Error getting string resource: %{public}s", (e as Error).message);
        return defaultValue;
      }
    }
    hilog.warn(DOMAIN, TAG, "getString: ResourceManager not available for SignInComponent");
    return defaultValue;
  }

  async aboutToAppear(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'SignInComponent aboutToAppear (Simplified)');
    this.nfcStatusText = await this.getString($r('app.string.sign_in_initial_status'), "NFC 签到功能待实现");
  }

  aboutToDisappear(): void {
    hilog.info(DOMAIN, TAG, 'SignInComponent aboutToDisappear (Simplified)');
  }

  async onPrepareNfcDataClick(): Promise<void> {
    hilog.info(DOMAIN, TAG, "准备NFC数据按钮被点击 (功能暂未实现)");
    this.updateNfcStatus("NFC 数据准备功能正在开发中...");
    promptAction.showToast({ message: "此功能正在快马加鞭开发中！" });
    this.isNfcDataPrepared = !this.isNfcDataPrepared;
    if (this.isNfcDataPrepared) {
      this.updateNfcStatus("（模拟）NFC 数据已准备");
    } else {
      this.updateNfcStatus("（模拟）NFC 数据已清除");
    }
  }

  updateNfcStatus(status: string): void {
    this.nfcStatusText = status;
    hilog.info(DOMAIN, TAG, 'NFC Status Updated (Simplified): %{public}s', status);
  }
  //
  // // handleError 方法可以保留，以备将来使用 (简化版)
  // handleError(message: string, exception?: unknown): void {
  //   let detailedMessage = message;
  //   if (exception) { detailedMessage += ` | ${(exception as Error).message}`; }
  //   hilog.error(DOMAIN, TAG, 'Error in SignInComponent: %{public}s', detailedMessage);
  //   this.updateNfcStatus(`错误: ${message}`);
  //   promptAction.showToast({ message: message });
  // }

  build() {
    Column() {
      Button("准备 NFC 签到数据")
        .fontSize(18).fontWeight(FontWeight.Bold)
        .padding({ left: 24, right: 24, top: 16, bottom: 16 })
        .margin({ top: '20%' })
        .onClick(async () => await this.onPrepareNfcDataClick()) // 调用异步方法
      Text(this.nfcStatusText)
        .fontSize(16).textAlign(TextAlign.Center)
        .margin({ top: 32, left:16, right: 16 })
        .lineHeight(20).height(80)
      if (this.isNfcDataPrepared) {
        Text("（模拟状态）请将手机靠近读卡器")
          .fontSize(14).fontColor(Color.Orange) // 使用预定义颜色
          .margin({top: 10})
      }
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Center).padding(16)
  }
}