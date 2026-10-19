import { OkrThemeMode, THEME } from '../store/ThemeStore';
import { SESSION } from '../store/SessionStore';
import { SYNC } from '../store/SyncService';
import { PageShell, SectionCard } from '../components/PageShell';

@ComponentV2
export struct SettingsPage {
  @Local stack: NavPathStack = new NavPathStack();
  @Local serverUrl: string = SESSION.baseUrl;

  private healthText(): string {
    return SYNC.lastMessage.length > 0 ? SYNC.lastMessage : SYNC.statusText();
  }

  private setTheme(mode: OkrThemeMode): void {
    THEME.setMode(mode);
  }

  @Builder
  themeButton(mode: OkrThemeMode, label: string) {
    Button(label)
      .layoutWeight(1)
      .height(36)
      .fontSize(13)
      .backgroundColor(THEME.mode === mode ? $r('app.color.okr_primary') : $r('app.color.okr_track'))
      .fontColor(THEME.mode === mode ? $r('app.color.okr_on_primary') : $r('app.color.okr_text_primary'))
      .onClick((): void => {
        this.setTheme(mode);
      })
  }

  private async signOut(): Promise<void> {
    AlertDialog.show({
      title: '退出登录',
      message: '本机数据仍会保留，但不再与云端同步。',
      primaryButton: { value: '取消', action: (): void => {
      } },
      secondaryButton: { value: '退出', fontColor: $r('app.color.okr_danger'), action: (): void => {
        SESSION.signOut();
        this.stack.pop();
      } }
    });
  }

  @Builder
  topBar() {
    Row() {
      Text('‹ 返回')
        .fontSize(14)
        .fontColor($r('app.color.okr_primary'))
        .onClick((): void => {
          this.stack.pop();
        })
      Text('设置')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.okr_text_primary'))
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Blank()
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  section(title: string) {
    Text(title)
      .fontSize(12)
      .fontColor($r('app.color.okr_text_tertiary'))
      .width('100%')
      .padding({ top: 8, left: 4 })
  }

  build() {
    NavDestination() {
      PageShell() {
        this.topBar()

        Column({ space: 8 }) {
          this.section('外观')
          SectionCard({ cardTitle: '外观', cardHint: THEME.modeLabel() }) {
            Row({ space: 8 }) {
              this.themeButton(OkrThemeMode.System, '跟随系统')
              this.themeButton(OkrThemeMode.Light, '浅色')
              this.themeButton(OkrThemeMode.Dark, '深色')
            }
            .width('100%')
          }

          this.section('云同步')
          SectionCard({ cardTitle: '云同步' }) {
            Row() {
              Column({ space: 3 }) {
                Text(SESSION.username.length > 0 ? SESSION.username : '未登录')
                  .fontSize(14)
                  .fontColor($r('app.color.okr_text_primary'))
                Text(this.healthText())
                  .fontSize(11)
                  .fontColor($r('app.color.okr_text_tertiary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Button('立即同步')
                .height(32)
                .fontSize(12)
                .backgroundColor($r('app.color.okr_primary_soft'))
                .fontColor($r('app.color.okr_primary'))
                .onClick((): void => {
                  SYNC.syncNow();
                })
            }
            .width('100%')
          }

          this.section('服务器')
          SectionCard({ cardTitle: '服务器' }) {
            TextInput({ placeholder: '服务器地址', text: this.serverUrl })
              .height(40)
              .fontSize(12)
              .backgroundColor($r('app.color.okr_track'))
              .borderRadius(10)
              .onChange((value: string): void => {
                this.serverUrl = value;
              })
            Row({ space: 8 }) {
              Button('保存地址')
                .layoutWeight(1)
                .height(36)
                .fontSize(13)
                .backgroundColor($r('app.color.okr_text_primary'))
                .fontColor($r('app.color.okr_on_primary'))
                .onClick((): void => {
                  SESSION.setBaseUrl(this.serverUrl);
                  this.getUIContext().getPromptAction().showToast({ message: '已保存' });
                })
              Button('测试连接')
                .layoutWeight(1)
                .height(36)
                .fontSize(13)
                .backgroundColor($r('app.color.okr_primary_soft'))
                .fontColor($r('app.color.okr_primary'))
                .onClick((): void => {
                  SESSION.setBaseUrl(this.serverUrl);
                  SYNC.health();
                })
            }
            .width('100%')
          }

          this.section('账户')
          Button('退出登录')
            .width('100%')
            .height(42)
            .fontSize(14)
            .backgroundColor($r('app.color.okr_card'))
            .fontColor($r('app.color.okr_danger'))
            .onClick((): void => {
              this.signOut();
            })

          Text('OKR 记事本 v1.0.0')
            .fontSize(11)
            .fontColor($r('app.color.okr_text_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 20 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
      }
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.okr_track'))
    .onReady((context: NavDestinationContext): void => {
      this.stack = context.pathStack;
    })
  }
}

@Builder
export function SettingsBuilder() {
  SettingsPage()
}
