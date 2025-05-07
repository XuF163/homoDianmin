import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import type Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import preferences from '@ohos.data.preferences'; // 导入 Preferences
// AbilityContext 通常不需要显式导入类型来注解 this.context
// import type AbilityContext from '@ohos.app.ability.AbilityContext';

const TAG: string = 'MainAbility';
const DOMAIN: number = 0xFF00; // 自定义日志 Domain ID
const PREFERENCES_NAME = 'app_main_prefs'; // Preferences 文件名

export default class MainAbility extends UIAbility {
  private prefs: preferences.Preferences | null = null;

  // 异步加载 Preferences 实例
  private async loadPreferences(): Promise<void> {
    if (this.prefs) return; // 如果已加载，则不重复加载
    try {
      // this.context 是 UIAbilityContext 类型
      this.prefs = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      hilog.info(DOMAIN, TAG, 'Preferences loaded successfully.');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to load preferences: %{public}s', JSON.stringify(err));
    }
  }

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    hilog.info(DOMAIN, TAG, 'Ability onCreate');
    await this.loadPreferences();

    if (this.context && this.context.applicationInfo && this.prefs) {
      try {
        // preferences.put 通常不返回 Promise<void>，或者其 Promise<void> 不需要赋值给变量
        // 但 flush 是异步的，需要 await
        this.prefs.putSync('applicationTokenId', this.context.applicationInfo.accessTokenId); // 尝试同步版本
        // await this.prefs.flush(); // 如果 putSync 已经持久化，flush 可能不是必须的，但通常建议调用
        hilog.info(DOMAIN, TAG, 'Stored applicationTokenId: %{public}s', this.context.applicationInfo.accessTokenId.toString());
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'Failed to store applicationTokenId in Prefs: %{public}s', (e as Error).message);
      }
    } else {
      hilog.warn(DOMAIN, TAG, 'Failed to get applicationInfo or accessTokenId, or prefs not loaded in onCreate');
    }

    if (this.prefs) {
      try {
        this.prefs.putSync('launchWant', JSON.stringify(want)); // 尝试同步版本
        // await this.prefs.flush();
        hilog.info(DOMAIN, TAG, 'LaunchWant stored in Prefs.');
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'Failed to store launchWant in Prefs: %{public}s', (e as Error).message);
      }
    }
  }

  async onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam) {
    hilog.info(DOMAIN, TAG, 'Ability onNewWant, want: %{public}s', JSON.stringify(want));
    await this.loadPreferences(); // 确保 prefs 已加载
    if (this.prefs) {
      try {
        this.prefs.putSync('newWantFromAbility', JSON.stringify(want));
        // await this.prefs.flush();
        hilog.info(DOMAIN, TAG, 'NewWant stored in Prefs.');
        // !!! 关键: 通知 Index 页面有新的 Want !!!
        // 这通常通过 EventHub 实现。MainAbility 发送事件，IndexPage 订阅并处理。
        // commonEventManager.publish('onNewWantEvent', { data: want }, (err) => {
        //   if (err) hilog.error(DOMAIN, TAG, 'Failed to publish newWantEvent');
        // });
      } catch (e) {
        hilog.error(DOMAIN, TAG, 'Failed to store newWant in Prefs: %{public}s', (e as Error).message);
      }
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage) {
    hilog.info(DOMAIN, TAG, 'Ability onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => { // data 参数可选
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading content.');
    });
  }

  async onDestroy() {
    hilog.info(DOMAIN, TAG, 'Ability onDestroy');
    if (this.prefs) {
      try {
        this.prefs.delete('launchWant');
        this.prefs.delete('newWantFromAbility');
        this.prefs.delete('applicationTokenId');
        await this.prefs.flush(); // 确保删除操作持久化
      } catch(e) {
        hilog.error(DOMAIN, TAG, 'Failed to clear keys from Prefs in onDestroy: %{public}s', (e as Error).message);
      }
    }
  }

  onForeground() {
    hilog.info(DOMAIN, TAG, 'Ability onForeground');
  }

  onBackground() {
    hilog.info(DOMAIN, TAG, 'Ability onBackground');
  }
}