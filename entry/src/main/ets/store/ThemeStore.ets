import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0A05;
const PREF_NAME: string = 'okr_theme_v1';
const KEY_MODE: string = 'colorMode';

export enum OkrThemeMode {
  System = 0,
  Light = 1,
  Dark = 2
}

@ObservedV2
export class ThemeStore {
  @Trace mode: OkrThemeMode = OkrThemeMode.System;

  private pref: preferences.Preferences | undefined = undefined;
  private context: common.UIAbilityContext | undefined = undefined;

  async init(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    try {
      this.pref = await preferences.getPreferences(context, PREF_NAME);
      const raw: preferences.ValueType = await this.pref.get(KEY_MODE, OkrThemeMode.System);
      const value: number = typeof raw === 'number' ? raw : OkrThemeMode.System;
      this.mode = value === OkrThemeMode.Light ? OkrThemeMode.Light
        : (value === OkrThemeMode.Dark ? OkrThemeMode.Dark : OkrThemeMode.System);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, 'Theme', 'init failed: %{public}s', e.message);
    }
    this.apply();
  }

  async setMode(mode: OkrThemeMode): Promise<void> {
    this.mode = mode;
    if (this.pref !== undefined) {
      try {
        await this.pref.put(KEY_MODE, mode);
        await this.pref.flush();
      } catch (err) {
        const e: BusinessError = err as BusinessError;
        hilog.error(DOMAIN, 'Theme', 'save failed: %{public}s', e.message);
      }
    }
    this.apply();
  }

  modeLabel(): string {
    if (this.mode === OkrThemeMode.Light) {
      return '浅色';
    }
    if (this.mode === OkrThemeMode.Dark) {
      return '深色';
    }
    return '跟随系统';
  }

  private apply(): void {
    if (this.context === undefined) {
      return;
    }
    let target: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
    if (this.mode === OkrThemeMode.Light) {
      target = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
    } else if (this.mode === OkrThemeMode.Dark) {
      target = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    }
    try {
      this.context.getApplicationContext().setColorMode(target);
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, 'Theme', 'apply failed: %{public}s', e.message);
    }
  }
}

export const THEME: ThemeStore = new ThemeStore();
