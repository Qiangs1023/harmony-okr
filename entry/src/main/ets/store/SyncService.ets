import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  apiHealth,
  apiLogin,
  apiPull,
  apiPush,
  apiRegister,
  ApiAuthResult,
  ApiPullResult,
  ApiPushBody,
  ApiPushResult
} from '../net/ApiClient';
import { OKR_STORE, setPersistListener } from './OkrStore';
import { SESSION } from './SessionStore';

const DOMAIN: number = 0x0A04;
const PUSH_DEBOUNCE_MS: number = 4000;

@ObservedV2
export class SyncService {
  @Trace lastSyncedAt: number = 0;
  @Trace lastMessage: string = '';
  @Trace busy: boolean = false;

  private timer: number = -1;
  private pushing: boolean = false;

  start(): void {
    setPersistListener((): void => {
      this.schedulePush();
    });
    this.pullNow();
  }

  statusText(): string {
    if (!SESSION.isLoggedIn()) {
      return '未登录';
    }
    if (this.busy) {
      return '同步中…';
    }
    if (this.lastSyncedAt === 0) {
      return '待同步';
    }
    return `已同步 ${new Date(this.lastSyncedAt).toLocaleTimeString()}`;
  }

  schedulePush(): void {
    if (!SESSION.isLoggedIn()) {
      return;
    }
    if (this.timer !== -1) {
      clearTimeout(this.timer);
    }
    this.timer = setTimeout((): void => {
      this.timer = -1;
      this.pushNow();
    }, PUSH_DEBOUNCE_MS);
  }

  async pullNow(): Promise<void> {
    if (!SESSION.isLoggedIn()) {
      return;
    }
    this.busy = true;
    try {
      const remote: ApiPullResult = await apiPull(SESSION.baseUrl, SESSION.token, SESSION.cursor);
      if (remote.error.length > 0) {
        this.lastMessage = remote.error;
        hilog.error(DOMAIN, 'Sync', 'pull failed: %{public}s', remote.error);
        return;
      }
      OKR_STORE.applyRemote(remote);
      await SESSION.setCursor(remote.cursor);
      this.lastSyncedAt = Date.now();
      this.lastMessage = '';
    } finally {
      this.busy = false;
    }
  }

  async pushNow(): Promise<void> {
    if (!SESSION.isLoggedIn() || this.pushing) {
      return;
    }
    this.pushing = true;
    this.busy = true;
    try {
      const body: ApiPushBody = OKR_STORE.buildPushBody(SESSION.deviceId);
      const result: ApiPushResult = await apiPush(SESSION.baseUrl, SESSION.token, body);
      if (result.error.length > 0) {
        this.lastMessage = result.error;
        hilog.error(DOMAIN, 'Sync', 'push failed: %{public}s', result.error);
        return;
      }
      OKR_STORE.clearRemoved();
      this.lastSyncedAt = Date.now();
      this.lastMessage = result.conflicts.length > 0
        ? `${result.conflicts.length} 条冲突已保留云端版本`
        : '';
    } finally {
      this.pushing = false;
      this.busy = false;
    }
  }

  async syncNow(): Promise<void> {
    await this.pullNow();
    await this.pushNow();
    await this.pullNow();
  }

  async health(): Promise<string> {
    return apiHealth(SESSION.baseUrl);
  }

  async signIn(username: string, password: string, register: boolean): Promise<ApiAuthResult> {
    const result: ApiAuthResult = register
      ? await apiRegister(SESSION.baseUrl, username, password)
      : await apiLogin(SESSION.baseUrl, username, password);
    if (result.ok) {
      await SESSION.signIn(result.token, result.userId, result.username);
      this.lastMessage = '';
      this.syncNow();
    }
    return result;
  }
}

export const SYNC: SyncService = new SyncService();
