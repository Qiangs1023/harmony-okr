import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { okrNewId } from '../model/OkrModel';

const DOMAIN: number = 0x0A02;
const PREF_NAME: string = 'okr_session_v1';
const KEY_TOKEN: string = 'token';
const KEY_USER: string = 'userId';
const KEY_NAME: string = 'username';
const KEY_DEVICE: string = 'deviceId';
const KEY_URL: string = 'baseUrl';
const KEY_CURSOR: string = 'cursor';

export const OKR_DEFAULT_BASE_URL: string = 'http://117.55.233.190:8088';

@ObservedV2
export class SessionStore {
  @Trace token: string = '';
  @Trace userId: string = '';
  @Trace username: string = '';
  @Trace deviceId: string = '';
  @Trace baseUrl: string = OKR_DEFAULT_BASE_URL;
  @Trace cursor: number = 0;
  @Trace syncing: boolean = false;
  @Trace lastError: string = '';

  private pref: preferences.Preferences | undefined = undefined;

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.pref = await preferences.getPreferences(context, PREF_NAME);
      this.token = await this.readString(KEY_TOKEN);
      this.userId = await this.readString(KEY_USER);
      this.username = await this.readString(KEY_NAME);
      this.deviceId = await this.readString(KEY_DEVICE);
      const url: string = await this.readString(KEY_URL);
      if (url.length > 0) {
        this.baseUrl = url;
      }
      const cursorRaw: preferences.ValueType = this.pref !== undefined
        ? await this.pref.get(KEY_CURSOR, 0)
        : 0;
      this.cursor = typeof cursorRaw === 'number' ? cursorRaw : Number(cursorRaw) || 0;
      if (this.deviceId.length === 0) {
        this.deviceId = okrNewId('dev');
        await this.writeString(KEY_DEVICE, this.deviceId);
      }
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, 'Session', 'init failed: %{public}s', e.message);
    }
  }

  isLoggedIn(): boolean {
    return this.token.length > 0 && this.userId.length > 0;
  }

  async signIn(token: string, userId: string, username: string): Promise<void> {
    this.token = token;
    this.userId = userId;
    this.username = username;
    this.cursor = 0;
    this.lastError = '';
    await this.writeString(KEY_TOKEN, token);
    await this.writeString(KEY_USER, userId);
    await this.writeString(KEY_NAME, username);
    await this.writeNumber(KEY_CURSOR, 0);
  }

  async signOut(): Promise<void> {
    this.token = '';
    this.userId = '';
    this.username = '';
    this.cursor = 0;
    if (this.pref === undefined) {
      return;
    }
    await this.pref.delete(KEY_TOKEN).catch(() => {
    });
    await this.pref.delete(KEY_USER).catch(() => {
    });
    await this.pref.delete(KEY_NAME).catch(() => {
    });
    await this.pref.delete(KEY_CURSOR).catch(() => {
    });
    await this.pref.flush().catch(() => {
    });
  }

  async setCursor(value: number): Promise<void> {
    this.cursor = value;
    await this.writeNumber(KEY_CURSOR, value);
  }

  async setBaseUrl(value: string): Promise<void> {
    const trimmed: string = value.trim().replace(/\/+$/, '');
    if (trimmed.length === 0) {
      return;
    }
    this.baseUrl = trimmed;
    await this.writeString(KEY_URL, trimmed);
  }

  private async readString(key: string): Promise<string> {
    if (this.pref === undefined) {
      return '';
    }
    try {
      const raw: preferences.ValueType = await this.pref.get(key, '');
      return typeof raw === 'string' ? raw : '';
    } catch (err) {
      return '';
    }
  }

  private async writeString(key: string, value: string): Promise<void> {
    if (this.pref === undefined) {
      return;
    }
    try {
      await this.pref.put(key, value);
      await this.pref.flush();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, 'Session', 'write %{public}s failed: %{public}s', key, e.message);
    }
  }

  private async writeNumber(key: string, value: number): Promise<void> {
    if (this.pref === undefined) {
      return;
    }
    try {
      await this.pref.put(key, value);
      await this.pref.flush();
    } catch (err) {
      const e: BusinessError = err as BusinessError;
      hilog.error(DOMAIN, 'Session', 'write %{public}s failed: %{public}s', key, e.message);
    }
  }
}

export const SESSION: SessionStore = new SessionStore();
