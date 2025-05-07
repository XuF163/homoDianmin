import hilog from '@ohos.hilog';
import type Want from '@ohos.app.ability.Want';
import promptAction from '@ohos.promptAction';
import { RollCallComponent } from '../components/RollCallComponent';
import { SignInComponent } from '../components/SignInComponent';
import type resourceManager from '@ohos.resourceManager';

// 只保留对整个模块的默认导入，我们将通过它访问类型和方法
import preferences from '@ohos.data.preferences';

const TAG: string = 'IndexPage';
const DOMAIN: number = 0xFF00;
const PREFERENCES_NAME = 'app_main_prefs';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  private controller: TabsController = new TabsController();
  private appResourceManager: resourceManager.ResourceManager | undefined = undefined;
  // !!! 使用 preferences.Preferences 来注解类型 !!!
  private prefs: preferences.Preferences | null = null;

  async aboutToAppear(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Index page aboutToAppear');
    try {
      const uiContext = getContext(this);
      if (uiContext && uiContext.resourceManager) {
        this.appResourceManager = uiContext.resourceManager as resourceManager.ResourceManager;
      } else {
        hilog.error(DOMAIN, TAG, "Failed to get ResourceManager from uiContext");
      }

      if (uiContext) {
        const appContext = uiContext.getApplicationContext();
        // 调用模块的静态方法 getPreferences
        this.prefs = await preferences.getPreferences(appContext, PREFERENCES_NAME);
      } else {
        hilog.error(DOMAIN, TAG, "UIContext is null, cannot get preferences.");
        return;
      }

      if (this.prefs) { // 现在 this.prefs 的类型应该是 preferences.Preferences | null
        const launchWantStr: string = await this.prefs.get('launchWant', '') as string;
        if (launchWantStr) {
          try {
            const launchWant = JSON.parse(launchWantStr) as Want;
            hilog.info(DOMAIN, TAG, 'Handling launch Want from Prefs: %{public}s', launchWantStr);
            await this.handleNfcWant(launchWant);
            this.prefs.delete('launchWant');
            await this.prefs.flush();
          } catch (e) {
            let errorMessage = JSON.stringify(e);
            if (e instanceof Error) errorMessage = e.message;
            hilog.error(DOMAIN, TAG, 'Failed to parse launchWant from Prefs: %{public}s', errorMessage);
          }
        }
      } else {
        hilog.error(DOMAIN, TAG, "Preferences instance is null after loading attempt.");
      }
      await this.checkNewWantFromPrefs();

    } catch (e) {
      let errorMessage = JSON.stringify(e);
      if (e instanceof Error) errorMessage = e.message;
      hilog.error(DOMAIN, TAG, "Error in Index aboutToAppear: %{public}s", errorMessage);
    }
  }

  // ... (onShow, checkNewWantFromPrefs, handleNfcWant, build, TabBuilder 保持不变，因为它们内部的 this.prefs 用法是正确的)
  async onShow(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Index page onShow');
    const uiContext = getContext(this);
    if (!this.prefs && uiContext) {
      try {
        const appContext = uiContext.getApplicationContext();
        this.prefs = await preferences.getPreferences(appContext, PREFERENCES_NAME);
      } catch (e) {
        let errorMessage = JSON.stringify(e);
        if (e instanceof Error) errorMessage = e.message;
        hilog.error(DOMAIN, TAG, "Failed to load prefs in onShow: %{public}s", errorMessage);
      }
    }
    await this.checkNewWantFromPrefs();
  }

  private async checkNewWantFromPrefs(): Promise<void> {
    if (!this.prefs) {
      hilog.warn(DOMAIN, TAG, "Preferences not available in checkNewWantFromPrefs");
      return;
    }
    const newWantStr: string = await this.prefs.get('newWantFromAbility', '') as string;
    if (newWantStr) {
      try {
        const newWant = JSON.parse(newWantStr) as Want;
        hilog.info(DOMAIN, TAG, 'Handling newWantFromAbility from Prefs: %{public}s', newWantStr);
        await this.handleNfcWant(newWant);
        this.prefs.delete('newWantFromAbility');
        await this.prefs.flush();
      } catch (e) {
        let errorMessage = JSON.stringify(e);
        if (e instanceof Error) errorMessage = e.message;
        hilog.error(DOMAIN, TAG, 'Failed to parse newWantFromAbility from Prefs: %{public}s', errorMessage);
      }
    }
  }

  private async handleNfcWant(want: Want): Promise<void> {
    hilog.info(DOMAIN, TAG, 'Handling NFC Want: %{public}s', JSON.stringify(want));
    if (want.action?.includes('nfc') || want.action?.includes('NDEF_DISCOVERED') || want.action?.includes('TAG_DISCOVERED')) {
      this.currentIndex = 1;
      this.controller.changeIndex(1);
      if (want.parameters && this.prefs) {
        try {
          this.prefs.putSync('nfcReceivedParameters', JSON.stringify(want.parameters));
        } catch (e) {
          let errorMessage = JSON.stringify(e);
          if (e instanceof Error) errorMessage = e.message;
          hilog.error(DOMAIN, TAG, "Failed to store NFC params in Prefs for SignInComponent: %{public}s", errorMessage);
        }
      } else if (!this.prefs) {
        hilog.error(DOMAIN, TAG, "Cannot store NFC params, Preferences not initialized.");
      }
      promptAction.showToast({ message: "检测到NFC事件，请查看签到页" });
    }
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.controller }) {
      TabContent() {
        RollCallComponent({ appResourceManager: this.appResourceManager! })
      }
      .tabBar(this.TabBuilder($r('app.string.roll_call_tab'), $r('app.media.ic_menu_roll_call'), 0))

      TabContent() {
        SignInComponent({ appResourceManager: this.appResourceManager! })
      }
      .tabBar(this.TabBuilder($r('app.string.sign_in_tab'), $r('app.media.ic_menu_sign_in'), 1))
    }
    .onChange((index: number) => {
      this.currentIndex = index;
      hilog.info(DOMAIN, TAG, 'Tab changed to index: %{public}d', index);
    })
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.white'))
  }

  @Builder
  TabBuilder(titleResource: Resource, imageResource: Resource, targetIndex: number) {
    Column() {
      Image(imageResource)
        .width(24).height(24)
        .fillColor(this.currentIndex === targetIndex ? $r('app.color.primary_color') : $r('app.color.inactive_color'))
      Text(titleResource)
        .fontColor(this.currentIndex === targetIndex ? $r('app.color.primary_color') : $r('app.color.inactive_color'))
        .fontSize(10).margin({ top: 2 })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.currentIndex = targetIndex;
      this.controller.changeIndex(this.currentIndex);
    })
  }
}